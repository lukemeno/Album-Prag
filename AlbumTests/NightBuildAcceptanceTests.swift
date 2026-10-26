import XCTest
import PDFKit
@testable import Album

@MainActor
final class NightBuildAcceptanceTests: XCTestCase {
    private var roots: [URL] = []
    private var libraries: [TripLibrary] = []

    override func tearDownWithError() throws {
        libraries.forEach { $0.activeStore?.stopOwnedCallbacks() }
        libraries.removeAll()
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots.removeAll()
        try super.tearDownWithError()
    }

    private func makeLibrary(legacy: AlbumData? = nil) throws -> TripLibrary {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("night-acceptance-\(UUID().uuidString)")
        roots.append(root)
        let legacyRoot = root.appendingPathComponent("Legacy")
        if let legacy {
            try FileManager.default.createDirectory(at: legacyRoot, withIntermediateDirectories: true)
            try JSONEncoder().encode(legacy).write(to: legacyRoot.appendingPathComponent("album.json"), options: .atomic)
        }
        let library = TripLibrary(root: root.appendingPathComponent("Library"), legacyRoot: legacyRoot,
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("Share")),
                                  availableCapacity: { 1_000_000_000 })
        libraries.append(library)
        return library
    }

    func testProductionDefaultsContainNoTravelExamples() {
        let data = AlbumData()
        XCTAssertTrue(data.places.isEmpty)
        XCTAssertTrue(data.documents.isEmpty)
        XCTAssertTrue(data.tripMemories.isEmpty)
        XCTAssertTrue(data.trip.hotel.isEmpty)
        XCTAssertNil(data.trip.startDate)
        XCTAssertNil(data.trip.endDate)
        XCTAssertTrue(data.trip.flights?.isEmpty ?? true)
        XCTAssertTrue(data.trip.travelers?.isEmpty ?? true)
        XCTAssertTrue(data.trip.expenses?.isEmpty ?? true)
    }

    func testSameTripOpenKeepsOneStoreAndNewTripsRemainIsolated() throws {
        let library = try makeLibrary()
        XCTAssertTrue(library.entries.isEmpty)
        XCTAssertNil(library.activeStore)
        let paris = try XCTUnwrap(library.createBlankTrip(title: "Paris im Frühling", destination: "Paris"))
        XCTAssertTrue(library.open(paris))
        let first = try XCTUnwrap(library.activeStore)
        XCTAssertTrue(first.places.isEmpty)
        XCTAssertTrue(first.upsert(Place(id: "my-paris-idea", title: "Mein Spaziergang", category: "Idee")))
        let pdf = PDFDocument()
        pdf.insert(PDFPage(), at: 0)
        let pdfBytes = try XCTUnwrap(pdf.dataRepresentation())
        let sourcePDF = library.root.appendingPathComponent("import-for-paris.pdf")
        try pdfBytes.write(to: sourcePDF)
        try first.importPDF(sourcePDF, id: "paris-booking")
        XCTAssertTrue(first.saveExpense(TravelExpense(id: "paris-expense", title: "Museum", amountCents: 1200,
                                                     payer: "QA", participants: ["QA"])))
        XCTAssertTrue(library.open(paris))
        XCTAssertTrue(library.activeStore === first, "Opening the same trip must not duplicate store-owned workers")
        let berlin = try XCTUnwrap(library.createBlankTrip(title: "Berlin", destination: "Berlin"))
        XCTAssertTrue(library.open(berlin))
        let second = try XCTUnwrap(library.activeStore)
        XCTAssertTrue(second.places.isEmpty)
        XCTAssertTrue(second.data.documents.isEmpty)
        XCTAssertTrue(second.data.trip.expenses?.isEmpty ?? true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.root.appendingPathComponent("paris-booking.pdf").path))
        XCTAssertTrue(library.open(paris))
        XCTAssertEqual(library.activeStore?.places.map(\.id), ["my-paris-idea"])
        let restored = try XCTUnwrap(library.activeStore)
        XCTAssertEqual(restored.data.documents.map(\.id), ["paris-booking"])
        XCTAssertEqual(restored.data.trip.expenses?.map(\.id), ["paris-expense"])
        XCTAssertEqual(try Data(contentsOf: restored.root.appendingPathComponent("paris-booking.pdf")), pdfBytes)
    }

    func testFailedOpenDoesNotDeactivateCurrentTrip() async throws {
        let library = try makeLibrary()
        let firstID = try XCTUnwrap(library.createBlankTrip(title: "Paris", destination: "Paris"))
        let brokenID = try XCTUnwrap(library.createBlankTrip(title: "Berlin", destination: "Berlin"))
        XCTAssertTrue(library.open(firstID))
        let first = try XCTUnwrap(library.activeStore)
        let brokenFile = library.root.appendingPathComponent("Trips/\(brokenID.uuidString)/album.json")
        try Data("broken-json".utf8).write(to: brokenFile, options: .atomic)
        XCTAssertFalse(library.open(brokenID))
        XCTAssertTrue(library.activeStore === first)
        let stillActive = await first.sync()
        XCTAssertTrue(stillActive, "A failed switch must not shut down the previously opened local trip")
    }

    func testShareForAnotherTripSurvivesAndCannotEnterCurrentTrip() throws {
        let library = try makeLibrary()
        let firstID = try XCTUnwrap(library.createBlankTrip(title: "Paris", destination: "Paris"))
        let secondID = try XCTUnwrap(library.createBlankTrip(title: "Berlin", destination: "Berlin"))
        XCTAssertTrue(library.open(firstID))
        let first = try XCTUnwrap(library.activeStore)
        let firstKey = "local:\(first.data.albumID)"
        let item = ShareQueueItem(id: "night-share-paris", payload: "Nur für Paris", url: nil, tripKey: firstKey)
        try library.shareInbox.save(item)
        XCTAssertTrue(library.open(secondID))
        first.drainShareQueue()
        library.activeStore?.drainShareQueue()
        XCTAssertEqual(library.shareInbox.items(), [item])
        XCTAssertTrue(library.open(firstID))
        library.activeStore?.drainShareQueue()
        XCTAssertTrue(library.shareInbox.items().isEmpty)
    }

    func testIndexedMigrationTargetSurvivesAStaleCopyingReceipt() throws {
        var legacy = AlbumData()
        legacy.albumID = "real-legacy-album"
        legacy.trip.title = "Meine echte Reise"
        legacy.trip.notes = "Original bleibt erhalten"
        let library = try makeLibrary(legacy: legacy)
        let id = try XCTUnwrap(library.entries.first?.id)
        let originalBytes = try Data(contentsOf: library.legacyRoot.appendingPathComponent("album.json"))
        XCTAssertTrue(library.open(id))
        let store = try XCTUnwrap(library.activeStore)
        var editedTrip = store.data.trip
        editedTrip.notes = "Nach der Übernahme selbst bearbeitet"
        XCTAssertTrue(store.updateTrip(editedTrip))
        XCTAssertTrue(library.showLibrary())
        let receiptURL = library.root.appendingPathComponent("legacy-migration.json")
        var receipt = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: receiptURL)) as? [String: Any])
        receipt["state"] = "copying"
        try JSONSerialization.data(withJSONObject: receipt).write(to: receiptURL, options: .atomic)
        let reopened = TripLibrary(root: library.root, legacyRoot: library.legacyRoot,
                                   shareInbox: library.shareInbox, availableCapacity: { 1_000_000_000 })
        libraries.append(reopened)
        XCTAssertTrue(reopened.open(id))
        XCTAssertEqual(reopened.activeStore?.data.trip.notes, editedTrip.notes,
                       "An indexed user-edited copy must never be deleted because the receipt commit was interrupted")
        XCTAssertEqual(try Data(contentsOf: library.legacyRoot.appendingPathComponent("album.json")), originalBytes)
        XCTAssertTrue(reopened.showLibrary())
        var interrupted = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: receiptURL)) as? [String: Any])
        interrupted["state"] = "copying"
        try JSONSerialization.data(withJSONObject: interrupted).write(to: receiptURL, options: .atomic)
        try Data("corrupt index".utf8).write(to: library.root.appendingPathComponent("library.json"), options: .atomic)
        let repaired = TripLibrary(root: library.root, legacyRoot: library.legacyRoot,
                                  shareInbox: library.shareInbox, availableCapacity: { 1_000_000_000 })
        libraries.append(repaired)
        XCTAssertTrue(repaired.open(id))
        XCTAssertEqual(repaired.activeStore?.data.trip.notes, editedTrip.notes,
                       "A corrupt cache index must not turn a user-edited trip into a disposable migration orphan")
    }

    func testProtectedLegacySimulatorCopyWhenOptedIn() throws {
        guard let path = ProcessInfo.processInfo.environment["ALBUM_NIGHT_LEGACY_QA_SOURCE"] else {
            throw XCTSkip("Opt-in only: a protected read-only copy of the existing simulator album")
        }
        let source = URL(fileURLWithPath: path, isDirectory: true)
        let sourceFile = source.appendingPathComponent("album.json")
        let originalBytes = try Data(contentsOf: sourceFile)
        let original = try JSONDecoder().decode(AlbumData.self, from: originalBytes)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("night-real-copy-\(UUID().uuidString)")
        roots.append(root)
        let legacy = root.appendingPathComponent("Legacy")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: legacy)
        let library = TripLibrary(root: root.appendingPathComponent("Library"), legacyRoot: legacy,
                                  shareInbox: ShareInbox(root: root.appendingPathComponent("Share")),
                                  availableCapacity: { 1_000_000_000 })
        libraries.append(library)
        let entry = try XCTUnwrap(library.entries.first, library.error ?? "Legacy copy was not indexed")
        XCTAssertTrue(library.open(entry.id))
        let migrated = try XCTUnwrap(library.activeStore)
        XCTAssertTrue(migrated.data.albumID == original.albumID, "Album identity changed")
        XCTAssertTrue(migrated.data.collaboration == original.collaboration, "Sharing identity changed")
        XCTAssertTrue(Set(migrated.data.documents.map(\.id)) == Set(original.documents.map(\.id)), "Documents changed")
        XCTAssertTrue(Set(migrated.data.tripMemories.map(\.id)) == Set(original.tripMemories.map(\.id)), "Memories changed")
        let protected = original.places.filter {
            $0.updatedAt > Date.distantPast || !$0.approvals.isEmpty || !$0.passedBy.isEmpty
        }
        for place in protected {
            guard let kept = migrated.data.places.first(where: { $0.id == place.id }) else {
                XCTFail("A real or user-edited place is missing")
                continue
            }
            XCTAssertTrue(kept.title == place.title && kept.note == place.note && kept.image == place.image
                          && kept.approvals == place.approvals && kept.passedBy == place.passedBy,
                          "A protected place changed")
        }
        var preservedFiles = 0
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: source, includingPropertiesForKeys: [.isDirectoryKey]))
        for case let file as URL in enumerator {
            if try file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true { continue }
            let relative = String(file.path.dropFirst(source.path.count + 1))
            if relative == "album.json" { continue }
            XCTAssertTrue(FileManager.default.contentsEqual(atPath: file.path,
                           andPath: migrated.root.appendingPathComponent(relative).path), "An existing attachment changed")
            preservedFiles += 1
        }
        XCTAssertEqual(try Data(contentsOf: sourceFile), originalBytes)
        XCTAssertEqual(try Data(contentsOf: legacy.appendingPathComponent("album.json")), originalBytes)
        print("NIGHT_LEGACY_PROOF attachments=\(preservedFiles) source_places=\(original.places.count) protected_places=\(protected.count)")
    }
}
