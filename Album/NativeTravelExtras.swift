import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

public struct NativeExpensesView: View {
    @Environment(AlbumStore.self) private var store
    @State private var showingEditor = false
    @State private var showingSettlement = false

    public init() {}

    private var expenses: [TravelExpense] { store.data.trip.expenses ?? [] }
    private var settlements: [TravelSettlement] { store.data.trip.settlements ?? [] }
    private var balances: [String: Int] { TravelLedger.balances(expenses: expenses, settlements: settlements) }
    private var transfers: [TravelTransfer] { TravelLedger.transfers(expenses: expenses, settlements: settlements) }
    private var participants: [String] {
        var names = [store.me]
        names.append(contentsOf: store.data.trip.travelers ?? [])
        names.append(contentsOf: expenses.flatMap { [$0.payer] + $0.participants })
        var seen = Set<String>()
        return names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .sorted { $0 == store.me ? true : $1 == store.me ? false : $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.l) {
                    balanceHeader
                    if expenses.isEmpty {
                        emptyState
                    } else {
                        expenseList
                    }
                }
                .padding(.horizontal, Stitch.Space.page)
                .padding(.top, Stitch.Space.s)
                .padding(.bottom, Stitch.Space.xxl)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(PaperBackground())
            .navigationTitle("Ausgaben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingEditor = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Ausgabe hinzufügen")
                        .accessibilityIdentifier("expenses-add")
                }
            }
            .sheet(isPresented: $showingEditor) {
                NativeExpenseEditor(participants: participants) { expense in
                    var trip = store.data.trip
                    trip.expenses = (trip.expenses ?? []) + [expense]
                    return store.updateTrip(trip)
                }
            }
            .sheet(isPresented: $showingSettlement) {
                NativeSettlementView(transfers: transfers) { entries in
                    var trip = store.data.trip
                    trip.settlements = (trip.settlements ?? []) + entries
                    return store.updateTrip(trip)
                }
            }
        }
        .accessibilityIdentifier("NativeExpensesView")
    }

    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Text("Euer Ledger")
                .font(Stitch.Face.display(34, relativeTo: .largeTitle))
                .foregroundStyle(Stitch.ink)
                .accessibilityAddTraits(.isHeader)
            if expenses.isEmpty {
                Text("Noch keine Ausgabe eingetragen")
                    .font(.subheadline).foregroundStyle(Stitch.inkSoft)
            } else {
                let mine = balances[store.me, default: 0]
                Text(balanceText(mine))
                    .font(.title3.weight(.semibold)).foregroundStyle(mine == 0 ? Stitch.ink : Stitch.red)
                Text("Gesamt \(money(expenses.reduce(0) { $0 + $1.amountCents })) · \(expenses.count) \(expenses.count == 1 ? "Ausgabe" : "Ausgaben")")
                    .font(.subheadline).foregroundStyle(Stitch.inkSoft)
            }
            if !transfers.isEmpty {
                Button("Ausgleichen") { showingSettlement = true }
                    .buttonStyle(StitchButton(primary: true))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("expenses-settle")
            }
        }
        .padding(Stitch.Space.m)
        .stitchCard(.pinned)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Image(systemName: "wallet.bifold")
                .font(.title2).foregroundStyle(Stitch.red).accessibilityHidden(true)
            Text("Noch keine Ausgaben")
                .font(.headline).foregroundStyle(Stitch.ink)
            Text("Tragt die erste Ausgabe ein, sobald ihr unterwegs etwas gemeinsam bezahlt habt.")
                .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button("Ausgabe hinzufügen") { showingEditor = true }
                .buttonStyle(TextActionButton())
                .accessibilityIdentifier("expenses-empty-add")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stitchCard()
    }

    private var expenseList: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Text("Eingetragen")
                .font(.headline).foregroundStyle(Stitch.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(expenses) { expense in
                HStack(spacing: Stitch.Space.m) {
                    Image(systemName: "fork.knife")
                        .font(.title3).foregroundStyle(Stitch.red)
                        .frame(width: 44, height: 44)
                        .background(Stitch.paperDeep, in: Circle())
                    VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                        Text(expense.title).font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
                        Text("\(expense.payer) bezahlt · \(expense.participants.count) Beteiligte")
                            .font(.footnote).foregroundStyle(Stitch.inkSoft)
                    }
                    Spacer(minLength: 0)
                    Text(money(expense.amountCents))
                        .font(.body.monospacedDigit().weight(.semibold)).foregroundStyle(Stitch.ink)
                }
                .frame(minHeight: Stitch.Size.touch)
                .stitchCard(padding: Stitch.Space.s)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(expense.title), \(money(expense.amountCents)), bezahlt von \(expense.payer)")
            }
        }
    }

    private func balanceText(_ cents: Int) -> String {
        if cents == 0 { return "Alles ausgeglichen" }
        return cents > 0 ? "Du bekommst \(money(cents))" : "Du schuldest \(money(-cents))"
    }

    private func money(_ cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "\(cents) ct"
    }
}

private struct NativeExpenseEditor: View {
    @Environment(\.dismiss) private var dismiss
    let initialParticipants: [String]
    let onSave: (TravelExpense) -> Bool
    @State private var title = ""
    @State private var amount = ""
    @State private var currency: TravelCurrency = .eur
    @State private var rate = "25"
    @State private var payer: String
    @State private var selected: Set<String>
    @State private var newParticipant = ""
    @State private var addedParticipants: [String] = []
    @State private var error: String?

    init(participants: [String], onSave: @escaping (TravelExpense) -> Bool) {
        initialParticipants = participants
        self.onSave = onSave
        _payer = State(initialValue: participants.first ?? "Ich")
        _selected = State(initialValue: Set(participants))
    }

    private var participantList: [String] {
        var names = initialParticipants
        names.append(contentsOf: addedParticipants)
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ausgabe") {
                    TextField("Titel", text: $title)
                        .accessibilityIdentifier("expense-title")
                    HStack {
                        TextField("Betrag", text: $amount)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("expense-amount")
                        Picker("Währung", selection: $currency) {
                            ForEach(TravelCurrency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    if currency == .czk {
                        TextField("Manueller Kurs (CZK für 1 EUR)", text: $rate)
                            .keyboardType(.decimalPad)
                        Text("Manueller Kurs · \(rate.isEmpty ? "25" : rate) CZK = 1,00 EUR (Näherung)")
                            .font(.footnote).foregroundStyle(Stitch.inkSoft)
                    }
                }
                Section("Bezahlt von") {
                    Picker("Person", selection: $payer) {
                        ForEach(participantList, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Aufteilen auf") {
                    ForEach(participantList, id: \.self) { person in
                        Toggle(person, isOn: Binding(get: { selected.contains(person) }, set: { on in
                            if on { selected.insert(person) } else { selected.remove(person) }
                        }))
                    }
                    HStack {
                        TextField("Person hinzufügen", text: $newParticipant)
                            .accessibilityIdentifier("expense-person-name")
                        Button("Hinzufügen") {
                            let name = newParticipant.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            guard !participantList.contains(name) else { newParticipant = ""; return }
                            addedParticipants.append(name)
                            selected.insert(name)
                            if !participantList.contains(payer) { payer = initialParticipants.first ?? name }
                            newParticipant = ""
                        }
                        .disabled(newParticipant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("expense-add-person")
                    }
                }
                if let error { Text(error).font(.footnote).foregroundStyle(Stitch.red) }
            }
            .scrollContentBackground(.hidden).background(PaperBackground())
            .navigationTitle("Ausgabe hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount.isEmpty || selected.isEmpty)
                        .accessibilityIdentifier("expense-save")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        do {
            let expense = try TravelExpense.make(title: title, amountText: amount, currency: currency,
                                                  exchangeRateText: currency == .czk ? rate : nil,
                                                  payer: payer, participants: participantList.filter { selected.contains($0) })
            guard onSave(expense) else { error = "Die Ausgabe konnte nicht gespeichert werden."; return }
            dismiss()
        } catch let value as TravelExpenseError { error = value.localizedDescription }
        catch { self.error = error.localizedDescription }
    }
}

private struct NativeSettlementView: View {
    @Environment(\.dismiss) private var dismiss
    let transfers: [TravelTransfer]
    let onConfirm: ([TravelSettlement]) -> Bool
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Stitch.Space.m) {
                Text("Diese Ausgleiche werden nur im Album vermerkt.")
                    .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                ForEach(transfers) { transfer in
                    HStack {
                        Text("\(transfer.from) → \(transfer.to)")
                        Spacer()
                        Text(money(transfer.amountCents)).font(.body.monospacedDigit().weight(.semibold))
                    }
                    .frame(minHeight: Stitch.Size.touch)
                    .stitchCard(padding: Stitch.Space.s)
                }
                if let error { Text(error).font(.footnote).foregroundStyle(Stitch.red) }
                Spacer()
            }
            .padding(Stitch.Space.page)
            .background(PaperBackground())
            .navigationTitle("Ausgleichen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Als ausgeglichen markieren") {
                        let entries = transfers.map { TravelSettlement(from: $0.from, to: $0.to, amountCents: $0.amountCents) }
                        if onConfirm(entries) { dismiss() } else { error = "Der Ausgleich konnte nicht gespeichert werden." }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func money(_ cents: Int) -> String {
        let formatter = NumberFormatter(); formatter.locale = Locale(identifier: "de_DE"); formatter.numberStyle = .currency; formatter.currencyCode = "EUR"
        return formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "\(cents) ct"
    }
}

public struct NativeMemoriesView: View {
    @Environment(AlbumStore.self) private var store
    @State private var targetPicker = false
    @State private var addPlace = false
    @State private var source: MemoryCaptureSource?
    @State private var targetID: String?
    @State private var replaceConfirmation = false
    @State private var cameraPresented = false
    @State private var cameraUnavailable = false
    @State private var photoPickerPresented = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var viewing: NativeMemoryPhoto?
    @State private var error: String?

    public init() {}

    private var photoPlaces: [Place] {
        store.places.filter { $0.image != nil }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                if photoPlaces.isEmpty {
                    emptyState
                } else {
                    photoGrid
                }
            }
            .background(PaperBackground())
            .navigationTitle("Erinnerungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { beginCapture(.library) } label: { Label("Foto aus Mediathek", systemImage: "photo.on.rectangle") }
                        .accessibilityIdentifier("memories-library")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { beginCapture(.camera) } label: {
                    Image(systemName: "camera.fill").font(.title2.weight(.semibold)).frame(width: 72, height: 72)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Stitch.onAccent)
                .background(Stitch.redFill, in: Circle())
                .frame(width: 72, height: 72)
                .contentShape(Circle())
                .accessibilityLabel("Mit Kamera fotografieren")
                .accessibilityIdentifier("memories-camera")
                .padding(.bottom, Stitch.Space.s)
            }
            .sheet(isPresented: $targetPicker, onDismiss: {
                guard targetID != nil else { source = nil; return }
                openCaptureAfterConfirmation()
            }) { targetPickerView }
            .sheet(isPresented: $addPlace) { PlaceEditor(place: Place(title: "Neue Reiseidee")) }
            .sheet(isPresented: $cameraPresented) {
                CameraImagePicker { imageData in
                    cameraPresented = false
                    if let imageData { save(data: imageData) }
                } onCancel: { cameraPresented = false }
            }
            .photosPicker(isPresented: $photoPickerPresented, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoLoadTask?.cancel()
                let capturedTargetID = targetID
                photoLoadTask = Task {
                    do {
                        let data = try await item.loadTransferable(type: Data.self)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            guard self.targetID == capturedTargetID, self.photoItem != nil else { return }
                            save(data: data, targetID: capturedTargetID)
                        }
                    } catch {
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            guard self.targetID == capturedTargetID else { return }
                            self.error = "Das Foto konnte nicht geladen werden."
                        }
                    }
                    await MainActor.run {
                        if self.targetID == capturedTargetID { photoItem = nil }
                        photoLoadTask = nil
                    }
                }
            }
            .confirmationDialog("Vorhandenes Foto ersetzen?", isPresented: $replaceConfirmation, titleVisibility: .visible) {
                Button("Foto ersetzen", role: .destructive) {
                    guard let source else { return }
                    openCapture(source)
                }
                Button("Abbrechen", role: .cancel) { source = nil; targetID = nil }
            } message: {
                Text(replacementMessage)
            }
            .alert("Kamera nicht verfügbar", isPresented: $cameraUnavailable) {
                Button("Schließen", role: .cancel) {}
            } message: {
                Text("Auf diesem Gerät ist keine Kamera verfügbar. Nutze die Mediathek oder einen echten iPhone-Simulator.")
            }
            .alert("Foto konnte nicht gespeichert werden", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Schließen", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
            .fullScreenCover(item: $viewing) { photo in
                NativeMemoryZoom(place: photo.place, asset: photo.asset, root: store.root)
            }
            .onDisappear {
                photoLoadTask?.cancel()
                photoLoadTask = nil
            }
        }
        .accessibilityIdentifier("NativeMemoriesView")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Image(systemName: "photo.on.rectangle.angled").font(.title2).foregroundStyle(Stitch.red)
            Text(store.places.isEmpty ? "Noch keine Orte" : "Noch keine Fotos")
                .font(.headline).foregroundStyle(Stitch.ink)
            Text(store.places.isEmpty
                 ? "Füge zuerst einen Ort hinzu, damit du ein Foto damit verbinden kannst."
                 : "Füge einem bestehenden Ort ein eigenes Foto hinzu.")
                .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button(store.places.isEmpty ? "Ort hinzufügen" : "Foto hinzufügen") {
                if store.places.isEmpty { addPlace = true } else { beginCapture(.camera) }
            }
                .buttonStyle(TextActionButton())
        }
        .padding(Stitch.Space.page)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Stitch.Space.s)], spacing: Stitch.Space.s) {
            ForEach(photoPlaces) { place in
                memoryCard(place)
            }
        }
        .padding(.horizontal, Stitch.Space.page)
        .padding(.top, Stitch.Space.s)
        .padding(.bottom, 110)
    }

    private func memoryCard(_ place: Place) -> some View {
        Button {
            if let asset = place.displayImage { viewing = NativeMemoryPhoto(place: place, asset: asset) }
            else { targetID = place.id; source = .library; openCaptureAfterConfirmation() }
        } label: {
            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                AlbumPhoto(asset: place.displayImage, root: store.root, thumbnailWidth: 500)
                    .frame(height: 150).clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
                Text(place.title).font(.body.weight(.semibold)).foregroundStyle(Stitch.ink).lineLimit(2)
                Text(place.image == nil ? "Foto ergänzen" : place.category)
                    .font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .stitchCard(padding: Stitch.Space.s)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(place.image == nil ? "\(place.title), Foto ergänzen" : "Foto von \(place.title), vergrößern")
    }

    private func beginCapture(_ requested: MemoryCaptureSource) {
        guard !store.places.isEmpty else { addPlace = true; return }
        source = requested; targetPicker = true
    }

    private var targetPickerView: some View {
        NavigationStack {
            List {
                Section("Foto zuordnen") {
                    ForEach(store.places) { place in
                        Button {
                            targetID = place.id; targetPicker = false
                        } label: {
                            HStack {
                                Image(systemName: place.image == nil ? "photo" : "photo.fill")
                                Text(place.title)
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote)
                            }
                            .frame(minHeight: Stitch.Size.touch)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(PaperBackground())
            .navigationTitle("Ort auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { targetID = nil; source = nil; targetPicker = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func openCaptureAfterConfirmation() {
        guard let targetID, let source else { return }
        if store.places.first(where: { $0.id == targetID })?.image != nil {
            replaceConfirmation = true
            return
        }
        openCapture(source)
    }

    private func openCapture(_ requested: MemoryCaptureSource) {
        switch requested {
        case .library: photoPickerPresented = true
        case .camera:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { cameraUnavailable = true; return }
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .denied, .restricted:
                cameraUnavailable = true
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    Task { @MainActor in
                        if granted { cameraPresented = true } else { cameraUnavailable = true }
                    }
                }
            case .authorized:
                cameraPresented = true
            @unknown default:
                cameraUnavailable = true
            }
        }
    }

    private func save(data: Data?, targetID capturedTargetID: String? = nil) {
        guard let data, let targetID = capturedTargetID ?? targetID,
              let place = store.places.first(where: { $0.id == targetID }) else { return }
        do {
            let uploaded = try PlaceImageStorage.save(data, root: store.root)
            var updated = place
            updated.image = .uploaded(uploaded)
            guard store.upsert(updated) else {
                PlaceImageStorage.remove(uploaded, root: store.root)
                error = "Das Foto konnte nicht gespeichert werden."
                return
            }
            source = nil; self.targetID = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var replacementMessage: String {
        guard let targetID, let place = store.places.first(where: { $0.id == targetID }), let image = place.image else {
            return "Das bisherige Foto dieses Orts wird ersetzt. Externe Galerie-Fotos bleiben erhalten."
        }
        if case .external = image {
            return "Das externe Ortsfoto wird durch dein neues Foto ersetzt. Externe Galerie-Fotos bleiben erhalten."
        }
        return "Das bisherige eigene Foto dieses Orts wird ersetzt. Externe Galerie-Fotos bleiben erhalten."
    }

    private enum MemoryCaptureSource { case camera, library }
    private struct NativeMemoryPhoto: Identifiable {
        let id = UUID(); let place: Place; let asset: PlaceImageAsset
    }
}

private struct NativeMemoryZoom: View {
    let place: Place
    let asset: PlaceImageAsset
    let root: URL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1

    var body: some View {
        ZStack {
            Stitch.scrim.ignoresSafeArea()
            AlbumPhoto(asset: asset, root: root, fitProgress: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(scale)
                .gesture(reduceMotion ? nil : MagnificationGesture().onChanged { value in scale = min(max(baseScale * value, 1), 4) }.onEnded { _ in baseScale = scale })
                .accessibilityLabel("Foto von \(place.title)")
            VStack { HStack { Spacer(); Button("Schließen", systemImage: "xmark") { dismiss() }.buttonStyle(.bordered).tint(.white).frame(minWidth: 44, minHeight: 44) }; Spacer() }
                .padding()
        }
        .statusBarHidden(true)
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    var onImage: (Data?) -> Void
    var onCancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage, onCancel: onCancel) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator; picker.allowsEditing = false; return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (Data?) -> Void; let onCancel: () -> Void
        init(onImage: @escaping (Data?) -> Void, onCancel: @escaping () -> Void) { self.onImage = onImage; self.onCancel = onCancel }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onImage((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.92))
        }
    }
}
