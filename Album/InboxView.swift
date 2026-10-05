import SwiftUI

/// Resolves a card release from the finger's actual travel and a bounded
/// amount of predicted momentum. A short release must always return the card
/// to center; prediction alone cannot cast a vote.
enum InboxSwipeResolver {
    static let minimumIntent: CGFloat = 50
    static let maximumMomentum: CGFloat = 64

    static func projectedTranslation(actual: CGFloat, predicted: CGFloat) -> CGFloat {
        guard abs(actual) > minimumIntent else { return actual }
        let momentum = (predicted - actual).clamped(to: -maximumMomentum...maximumMomentum)
        return actual + momentum
    }

    static func horizontalDecision(actual: CGFloat, predicted: CGFloat, threshold: CGFloat) -> Bool? {
        guard abs(actual) > minimumIntent else { return nil }
        // Once the finger has crossed the full threshold, a late release
        // velocity must not undo that deliberate swipe.
        if actual > threshold { return true }
        if actual < -threshold { return false }
        let projected = projectedTranslation(actual: actual, predicted: predicted)
        if projected > threshold { return true }
        if projected < -threshold { return false }
        return nil
    }

    static func shouldOpen(actual: CGFloat, predicted: CGFloat, threshold: CGFloat) -> Bool {
        guard actual < -minimumIntent else { return false }
        if actual <= -threshold { return true }
        return projectedTranslation(actual: actual, predicted: predicted) < -threshold
    }
}

struct InboxView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var add: () -> Void = {}
    @State private var offset: CGSize = .zero
    @State private var editing: Place?
    @State private var departingPlace: Place?
    @State private var lastAction: Place?
    @State private var lastActionWasOpen = false
    @State private var openThisPassIDs: Set<String> = []
    @State private var feedback = 0
    @State private var thresholdFeedback = 0
    @State private var thresholdArmed = false
    @State private var committing = false
    /// 0…1: Der Poststempel landet auf dem Foto („frankiert“).
    @State private var stamp: CGFloat = 0
    @State private var stampTick = 0
    /// Wenn beide Ja sagen: zwei Herzhälften schnappen zusammen.
    @State private var magnet: CGFloat = 0
    @State private var magnetTick = 0
    /// 1 = hintere Marken weit aufgefächert, 0 = ruhige Lage; federt beim Erscheinen des Stapels.
    @State private var fan: CGFloat = 1
    /// Oberste Marke in der Hand: 0…1 für Anheben (Größe, Schatten).
    @State private var lift: CGFloat = 0
    /// Neigung um die senkrechte Achse in Grad, aus der geglätteten Ziehgeschwindigkeit.
    @State private var tilt: Double = 0
    @State private var lastSample: (x: CGFloat, time: Date)?
    @State private var tiltDecay: Task<Void, Never>?
    @State private var viewer: PhotoViewerItem?
    @State private var section: InboxSection = .discover
    @State private var allSearchText = ""
    @State private var detailPlaceID: String?

    private let decisionThreshold: CGFloat = 96
    private var progress: CGFloat { min(abs(offset.width) / decisionThreshold, 1) }
    private var openProgress: CGFloat { min(max(-offset.height, 0) / decisionThreshold, 1) }

    private var undecided: [Place] { store.inbox.filter { !openThisPassIDs.contains($0.id) } }
    private var visibleStack: [Place] {
        guard let departingPlace else { return undecided }
        return [departingPlace] + undecided.filter { $0.id != departingPlace.id }
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize && section == .discover {
                ScrollView(.vertical) { content }
            } else {
                content
            }
        }
        .task(id: section == .discover ? undecided.first?.id : nil) {
            guard section == .discover, let id = undecided.first?.id else { return }
            #if DEBUG
            if ProcessInfo.processInfo.environment["ALBUM_TEST_STORE"] != nil, ProcessInfo.processInfo.environment["ALBUM_IMAGE_RESPONSE_BASE64"] == nil { return }
            #endif
            await store.refreshPlaceImages(placeID: id)
        }
    }

    private var content: some View {
        VStack(spacing: Stitch.Space.m) {
            Picker("Ideenbereich", selection: $section) {
                ForEach(InboxSection.allCases) { section in Text(section.title).tag(section) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("Ideas-Segment")

            if section == .collection {
                CollectionHomeView(add: add)
            } else if section == .all {
                AllIdeasView(query: $allSearchText) { detailPlaceID = $0 }
            } else if section == .deferred {
                DeferredIdeasView(places: store.deferred, root: store.root) { place in
                    editing = place
                } restore: { place in
                    store.restoreDeferred(place)
                } restoreAll: {
                    store.restoreDeferred()
                }
            } else if let place = visibleStack.first {
                if dynamicTypeSize.isAccessibilitySize {
                    frontCard(place)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 420)
                } else {
                    GeometryReader { geo in
                        ZStack {
                        ForEach(Array(visibleStack.dropFirst().prefix(2).enumerated()), id: \.element.id) { index, next in
                            let spread = reduceMotion ? 0 : fan
                            IdeaStamp(place: next, root: store.root)
                                .rotationEffect(.degrees((index == 0 ? -2.5 : 3) + (index == 0 ? -5 : 5) * spread))
                                .offset(x: (index == 0 ? -10 : 12) + (index == 0 ? -16 : 18) * spread, y: 8 - 4 * spread)
                                .scaleEffect(reduceMotion ? 0.95 : 0.95 + 0.03 * progress)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }

                        frontCard(place)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                }

                if let line = authorLine(place) {
                    Text(line)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Stitch.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: Stitch.Space.s) {
                            decisionButton(place, frank: false)
                            decisionButton(place, frank: true)
                        }
                    } else {
                        HStack(spacing: Stitch.Space.s) {
                            decisionButton(place, frank: false)
                            decisionButton(place, frank: true)
                        }
                    }
                }
                HStack {
                    if let lastAction { undoButton(lastAction) }
                    Spacer()
                    Button("Offen") { markOpen(place) }.buttonStyle(AlbumTextActionButtonStyle(tint: Stitch.inkSoft))
                }
                .padding(.trailing, Stitch.Size.touch + Stitch.Space.m)
            } else {
                empty
            }
        }
        .allowsHitTesting(!committing)
        .padding(.horizontal, Stitch.Space.page).padding(.bottom, Stitch.Space.xs)
        .background(PaperBackground())
        .navigationTitle("Ideen")
        .toolbar {
            if section == .discover || section == .all {
                ToolbarItem(placement: .primaryAction) {
                    Button("Idee einwerfen", systemImage: "plus", action: add)
                }
            }
        }
        .sheet(item: $editing) { PlaceEditor(place: $0) }
        .sheet(isPresented: Binding(get: { detailPlaceID != nil }, set: { if !$0 { detailPlaceID = nil } })) {
            if let detailPlaceID { PlaceDetail(placeID: detailPlaceID) }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: feedback)
        .sensoryFeedback(.selection, trigger: thresholdFeedback)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: stampTick)
        .sensoryFeedback(.success, trigger: magnetTick)
        .onAppear { spread() }
        .onChange(of: visibleStack.first?.id) { spread() }
        .fullScreenCover(item: $viewer) { PhotoViewer(place: $0.place, root: store.root, source: $0.source) }
    }

    @ViewBuilder
    private func frontCard(_ place: Place) -> some View {
        let card = IdeaStamp(place: place, root: store.root, stamp: stamp, onPhotoTap: { openPhoto(place, from: $0) })
            .overlay(alignment: .topTrailing) {
                Button { editing = place } label: { Image(systemName: "pencil") }
                    .buttonStyle(HeaderIconButton())
                    .padding(Stitch.Space.l)
                    .accessibilityLabel("Idee bearbeiten")
                    .disabled(committing)
            }
            .overlay { DecisionHint(direction: hintDirection, progress: max(progress, openProgress)) }
            .overlay { if magnet > 0 { MagnetHearts(progress: magnet) } }
            .rotation3DEffect(.degrees(reduceMotion ? 0 : tilt), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .scaleEffect(reduceMotion ? 1 : 1 + 0.05 * lift)
            .offset(x: offset.width, y: min(offset.height, 0) + (reduceMotion ? 0 : -4 * progress))
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset.width / 42).clamped(to: -6...6)))
            .shadow(color: Stitch.shadow.opacity(0.06 * lift + 0.08 * progress), radius: 10 + 8 * lift, y: 6 + 6 * lift)
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                card
            } else {
                card.gesture(dragGesture(for: place))
            }
        }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("Inbox-Ticket")
            .accessibilityAction(named: "Ja") { act(place, frank: true) }
            .accessibilityAction(named: "Nein") { act(place, frank: false) }
            .accessibilityAction(named: "Offen") { markOpen(place) }
    }

    private var hintDirection: InboxDecision? {
        if openProgress > progress, openProgress > 0 { return .open }
        if offset.width == 0 { return nil }
        return offset.width > 0 ? .frank : .shelve
    }

    private var empty: some View {
        VStack(spacing: Stitch.Space.s) {
            Spacer()
            Postmark(top: "IDEEN", bottom: openThisPassIDs.isEmpty ? "LEER" : "OFFEN", color: Stitch.inkSoft, size: 96)
                .padding(.bottom, Stitch.Space.s)
            Text(openThisPassIDs.isEmpty ? "Alles entschieden" : "Noch offen")
                .font(Stitch.Face.title(28, relativeTo: .title)).foregroundStyle(Stitch.ink)
            Text(openThisPassIDs.isEmpty ? "Neue Links landen hier. Was ihr wollt, steht danach im Plan." : "Diese Ideen bleiben offen. Ihr könnt jederzeit neu entscheiden.")
                .font(.body).multilineTextAlignment(.center).foregroundStyle(Stitch.inkSoft)
            VStack(spacing: Stitch.Space.xs) {
                if !openThisPassIDs.isEmpty {
                    Button("Weitersehen") { openThisPassIDs.removeAll(); lastAction = nil }
                        .buttonStyle(AlbumActionButtonStyle(primary: true))
                } else {
                    Button(action: add) { Label("Idee einwerfen", systemImage: "plus") }
                        .buttonStyle(AlbumActionButtonStyle(primary: true))
                }
                if !store.deferred.isEmpty {
                    Button(store.deferred.count == 1 ? "1 abgelehnte Idee zurückholen" : "\(store.deferred.count) abgelehnte Ideen zurückholen") {
                        store.restoreDeferred()
                    }
                    .buttonStyle(AlbumTextActionButtonStyle())
                }
            }
            .padding(.top, Stitch.Space.m).padding(.horizontal, Stitch.Space.l)
            if let lastAction { undoButton(lastAction) }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func undoButton(_ place: Place) -> some View {
        Button {
            if lastActionWasOpen { openThisPassIDs.remove(place.id) } else { store.upsert(place) }
            lastAction = nil
        } label: { Label("Rückgängig", systemImage: "arrow.uturn.backward") }
        .buttonStyle(AlbumTextActionButtonStyle())
        .accessibilityLabel("Letzte Entscheidung rückgängig")
        .disabled(committing)
    }

    @ViewBuilder
    private func decisionButton(_ place: Place, frank: Bool) -> some View {
        Button { act(place, frank: frank) } label: {
            Label(frank ? "Ja" : "Nein", systemImage: frank ? "checkmark" : "xmark")
                .font(.headline)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(AlbumActionButtonStyle(primary: frank))
    }

    /// Die hinteren Marken fächern kurz weiter auf und legen sich per Feder auf ihre Lage;
    /// nur beim Erscheinen und wenn eine neue Marke oben liegt.
    private func spread() {
        guard !reduceMotion else { return }
        var instant = Transaction(animation: nil); instant.disablesAnimations = true
        withTransaction(instant) { fan = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { fan = 0 }
        }
    }

    private func openPhoto(_ place: Place, from source: CGRect) {
        guard !committing else { return }
        var instant = Transaction(animation: nil); instant.disablesAnimations = true
        withTransaction(instant) { viewer = PhotoViewerItem(place: place, source: source) }
    }

    /// Nur was du nicht schon weißt: wer außer dir die Idee gesammelt hat und wer schon dafür ist.
    private func authorLine(_ place: Place) -> String? {
        let fromPartner = place.author != store.me && place.author.localizedCaseInsensitiveCompare("Wir") != .orderedSame
        let others = place.approvals.filter { $0 != store.me }
        var parts: [String] = []
        if fromPartner { parts.append("Von \(place.author)") }
        if !others.isEmpty { parts.append(ListFormatter.localizedString(byJoining: others) + (others.count == 1 ? " ist dafür" : " sind dafür")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func dragGesture(for place: Place) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !committing else { return }
                let t = value.translation
                if abs(t.width) >= abs(t.height) {
                    offset = CGSize(width: rubberBanded(t.width), height: 0)
                    if !reduceMotion { hold(value) }
                } else if t.height < 0 {
                    offset = CGSize(width: 0, height: rubberBanded(t.height))
                }
                let armed = progress >= 1 || openProgress >= 1
                if armed && !thresholdArmed { thresholdFeedback += 1 }
                thresholdArmed = armed
            }
            .onEnded { value in
                release()
                thresholdArmed = false
                if offset.height < 0 {
                    if InboxSwipeResolver.shouldOpen(
                        actual: value.translation.height,
                        predicted: value.predictedEndTranslation.height,
                        threshold: decisionThreshold
                    ) {
                        markOpen(place)
                    }
                } else {
                    if let decision = InboxSwipeResolver.horizontalDecision(
                        actual: value.translation.width,
                        predicted: value.predictedEndTranslation.width,
                        threshold: decisionThreshold
                    ) {
                        act(place, frank: decision)
                    }
                }
                if !committing {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.78)) { offset = .zero }
                }
            }
    }

    /// Marke in der Hand: hebt sich an und neigt sich mit der Ziehgeschwindigkeit (geglättet, höchstens ±12°).
    private func hold(_ value: DragGesture.Value) {
        if lift == 0 { withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { lift = 1 } }
        if let last = lastSample {
            let dt = value.time.timeIntervalSince(last.time)
            if dt > 0.008 {
                let velocity = Double(value.translation.width - last.x) / dt
                tilt = tilt * 0.7 + (velocity / 1000 * 12).clamped(to: -12...12) * 0.3
                lastSample = (value.translation.width, value.time)
            }
        } else {
            lastSample = (value.translation.width, value.time)
        }
        // Hält der Finger inne, richtet sich die Marke wieder auf.
        tiltDecay?.cancel()
        tiltDecay = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { tilt = 0 }
        }
    }

    private func release() {
        tiltDecay?.cancel(); lastSample = nil
        withAnimation(reduceMotion ? nil : Stitch.Motion.decisionReturn) { tilt = 0; lift = 0 }
    }

    private func rubberBanded(_ value: CGFloat) -> CGFloat {
        let limit: CGFloat = 190
        guard abs(value) > limit else { return value }
        return value.sign == .minus ? -limit - sqrt(abs(value) - limit) * 4 : limit + sqrt(value - limit) * 4
    }

    /// Offen: Die Marke geht nur für diesen Durchgang aus dem Weg, ohne Stimme und ohne Abgleich.
    private func markOpen(_ place: Place) {
        guard !committing else { return }
        lastAction = place
        lastActionWasOpen = true
        feedback += 1
        if reduceMotion { openThisPassIDs.insert(place.id); offset = .zero; return }
        committing = true
        withAnimation(.easeIn(duration: 0.24)) { offset = CGSize(width: 0, height: -700) } completion: {
            openThisPassIDs.insert(place.id)
            offset = .zero
            committing = false
        }
    }

    private func act(_ place: Place, frank: Bool) {
        guard !committing else { return }
        let changed = store.decided(place, approve: frank)
        departingPlace = reduceMotion ? nil : place
        committing = !reduceMotion
        guard store.upsert(changed) else {
            departingPlace = nil
            committing = false
            offset = .zero
            return
        }
        lastAction = place
        lastActionWasOpen = false
        let bothAgree = frank && store.isShared(changed)
        if reduceMotion { feedback += 1; if bothAgree { magnetTick += 1 }; offset = .zero; return }
        if frank {
            // Frankieren: Der Poststempel wird mit Nachdruck aufs Foto gesetzt.
            withAnimation(.easeOut(duration: 0.2)) { offset = .zero }
            withAnimation(.spring(response: 0.26, dampingFraction: 0.55)) { stamp = 1 } completion: {
                stampTick += 1
                guard bothAgree else { fly(to: 640); return }
                // Ihr seid beide dafür: Die Herzhälften schnappen zusammen, dann fliegt die Marke.
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { magnet = 1 } completion: {
                    magnetTick += 1
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(450))
                        fly(to: 640)
                    }
                }
            }
        } else {
            feedback += 1
            fly(to: -640)
        }
    }

    private func fly(to target: CGFloat) {
        Task { @MainActor in
            if target > 0 { try? await Task.sleep(for: .milliseconds(260)) }
            withAnimation(.easeIn(duration: 0.26)) { offset = CGSize(width: target, height: 0) } completion: {
                offset = .zero
                stamp = 0
                magnet = 0
                departingPlace = nil
                committing = false
            }
        }
    }
}

private enum InboxSection: String, CaseIterable, Identifiable {
    case discover, all, deferred, collection
    var id: String { rawValue }
    var title: String {
        switch self {
        case .discover: "Entdecken"
        case .all: "Alle"
        case .deferred: "Weggelegt"
        case .collection: "Sammlung"
        }
    }
}

private struct AllIdeasView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var query: String
    let open: (String) -> Void

    private var filteredPlaces: [Place] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return store.places }
        return store.places.filter { place in
            [place.title, place.category, place.address, place.note]
                .contains { $0.localizedCaseInsensitiveContains(term) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            HStack(spacing: Stitch.Space.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Stitch.inkSoft)
                    .accessibilityHidden(true)
                TextField("Ideen suchen", text: $query)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("Ideas-All-Search")
                if !query.isEmpty {
                    Button("Suche löschen", systemImage: "xmark.circle.fill") { query = "" }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(Stitch.inkSoft)
                        .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("Ideas-All-Search-Clear")
                }
            }
            .padding(.horizontal, Stitch.Space.s)
            .frame(minHeight: Stitch.Size.touch)
            .background(Stitch.paperDeep, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))

            Text(filteredPlaces.count == 1 ? "1 Idee" : "\(filteredPlaces.count) Ideen")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Stitch.inkSoft)
                .accessibilityIdentifier("Ideas-All-Count")
                .accessibilityValue("\(filteredPlaces.count) von \(store.places.count)")

            ScrollView {
                LazyVStack(spacing: Stitch.Space.s) {
                    if filteredPlaces.isEmpty {
                        ContentUnavailableView {
                            Label(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Noch keine Ideen" : "Keine Treffer", systemImage: "magnifyingglass")
                        } description: {
                            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                 ? "Gespeicherte Ideen erscheinen hier."
                                 : "Versuche einen anderen Titel, Ort oder Begriff.")
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .accessibilityIdentifier("Ideas-All-Empty")
                    } else {
                        ForEach(filteredPlaces) { place in
                            ideaRow(place)
                        }
                    }
                }
                .padding(.vertical, Stitch.Space.xs)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("Ideas-All-List")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func ideaRow(_ place: Place) -> some View {
        Button { open(place.id) } label: {
            HStack(alignment: .top, spacing: Stitch.Space.m) {
                AlbumPhoto(asset: place.image, root: store.root, fallbackLocation: place.coordinate.map {
                    ResolvedPlaceIdentity(title: place.title, latitude: $0.latitude, longitude: $0.longitude,
                                          category: place.category, address: place.address)
                })
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                    Text(place.title.isEmpty ? "Neue Idee" : place.title)
                        .font(Stitch.Face.place(21, relativeTo: .headline))
                        .foregroundStyle(Stitch.ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(place.category)
                        .font(.subheadline)
                        .foregroundStyle(Stitch.inkSoft)
                        .lineLimit(1)
                    Text(status(for: place))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Stitch.inkSoft)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Stitch.inkSoft)
                    .padding(.top, Stitch.Space.xs)
                    .accessibilityHidden(true)
            }
            .padding(Stitch.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous).strokeBorder(Stitch.rule))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Ideas-All-Row-\(place.id)")
        .accessibilityLabel("\(place.title.isEmpty ? "Neue Idee" : place.title), \(place.category), \(status(for: place))")
    }

    private func status(for place: Place) -> String {
        if place.franked { return "Im Reiseplan" }
        if place.passedBy.contains(store.me) || (place.deferred && place.passedBy.isEmpty) { return "Weggelegt" }
        let approvals = place.approvals.filter { !$0.isEmpty }
        if approvals.contains(store.me) {
            return approvals.count > 1 ? "Deine Zusage · weitere Zusagen" : "Deine Zusage"
        }
        if let first = approvals.first {
            return approvals.count == 1 ? "Zusage von \(first)" : "\(approvals.count) Zusagen"
        }
        return "Offen"
    }
}

private struct DeferredIdeasView: View {
    let places: [Place]
    let root: URL
    let edit: (Place) -> Void
    let restore: (Place) -> Void
    let restoreAll: () -> Void

    var body: some View {
        if places.isEmpty {
            ContentUnavailableView {
                Label("Nichts weggelegt", systemImage: "tray")
            } description: {
                Text("Ideen, die du mit Nein beantwortest, kannst du hier später wieder ansehen.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("Deferred-Ideas-Empty")
        } else {
            ScrollView {
                LazyVStack(spacing: Stitch.Space.s) {
                    ForEach(places) { place in
                        HStack(spacing: Stitch.Space.m) {
                            AlbumPhoto(asset: place.image, root: root, fallbackLocation: place.coordinate.map {
                                ResolvedPlaceIdentity(title: place.title, latitude: $0.latitude, longitude: $0.longitude,
                                                     category: place.category, address: place.address)
                            })
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                            .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                                Text(place.title.isEmpty ? "Neue Idee" : place.title)
                                    .font(Stitch.Face.place(21, relativeTo: .headline))
                                    .foregroundStyle(Stitch.ink)
                                    .lineLimit(2)
                                    .accessibilityIdentifier("Deferred-Idea-\(place.id)-Title")
                                Text([place.category, place.sourceLabel].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.subheadline)
                                    .foregroundStyle(Stitch.inkSoft)
                                    .lineLimit(2)
                                Button("Idee ansehen") { edit(place) }
                                    .font(.subheadline.weight(.medium))
                                    .buttonStyle(AlbumTextActionButtonStyle())
                                    .accessibilityLabel("Idee ansehen: \(place.title)")
                            }
                            Spacer(minLength: 0)
                            Button {
                                restore(place)
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                                    .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(HeaderIconButton())
                            .accessibilityLabel("Idee wiederherstellen: \(place.title)")
                            .accessibilityIdentifier("Deferred-Idea-\(place.id)-Restore")
                        }
                        .padding(Stitch.Space.s)
                        .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous).strokeBorder(Stitch.rule))
                    }

                    Button("Alle Ideen zurückholen", action: restoreAll)
                        .buttonStyle(AlbumTextActionButtonStyle())
                        .padding(.top, Stitch.Space.xs)
                        .accessibilityIdentifier("Deferred-Ideas-Restore-All")
                }
                .padding(.vertical, Stitch.Space.s)
            }
            .accessibilityIdentifier("Deferred-Ideas-List")
        }
    }
}

private enum InboxDecision { case shelve, frank, open }

/// Zwei Herzhälften (Rot und Teal), die von links und rechts zusammenschnappen.
private struct MagnetHearts: View {
    let progress: CGFloat
    var body: some View {
        ZStack {
            half(leading: true).offset(x: -90 * (1 - progress))
            half(leading: false).offset(x: 90 * (1 - progress))
        }
        .scaleEffect(0.9 + 0.1 * progress)
        .padding(.bottom, 60)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    private func half(leading: Bool) -> some View {
        Image(systemName: "heart.fill").font(.system(size: 96)).foregroundStyle(leading ? Stitch.ink : Stitch.teal)
            .mask(alignment: leading ? .leading : .trailing) {
                Rectangle().frame(width: 53)
            }
            .stitchElevation(.pinned)
    }
}

private struct DecisionHint: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let direction: InboxDecision?
    let progress: CGFloat
    var body: some View {
        if let direction {
            let armed = progress >= 1
            let ink = direction == .frank ? Stitch.ink : direction == .shelve ? Stitch.ink : Stitch.teal
            let word = direction == .frank ? "Ja" : direction == .shelve ? "Nein" : "Offen"
            Text(word + (armed ? "" : "?"))
                .font(Stitch.Face.title(24, relativeTo: .title2))
                .contentTransition(.interpolate)
                .foregroundStyle(armed ? Stitch.onAccent : ink)
                .padding(.horizontal, Stitch.Space.m).padding(.vertical, Stitch.Space.xs)
                .background {
                    // Stempelfarbe füllt die Pille mit dem Weg; an der Schwelle ist sie voll.
                    GeometryReader { box in
                        ZStack(alignment: direction == .shelve ? .trailing : .leading) {
                            Stitch.card
                            ink.frame(width: box.size.width * progress)
                        }
                    }
                }
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(ink, lineWidth: 2))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: armed)
                .phaseAnimator([1.0, reduceMotion ? 1.0 : 1.08, 1.0], trigger: armed) { content, scale in
                    content.scaleEffect(scale)
                } animation: { _ in .spring(response: 0.22, dampingFraction: 0.5) }
                .rotationEffect(.degrees(direction == .frank ? -8 : direction == .shelve ? 8 : 0))
                .opacity(Double(min(progress * 4, 1)))
                .scaleEffect(0.85 + 0.15 * progress)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: direction == .frank ? .topLeading : direction == .shelve ? .topTrailing : .bottom)
                .padding(Stitch.Space.xl)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Eine Idee als große Briefmarke: Foto im Pastellrand ihrer Kategorie, Name in Serif, Quelle darunter.
/// `stamp` 0…1 setzt den Poststempel aufs Foto (frankiert).
struct IdeaStamp: View {
    let place: Place
    let root: URL
    var stamp: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var captionBudget: CGFloat = 132
    /// Tippen auf das Foto; liefert dessen Rahmen auf dem Bildschirm.
    var onPhotoTap: ((CGRect) -> Void)?

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 0) {
                photo(height: 180)
                caption
            }
            .background(Stitch.card)
            .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous).strokeBorder(Stitch.rule))
        } else {
            GeometryReader { geo in
                VStack(alignment: .leading, spacing: 0) {
                    photo(height: max(112, geo.size.height - captionBudget))
                    caption
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .background(Stitch.card)
                .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous).strokeBorder(Stitch.rule))
            }
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
            Text(place.title.isEmpty ? "Neue Idee" : place.title)
                .font(Stitch.Face.place(30, relativeTo: .title)).foregroundStyle(Stitch.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("\(place.title.isEmpty ? "Neue Idee" : place.title), \(place.sourceURL.isEmpty ? place.category : "\(place.sourceLabel), \(place.category)")")
            HStack(spacing: Stitch.Space.xs) {
                if let source = LinkValidation.url(place.sourceURL) {
                    Link(destination: source) {
                        Label("\(place.sourceLabel) · \(place.category)", systemImage: sourceIcon)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: Stitch.Size.touch, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Quelle öffnen: \(place.sourceLabel)")
                    .accessibilityIdentifier("idea-source-link")
                    Link(destination: place.mapLink) {
                        Image(systemName: "map")
                            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Ort in Karten öffnen")
                    .accessibilityIdentifier("idea-map-link")
                } else {
                    Link(destination: place.mapLink) {
                        Label("Ort ansehen · \(place.category)", systemImage: "map")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: Stitch.Size.touch, alignment: .leading)
                    }
                    .accessibilityLabel("Ort in Karten suchen: \(place.title)")
                    .accessibilityIdentifier("idea-map-link")
                }
            }
            .foregroundStyle(Stitch.inkSoft)
            .layoutPriority(1)
        }
        .padding(.horizontal, Stitch.Space.s).padding(.vertical, Stitch.Space.s)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Stitch.card)
    }

    private func photo(height: CGFloat) -> some View {
        AlbumPhoto(asset: place.image, root: root, fallbackLocation: place.coordinate.map {
            ResolvedPlaceIdentity(title: place.title, latitude: $0.latitude, longitude: $0.longitude, category: place.category, address: place.address)
        })
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .overlay {
                if let onPhotoTap {
                    GeometryReader { photo in
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { onPhotoTap(photo.frame(in: .global)) }
                    }
                    .accessibilityElement().accessibilityLabel("Foto vergrößern").accessibilityAddTraits(.isButton)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Postmark(bottom: "FRANKIERT", size: 92)
                    .scaleEffect(1.8 - 0.8 * stamp)
                    .opacity(Double(stamp))
                    .padding(Stitch.Space.s)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }

    private var sourceIcon: String {
        switch place.sourceLabel {
        case "TikTok": "music.note"
        case "Instagram": "camera"
        case "Gesammelt": "square.and.pencil"
        default: "link"
        }
    }
}

private struct PhotoViewerItem: Identifiable {
    let id = UUID()
    let place: Place
    let source: CGRect
}

/// Foto im Vollbild. Wächst aus der Marke, nach unten ziehen schrumpft es zurück (halbe Geste = halbe Verkleinerung).
/// Mit `photo` zeigt es ein bestimmtes Foto des Ortes (Foto-Stapel), sonst das Hauptfoto.
struct PhotoViewer: View {
    let place: Place
    let root: URL
    let source: CGRect
    var photo: PlaceImageAsset?
    private var asset: PlaceImageAsset? { photo ?? place.image }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = an der Stelle der Marke, 1 = groß.
    @State private var open: CGFloat = 0
    @State private var pull: CGSize = .zero
    @State private var closing = false
    /// 0…1 nach unten gezogen; 300 pt ziehen halbieren den Weg zurück zur Marke.
    private var shrink: CGFloat { min(max(pull.height / 300, 0), 1) }
    private var fitProgress: CGFloat {
        let reveal = min(max((open - 0.82) / 0.18, 0), 1)
        return reveal * (1 - shrink)
    }

    var body: some View {
        GeometryReader { geo in
            let full = CGRect(x: 0, y: 0, width: geo.size.width, height: min(geo.size.height * 0.72, geo.size.width * 1.3))
                .offsetBy(dx: 0, dy: geo.size.height * 0.46 - min(geo.size.height * 0.72, geo.size.width * 1.3) / 2)
            let t = reduceMotion ? 1 : open * (1 - 0.5 * shrink)
            let mix = { (a: CGFloat, b: CGFloat) in a + (b - a) * t }
            ZStack {
                Stitch.scrim.opacity(reduceMotion ? open : t)
                AlbumPhoto(asset: asset, root: root, fitProgress: fitProgress)
                    .frame(width: mix(source.width, full.width), height: mix(source.height, full.height))
                    .position(x: mix(source.midX, full.midX) + pull.width * open, y: mix(source.midY, full.midY) + pull.height * open)
                    .opacity(reduceMotion ? open : 1)
                    .gesture(reduceMotion ? nil : drag)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Foto von \(place.title)").accessibilityAddTraits(.isImage)

                VStack {
                    HStack {
                        Spacer()
                        Button { close() } label: { Image(systemName: "xmark") }
                            .buttonStyle(HeaderIconButton())
                            .accessibilityLabel("Foto schließen")
                    }
                    Spacer()
                    if case .external(let image) = asset {
                        Text("Foto: \(image.credit)\(image.licenseName.map { " · \($0)" } ?? "")")
                            .font(.caption).foregroundStyle(Stitch.onAccent.opacity(0.85)).multilineTextAlignment(.center)
                    }
                }
                .safeAreaPadding()
                .padding(Stitch.Space.page)
                .opacity(Double(open * (1 - shrink)))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .presentationBackground(.clear)
        .onAppear {
            withAnimation(reduceMotion ? Stitch.Motion.reducedFade : .spring(response: 0.42, dampingFraction: 0.86)) { open = 1 }
        }
        .accessibilityAction(.escape) { close() }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !closing else { return }
                pull = CGSize(width: value.translation.width, height: value.translation.height > 0 ? value.translation.height : value.translation.height / 4)
            }
            .onEnded { value in
                guard !closing else { return }
                if pull.height > 110 || value.predictedEndTranslation.height > 320 { close() }
                else { withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) { pull = .zero } }
            }
    }

    private func close() {
        guard !closing else { return }
        closing = true
        withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.32)) { open = 0; pull = .zero } completion: {
            var instant = Transaction(animation: nil); instant.disablesAnimations = true
            withTransaction(instant) { dismiss() }
        }
    }
}
