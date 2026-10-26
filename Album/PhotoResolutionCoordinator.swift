import Foundation
import CryptoKit

enum PhotoAutomationIntent {
    case automatic
    case automaticResult
    case suppress
}

enum PhotoResolutionQueueState: String, Codable, Equatable {
    case pending
    case running
    case waitingForContext
    case needsReview
    case retryAt
    case completed
    case noMatch
    case suppressed
}

struct PhotoResolutionQueueJob: Codable, Equatable, Identifiable {
    let id: String
    let placeID: String
    let fingerprint: String
    var state: PhotoResolutionQueueState
    var attempts: Int
    var nextAttemptAt: Date?
    var leaseUntil: Date?
    var lastErrorCode: String?
    var updatedAt: Date
}

/// A local, persistent coordinator for automatic place-photo work.
/// It deliberately owns no image provider logic: AlbumStore remains the single
/// path that resolves identity, Wikimedia and website previews.
@MainActor
final class PhotoResolutionCoordinator {
    private struct File: Codable {
        var version = 1
        var jobs: [PhotoResolutionQueueJob] = []
    }

    private weak var store: AlbumStore?
    private let fileURL: URL
    private let now: () -> Date
    private var jobs: [PhotoResolutionQueueJob] = []
    private var worker: Task<Void, Never>?
    private var workerGeneration = 0
    private let leaseDuration: TimeInterval = 10 * 60
    private let retryDelays: [TimeInterval] = [60, 15 * 60, 6 * 60 * 60]

    init(store: AlbumStore, root: URL, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.fileURL = root.appendingPathComponent("photo-resolution-queue.json")
        self.now = now
        load()
    }

    var pendingJobCount: Int {
        jobs.filter { [.pending, .running, .waitingForContext, .retryAt, .noMatch].contains($0.state) }.count
    }

    func job(for placeID: String) -> PhotoResolutionQueueJob? {
        jobs.filter { $0.placeID == placeID }.max { $0.updatedAt < $1.updatedAt }
    }

    func enqueue(place: Place, context: TripRegionContext, force: Bool = false) {
        guard !place.deleted, let store else { return }
        let fingerprint = Self.fingerprint(place: place, context: context, albumID: store.data.albumID)
        let id = Self.jobID(placeID: place.id, fingerprint: fingerprint)
        if let index = jobs.firstIndex(where: { $0.id == id }) {
            if !force { return }
            jobs[index] = PhotoResolutionQueueJob(id: id, placeID: place.id, fingerprint: fingerprint,
                                                  state: .pending, attempts: 0, nextAttemptAt: nil,
                                                  leaseUntil: nil, lastErrorCode: nil, updatedAt: now())
        } else {
            jobs.append(PhotoResolutionQueueJob(id: id, placeID: place.id, fingerprint: fingerprint,
                                                state: .pending, attempts: 0, nextAttemptAt: nil,
                                                leaseUntil: nil, lastErrorCode: nil, updatedAt: now()))
        }
        save()
        resume()
    }

    func suppress(place: Place, context: TripRegionContext) {
        guard let store else { return }
        let fingerprint = Self.fingerprint(place: place, context: context, albumID: store.data.albumID)
        let id = Self.jobID(placeID: place.id, fingerprint: fingerprint)
        let suppressed = PhotoResolutionQueueJob(id: id, placeID: place.id, fingerprint: fingerprint,
                                                 state: .suppressed, attempts: 0, nextAttemptAt: nil,
                                                 leaseUntil: nil, lastErrorCode: "user-removed", updatedAt: now())
        if let index = jobs.firstIndex(where: { $0.id == id }) { jobs[index] = suppressed } else { jobs.append(suppressed) }
        save()
    }

    func resume() {
        guard worker == nil else { return }
        workerGeneration += 1
        let generation = workerGeneration
        worker = Task { [weak self] in await self?.drain(generation: generation) }
    }

    func cancel() {
        workerGeneration += 1
        worker?.cancel()
        worker = nil
        for index in jobs.indices where jobs[index].state == .running {
            jobs[index].state = .pending
            jobs[index].leaseUntil = nil
            jobs[index].nextAttemptAt = nil
            jobs[index].updatedAt = now()
        }
        save()
    }

    /// Test and lifecycle hook. It starts the same worker used by production;
    /// callers can await it only when they intentionally want a finite drain.
    func drainForTesting() async {
        cancel()
        await drain(generation: workerGeneration, stopWhenWaiting: true)
    }

    private func drain(generation: Int, stopWhenWaiting: Bool = false) async {
        defer { if workerGeneration == generation { worker = nil } }
        recoverExpiredLeases()
        while !Task.isCancelled, workerGeneration == generation {
            guard let index = nextJobIndex() else { return }
            let due = jobs[index].nextAttemptAt
            if let due, due > now() {
                if stopWhenWaiting { return }
                do { try await Task.sleep(for: .seconds(due.timeIntervalSince(now()))) } catch { return }
                continue
            }
            await process(index: index, generation: generation)
        }
    }

    private func process(index: Int, generation: Int) async {
        guard let store, jobs.indices.contains(index) else { return }
        var job = jobs[index]
        guard let place = store.places.first(where: { $0.id == job.placeID }) else {
            job.state = .suppressed; job.lastErrorCode = "place-missing"; job.updatedAt = now()
            jobs[index] = job; save(); return
        }
        let context = store.tripRegionContext(for: place)
        let currentFingerprint = Self.fingerprint(place: place, context: context, albumID: store.data.albumID)
        guard currentFingerprint == job.fingerprint else {
            job.state = .completed; job.lastErrorCode = "superseded"; job.updatedAt = now()
            jobs[index] = job; save()
            enqueue(place: place, context: context)
            return
        }
        if PlaceImageService.isUserChosen(place.image) {
            job.state = .completed; job.lastErrorCode = "user-image"; job.updatedAt = now()
            jobs[index] = job; save(); return
        }
        if Self.hasValidAutomaticImage(place) {
            // A manual candidate acceptance or another resolver may have
            // completed the image while this queue job was in flight. Do not
            // turn that successful result into a retry on the next wake-up.
            job.state = .completed; job.lastErrorCode = "existing-image"; job.nextAttemptAt = nil; job.updatedAt = now()
            jobs[index] = job; save(); return
        }
        if place.automaticPhotoSuppressed {
            job.state = .suppressed; job.lastErrorCode = "user-removed"; job.updatedAt = now()
            jobs[index] = job; save(); return
        }
        if place.coordinate == nil && context.source == .none {
            job.state = .waitingForContext; job.nextAttemptAt = nil; job.updatedAt = now()
            jobs[index] = job; save(); return
        }

        let retry = job.state == .retryAt || job.state == .noMatch || job.attempts > 0
        job.state = .running; job.leaseUntil = now().addingTimeInterval(leaseDuration); job.updatedAt = now()
        jobs[index] = job; save()
        await store.refreshPlaceImage(id: place.id, force: retry, automatic: true)
        guard workerGeneration == generation, !Task.isCancelled else {
            if jobs.indices.contains(index), jobs[index].state == .running {
                jobs[index].state = .pending
                jobs[index].leaseUntil = nil
                jobs[index].nextAttemptAt = nil
                jobs[index].updatedAt = now()
                save()
            }
            return
        }
        guard jobs.indices.contains(index), let current = store.places.first(where: { $0.id == place.id }) else { return }
        job = jobs[index]
        job.leaseUntil = nil
        let afterContext = store.tripRegionContext(for: current)
        let afterFingerprint = Self.fingerprint(place: current, context: afterContext, albumID: store.data.albumID)
        if afterFingerprint != job.fingerprint {
            job.state = .completed; job.lastErrorCode = "superseded"; job.updatedAt = now()
            jobs[index] = job; save()
            enqueue(place: current, context: afterContext)
            return
        }
        if PlaceImageService.isUserChosen(current.image) {
            job.state = .completed; job.lastErrorCode = "user-image"; job.updatedAt = now()
            jobs[index] = job; save(); return
        }
        switch store.placeImageStatus(for: current.id) {
        case .ready:
            job.state = .completed; job.nextAttemptAt = nil; job.lastErrorCode = nil
        case .notFound:
            job.state = .noMatch; job.nextAttemptAt = now().addingTimeInterval(7 * 86400); job.lastErrorCode = "no-match"
        case .deferred(let retryAfter):
            // A backend quota/lease response is not a no-match. Preserve its
            // server-provided wake-up time and do not consume retry attempts.
            job.state = .retryAt; job.nextAttemptAt = now().addingTimeInterval(max(retryAfter, 1)); job.lastErrorCode = "deferred"
        case .needsReview(_, let reason):
            job.state = .needsReview; job.nextAttemptAt = nil; job.lastErrorCode = String(describing: reason)
        case .failed(let retryable) where retryable && job.attempts < retryDelays.count:
            let delay = retryDelays[job.attempts]
            job.attempts += 1; job.state = .retryAt; job.nextAttemptAt = now().addingTimeInterval(delay); job.lastErrorCode = "retryable"
        case .failed:
            job.attempts += 1; job.state = .needsReview; job.nextAttemptAt = nil; job.lastErrorCode = "attempt-limit"
        default:
            job.state = .retryAt; job.nextAttemptAt = now().addingTimeInterval(retryDelays[min(job.attempts, retryDelays.count - 1)])
            job.attempts += 1; job.lastErrorCode = "incomplete"
        }
        job.updatedAt = now()
        jobs[index] = job
        save()
    }

    private func nextJobIndex() -> Int? {
        let current = now()
        return jobs.indices
            .filter { job in
                switch jobs[job].state {
                case .pending, .retryAt, .noMatch: return jobs[job].nextAttemptAt.map { $0 <= current } ?? true
                default: return false
                }
            }
            .min { lhs, rhs in jobs[lhs].updatedAt < jobs[rhs].updatedAt }
    }

    private func recoverExpiredLeases() {
        let current = now()
        for index in jobs.indices where jobs[index].state == .running && (jobs[index].leaseUntil ?? .distantPast) <= current {
            jobs[index].state = .pending; jobs[index].leaseUntil = nil; jobs[index].nextAttemptAt = nil; jobs[index].updatedAt = current
        }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL), let file = try? JSONDecoder().decode(File.self, from: data) else { return }
        jobs = file.jobs
    }

    private func save() {
        let file = File(jobs: jobs)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func fingerprint(place: Place, context: TripRegionContext, albumID: String) -> String {
        let coordinate = place.coordinate.map { "\($0.latitude),\($0.longitude)" } ?? "none"
        let region = context.region.map { "\($0.center.latitude),\($0.center.longitude),\($0.span.latitudeDelta),\($0.span.longitudeDelta)" } ?? "none"
        let raw = [albumID, place.id, normalized(place.title), normalized(place.address), normalized(place.category),
                   coordinate, place.sourceURL, context.name ?? "", String(describing: context.source), region].joined(separator: "\u{1F}")
        let digest = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
        return digest
    }

    /// Revision shared by collaborators for the same place/context. It excludes
    /// the installation-local album ID and device locale so backend leases can
    /// converge for one shared trip.
    static func serverRevision(place: Place, context: TripRegionContext) -> String {
        let coordinate = place.coordinate.map { "\($0.latitude),\($0.longitude)" } ?? "none"
        let region = context.region.map { "\($0.center.latitude),\($0.center.longitude),\($0.span.latitudeDelta),\($0.span.longitudeDelta)" } ?? "none"
        let raw = [place.id, serverNormalized(place.title), serverNormalized(place.address), serverNormalized(place.category),
                   coordinate, serverNormalized(context.name ?? ""), String(describing: context.source), region].joined(separator: "\u{1F}")
        let digest = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
        return digest
    }

    private static func serverNormalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func jobID(placeID: String, fingerprint: String) -> String { "\(placeID):\(fingerprint)" }

    private static func hasValidAutomaticImage(_ place: Place) -> Bool {
        guard case .external(let image) = place.image,
              image.userSelected != true,
              let resolvedFor = image.resolvedFor,
              resolvedFor.matches(place) else { return false }
        return image.provider == .sourcePreview
            || (image.provider == .wikimedia && (image.ranking ?? 1) >= PlaceImageService.ranking)
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
