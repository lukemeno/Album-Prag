import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct AssistantBottomClearanceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct AssistantView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: AssistantSession
    @State private var draft = ""
    @State private var showClearConfirmation = false
    @State private var showPreferences = false
    @State private var selectedDocument: TravelDocument?
    @State private var selectedPlaceID: String?
    @State private var preparedPlace: Place?
    @State private var planToApply: [AssistantDay]?
    @State private var planMessageID: String?
    @State private var location: CLLocationCoordinate2D?
    @State private var locationText: String?
    @State private var preparingPlaceID: String?
    @State private var savedIdeaCounts: [String: String] = [:]
    @FocusState private var inputFocused: Bool

    /// The action closure is supplied by the root once the revision checked action layer is available.
    var onApplyPlan: (([AssistantDay], AlbumStore) throws -> Void)? = nil

    init(session: AssistantSession, onApplyPlan: (([AssistantDay], AlbumStore) throws -> Void)? = nil) {
        self.session = session
        self.onApplyPlan = onApplyPlan
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Stitch.Space.m) {
                        if session.messages.isEmpty { welcome }
                        ForEach(session.messages) { message in
                            messageView(message)
                                .id(message.id)
                        }
                        if session.isLoading { loading }
                        if let error = session.lastError, !session.isLoading { errorView(error) }
                        Color.clear.frame(height: 4).id("assistant-end")
                    }
                    .padding(.horizontal, Stitch.Space.page)
                    .padding(.top, Stitch.Space.s)
                    .padding(.bottom, Stitch.Space.s)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: session.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("assistant-end", anchor: .bottom) }
                }
                .onChange(of: session.isLoading) { _, loading in
                    if loading { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("assistant-end", anchor: .bottom) } }
                }
            }
            .background(PaperBackground())
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .navigationTitle("Reise-Assistent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Vorlieben bearbeiten", systemImage: "heart") { showPreferences = true }
                        Button("Unterhaltung löschen", systemImage: "trash", role: .destructive) { showClearConfirmation = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Assistant-Einstellungen")
                }
            }
            .sheet(isPresented: $showPreferences) { preferencesSheet }
            .sheet(item: $selectedDocument) { DocumentDetail(document: $0).environment(store) }
            .sheet(isPresented: Binding(get: { selectedPlaceID != nil }, set: { if !$0 { selectedPlaceID = nil } })) {
                if let selectedPlaceID { PlaceDetail(placeID: selectedPlaceID).environment(store) }
            }
            .sheet(item: $preparedPlace) { PlaceEditor(place: $0).environment(store) }
            .alert("Plan übernehmen?", isPresented: Binding(get: { planToApply != nil }, set: { if !$0 { planToApply = nil; planMessageID = nil } })) {
                Button("Übernehmen") { applyPlan() }
                Button("Abbrechen", role: .cancel) { planToApply = nil; planMessageID = nil }
            } message: { Text("Der Plan wird gegen die aktuelle Reise geprüft und erst jetzt gespeichert.") }
            .confirmationDialog("Unterhaltung löschen?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { session.clear() }
                Button("Abbrechen", role: .cancel) {}
            } message: { Text("Deine lokale Unterhaltung und deine persönlichen Vorlieben werden gelöscht.") }
        }
        .environment(store)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Text("Womit soll ich helfen?").font(Stitch.Face.display()).foregroundStyle(Stitch.ink)
            Text("Ich kenne deine Reise, gespeicherte Orte und ausgewählte Unterlagen. Änderungen zeige ich zuerst als Vorschlag.")
                .font(.body).foregroundStyle(Stitch.inkSoft)
            HStack(spacing: Stitch.Space.xs) {
                suggestion("Plane morgen")
                suggestion("Was passt jetzt?")
            }
            suggestion("Fragen zu Unterlagen")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stitchCard()
    }

    private func suggestion(_ text: String) -> some View {
        Button(text) { draft = text; send() }
            .buttonStyle(.bordered)
            .tint(Stitch.ink)
            .accessibilityIdentifier("assistant-suggestion-\(text.replacingOccurrences(of: " ", with: "-"))")
    }

    @ViewBuilder private func messageView(_ message: AssistantMessage) -> some View {
        VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: Stitch.Space.xs) {
            Text(message.text)
                .font(.body)
                .foregroundStyle(message.role == "user" ? .white : Stitch.ink)
                .textSelection(.enabled)
                .padding(.horizontal, Stitch.Space.m)
                .padding(.vertical, Stitch.Space.s)
                .background(message.role == "user" ? Stitch.ink : Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
                .overlay { if message.role != "user" { RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous).strokeBorder(Stitch.rule) } }
                .frame(maxWidth: message.role == "user" ? 320 : .infinity, alignment: message.role == "user" ? .trailing : .leading)
            if let reply = message.reply, message.role == "assistant" { replyCards(reply, messageID: message.id) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
    }

    @ViewBuilder private func replyCards(_ reply: AssistantReply, messageID: String) -> some View {
        if !reply.sources.isEmpty {
            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                Text("Quellen").font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                ForEach(reply.sources) { source in
                    sourceButton(source)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        if !reply.places.isEmpty {
            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                Text("Orte zum Prüfen").font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                ForEach(reply.places) { place in placeCard(place) }
                Button {
                    let result = store.saveAssistantIdeas(reply.places)
                    if result.added + result.restored == 0 && result.existing == 0 {
                        savedIdeaCounts[messageID] = "Speichern fehlgeschlagen. Bitte erneut versuchen."
                    } else {
                        var parts: [String] = []
                        if result.added > 0 { parts.append("\(result.added) hinzugefügt") }
                        if result.restored > 0 { parts.append("\(result.restored) wieder geöffnet") }
                        if result.existing > 0 { parts.append("\(result.existing) schon vorhanden") }
                        savedIdeaCounts[messageID] = parts.joined(separator: " · ")
                    }
                } label: {
                    Label("Alle als Ideen speichern", systemImage: "tray.and.arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: Stitch.Size.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AlbumActionButtonStyle(primary: true))
                .accessibilityIdentifier("assistant-save-all-ideas-\(messageID)")
                if let status = savedIdeaCounts[messageID] {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(status.hasPrefix("Speichern fehlgeschlagen") ? Stitch.red : Stitch.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("assistant-save-ideas-status-\(messageID)")
                }
                Text("Gespeicherte Orte erscheinen im Ideenstapel.")
                    .font(.caption2)
                    .foregroundStyle(Stitch.inkSoft)
            }
        }
        if !reply.plan.isEmpty {
            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                Text("Planvorschlag").font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                ForEach(reply.plan) { day in planCard(day) }
                if session.canApply(messageID: messageID) {
                    Button("Plan prüfen und übernehmen") {
                        planMessageID = messageID
                        planToApply = reply.plan
                    }.buttonStyle(AlbumActionButtonStyle(primary: true))
                } else {
                    Text("Dieser Plan ist nur noch als Verlauf verfügbar. Bitte die Frage erneut senden, um ihn zu prüfen und zu übernehmen.")
                        .font(.footnote)
                        .foregroundStyle(Stitch.inkSoft)
                }
                if session.canUndo(messageID: messageID) {
                    Button("Rückgängig") {
                        do { try session.undo(messageID: messageID) }
                        catch { session.lastError = error.localizedDescription }
                    }.buttonStyle(AlbumTextActionButtonStyle())
                }
            }
        }
        if !reply.preferences.isEmpty {
            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                Text("Als persönliche Vorliebe merken?").font(.caption.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                ForEach(reply.preferences, id: \.self) { preference in
                    HStack {
                        Text(preference).font(.subheadline).foregroundStyle(Stitch.ink)
                        Spacer()
                        Button("Merken") { session.remember(preference) }.buttonStyle(AlbumTextActionButtonStyle())
                    }
                    .stitchCard()
                }
            }
        }
    }

    private func sourceButton(_ source: AssistantSource) -> some View {
        Button {
            if let documentID = source.documentID, let document = store.data.documents.first(where: { $0.id == documentID }) { selectedDocument = document }
            else if let url = source.url.flatMap(LinkValidation.url) { UIApplication.shared.open(url) }
        } label: {
            HStack(alignment: .top, spacing: Stitch.Space.s) {
                Image(systemName: source.documentID != nil ? "doc.text" : "arrow.up.right.square").foregroundStyle(Stitch.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title).font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.ink)
                    if let quote = source.quote, !quote.isEmpty { Text(quote).font(.footnote).foregroundStyle(Stitch.inkSoft).lineLimit(3) }
                }
                Spacer(minLength: 0)
            }
            .stitchCard()
        }
        .buttonStyle(.plain)
        .disabled(source.documentID != nil && !store.data.documents.contains { $0.id == source.documentID })
    }

    private func placeCard(_ place: AssistantPlace) -> some View {
        HStack(spacing: Stitch.Space.s) {
            Image(systemName: "mappin.and.ellipse").foregroundStyle(Stitch.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.title).font(.headline).foregroundStyle(Stitch.ink)
                if !place.address.isEmpty { Text(place.address).font(.footnote).foregroundStyle(Stitch.inkSoft) }
            }
            Spacer(minLength: 0)
            if preparingPlaceID == place.id { ProgressView() }
            else { Button("Prüfen") { prepare(place) }.buttonStyle(AlbumTextActionButtonStyle()) }
        }
        .stitchCard()
    }

    private func planCard(_ day: AssistantDay) -> some View {
        let names = day.placeIDs.compactMap { id in store.places.first(where: { $0.id == id })?.title }
        return VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Text(TripDates.dayTitle(day.day)).font(.headline).foregroundStyle(Stitch.ink)
            Text(names.isEmpty ? day.note : names.joined(separator: " · ")).font(.subheadline).foregroundStyle(Stitch.ink)
            if !day.note.isEmpty && !names.isEmpty { Text(day.note).font(.footnote).foregroundStyle(Stitch.inkSoft) }
        }
        .stitchCard()
    }

    private var loading: some View {
        HStack(spacing: Stitch.Space.s) {
            ProgressView().tint(Stitch.ink)
            Text("Ich sehe kurz nach …").font(.subheadline).foregroundStyle(Stitch.inkSoft)
            Spacer()
            Button("Abbrechen") { session.cancel() }.buttonStyle(AlbumTextActionButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorView(_ error: String) -> some View {
        HStack(alignment: .top, spacing: Stitch.Space.s) {
            Image(systemName: "wifi.exclamationmark").foregroundStyle(Stitch.red)
            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                Text(error).font(.subheadline).foregroundStyle(Stitch.ink)
                HStack(spacing: Stitch.Space.s) {
                    Button("Erneut versuchen") { session.retry() }.buttonStyle(AlbumTextActionButtonStyle())
                    Text("Verlauf bleibt offline verfügbar.").font(.caption).foregroundStyle(Stitch.inkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stitchCard()
    }

    private var composer: some View {
        VStack(spacing: Stitch.Space.xs) {
            HStack(spacing: Stitch.Space.s) {
                TextField("Nachricht …", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textInputAutocapitalization(.sentences)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, Stitch.Space.s)
                    .padding(.vertical, Stitch.Space.xs)
                    .background(Stitch.card, in: RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous).strokeBorder(Stitch.rule) }
                    .accessibilityIdentifier("assistant-input")
                Button { send() } label: { Image(systemName: "arrow.up.circle.fill").font(.title).foregroundStyle(Stitch.ink) }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isLoading)
                    .accessibilityLabel("Senden")
                    .accessibilityIdentifier("assistant-send")
            }
            HStack {
                Button {
                    Task {
                        let coordinate = await session.useLocation()
                        await MainActor.run {
                            location = coordinate ?? store.hotelCoordinate
                            locationText = coordinate == nil ? "Ausgangspunkt der Reise" : "Aktueller Standort"
                        }
                    }
                } label: { Label(locationText ?? "Standort verwenden", systemImage: "location") }
                    .font(.caption)
                    .foregroundStyle(Stitch.inkSoft)
                Spacer()
                Toggle("Web-Recherche", isOn: $session.webSearch).font(.caption).tint(Stitch.ink)
                    .accessibilityHint("Nutzt zusätzlich aktuelle Quellen aus dem Web.")
            }
        }
        .padding(.horizontal, Stitch.Space.page)
        .padding(.top, Stitch.Space.s)
        .padding(.bottom, Stitch.Space.xs)
        .background(Stitch.paper)
        .overlay(alignment: .top) { Stitch.rule.frame(height: 1) }
    }

    private var preferencesSheet: some View {
        NavigationStack {
            List {
                if session.preferences.isEmpty { Text("Noch keine Vorlieben gemerkt.").foregroundStyle(Stitch.inkSoft) }
                ForEach(session.preferences, id: \.self) { preference in
                    HStack {
                        Text(preference)
                        Spacer()
                        Button("Löschen") { session.forget(preference) }.foregroundStyle(Stitch.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PaperBackground())
            .navigationTitle("Meine Vorlieben")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { showPreferences = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func send() {
        let text = draft
        draft = ""
        inputFocused = false
        session.send(text, location: location)
    }

    private func prepare(_ place: AssistantPlace) {
        guard preparingPlaceID == nil else { return }
        if let existingID = place.existingID, store.places.contains(where: { $0.id == existingID }) { selectedPlaceID = existingID; return }
        preparingPlaceID = place.id
        Task { @MainActor in
            defer { preparingPlaceID = nil }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = place.query.isEmpty ? [place.title, place.address].filter { !$0.isEmpty }.joined(separator: ", ") : place.query
            request.region = MKCoordinateRegion(center: store.hotelCoordinate, span: .init(latitudeDelta: 0.3, longitudeDelta: 0.3))
            let result = try? await MKLocalSearch(request: request).start()
            let item = result?.mapItems.first
            var prepared = Place(title: place.title, note: "Vom Assistenten vorgeschlagen", sourceURL: place.sourceURL ?? "", category: "Idee", author: store.me)
            prepared.address = item?.placemark.title ?? place.address
            if let coordinate = item?.placemark.coordinate { prepared.lat = coordinate.latitude; prepared.lng = coordinate.longitude }
            preparedPlace = prepared
        }
    }

    private func applyPlan() {
        guard let plan = planToApply else { return }
        let messageID = planMessageID
        planToApply = nil; planMessageID = nil
        guard let messageID else { return }
        Task { @MainActor in
            do {
                if let onApplyPlan { try onApplyPlan(plan, store) }
                else { try await session.applyPlan(plan, messageID: messageID) }
            } catch { session.lastError = error.localizedDescription }
        }
    }
}
