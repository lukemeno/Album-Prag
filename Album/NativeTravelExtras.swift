import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

public struct NativeExpensesView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editorRoute: ExpenseEditorRoute?
    @State private var showingSettlement = false
    @State private var feedbackTick = 0
    @State private var expenseToDelete: TravelExpense?
    @State private var showingDeleteConfirmation = false

    public init() {}

    private var expenses: [TravelExpense] { TravelLedger.visibleExpenses(store.data.trip.expenses ?? []) }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Ausgaben schließen")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { editorRoute = .add } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Ausgabe hinzufügen")
                        .accessibilityIdentifier("expenses-add")
                }
            }
            .sheet(item: $editorRoute) { route in
                NativeExpenseEditor(expense: route.expense, participants: participants) { changedExpense in
                    let saved = store.saveExpense(changedExpense)
                    if saved { feedbackTick += 1 }
                    return saved
                }
            }
            .confirmationDialog("Ausgabe löschen?", isPresented: $showingDeleteConfirmation, presenting: expenseToDelete) { expense in
                Button("Ausgabe löschen", role: .destructive) { delete(expense) }
                    .accessibilityIdentifier("expense-delete-confirm")
                Button("Abbrechen", role: .cancel) { expenseToDelete = nil }
            } message: { expense in
                Text("„\(expense.title)“ wird aus der gemeinsamen Abrechnung entfernt.")
            }
            .sheet(isPresented: $showingSettlement) {
                NativeSettlementView(transfers: transfers) { entries in
                    var trip = store.data.trip
                    trip.settlements = (trip.settlements ?? []) + entries
                    let saved = store.updateTrip(trip)
                    if saved { feedbackTick += 1 }
                    return saved
                }
            }
            .sensoryFeedback(.success, trigger: feedbackTick)
        }
    }

    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Text("Eure Reisekosten")
                .font(Stitch.Face.display(34, relativeTo: .largeTitle))
                .foregroundStyle(Stitch.ink)
                .accessibilityAddTraits(.isHeader)
            if expenses.isEmpty {
                Text("Noch keine Ausgabe eingetragen")
                    .font(.subheadline).foregroundStyle(Stitch.inkSoft)
            } else {
                let mine = balances[store.me, default: 0]
                Text(balanceText(mine))
                    .font(.title3.weight(.semibold)).foregroundStyle(mine == 0 ? Stitch.ink : Stitch.action)
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
                .font(.title2).foregroundStyle(Stitch.action).accessibilityHidden(true)
            Text("Noch keine Ausgaben")
                .font(.headline).foregroundStyle(Stitch.ink)
            Text("Tragt die erste Ausgabe ein, sobald ihr unterwegs etwas gemeinsam bezahlt habt.")
                .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button("Ausgabe hinzufügen") { editorRoute = .add }
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
                        .font(.title3).foregroundStyle(Stitch.action)
                        .frame(width: 44, height: 44)
                        .background(Stitch.paper, in: Circle())
                    VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                        Text(expense.title).font(.body.weight(.semibold)).foregroundStyle(Stitch.ink)
                        Text("\(expense.payer) bezahlt · \(expense.participants.count) Beteiligte")
                            .font(.footnote).foregroundStyle(Stitch.inkSoft)
                    }
                    Spacer(minLength: 0)
                    Text(money(expense.amountCents))
                        .font(.body.monospacedDigit().weight(.semibold)).foregroundStyle(Stitch.ink)
                    Menu {
                        Button("Ausgabe bearbeiten", systemImage: "pencil") { editorRoute = .edit(expense) }
                            .accessibilityLabel("Ausgabe \(expense.title) bearbeiten")
                            .accessibilityIdentifier("expense-edit-\(expense.id)")
                        Button("Ausgabe löschen", systemImage: "trash", role: .destructive) {
                            expenseToDelete = expense
                            showingDeleteConfirmation = true
                        }
                            .accessibilityLabel("Ausgabe \(expense.title) löschen")
                                .accessibilityIdentifier("expense-delete-\(expense.id)")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .frame(width: Stitch.Size.touch, height: Stitch.Size.touch)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Aktionen für \(expense.title)")
                    .accessibilityIdentifier("expense-actions-\(expense.id)")
                }
                .frame(minHeight: Stitch.Size.touch)
                .stitchCard(padding: Stitch.Space.s)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("expense-row-\(expense.id)")
            }
        }
    }

    private func delete(_ expense: TravelExpense) {
        if store.deleteExpense(id: expense.id) { feedbackTick += 1 }
        expenseToDelete = nil
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

private enum ExpenseEditorRoute: Identifiable {
    case add
    case edit(TravelExpense)
    var id: String {
        switch self { case .add: "add"; case .edit(let expense): "edit-\(expense.id)" }
    }
    var expense: TravelExpense? { if case .edit(let value) = self { value } else { nil } }
}

private struct NativeExpenseEditor: View {
    @Environment(\.dismiss) private var dismiss
    let initialParticipants: [String]
    let initialExpense: TravelExpense?
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

    init(expense: TravelExpense? = nil, participants: [String], onSave: @escaping (TravelExpense) -> Bool) {
        initialExpense = expense
        var names = participants
        if let expense {
            for name in [expense.payer] + expense.participants where !names.contains(name) { names.append(name) }
        }
        initialParticipants = names
        self.onSave = onSave
        _title = State(initialValue: expense?.title ?? "")
        _amount = State(initialValue: Self.amountText(expense?.originalMinor))
        _currency = State(initialValue: expense?.currency ?? .eur)
        _rate = State(initialValue: expense.map { String(format: "%.2f", Double($0.exchangeRateHundredths) / 100).replacingOccurrences(of: ".", with: ",") } ?? "25")
        _payer = State(initialValue: expense?.payer ?? names.first ?? "Ich")
        _selected = State(initialValue: Set(expense?.participants ?? names))
    }

    private static func amountText(_ minor: Int?) -> String {
        guard let minor else { return "" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: Double(minor) / 100)) ?? ""
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
                if let error { Text(error).font(.footnote).foregroundStyle(Stitch.action) }
            }
            .scrollContentBackground(.hidden).background(PaperBackground())
            .navigationTitle(initialExpense == nil ? "Ausgabe hinzufügen" : "Ausgabe bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(initialExpense == nil ? "Hinzufügen" : "Speichern") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount.isEmpty || selected.isEmpty)
                        .accessibilityIdentifier("expense-save")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        do {
            var expense = try TravelExpense.make(title: title, amountText: amount, currency: currency,
                                                  exchangeRateText: currency == .czk ? rate : nil,
                                                  payer: payer, participants: participantList.filter { selected.contains($0) },
                                                  id: initialExpense?.id ?? UUID().uuidString)
            if let initialExpense { expense.createdAt = initialExpense.createdAt }
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
                if let error { Text(error).font(.footnote).foregroundStyle(Stitch.action) }
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
    @Environment(\.dismiss) private var dismiss
    private let startWithCamera: Bool
    @State private var cameraPresented = false
    @State private var cameraUnavailable = false
    @State private var photoPickerPresented = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var viewing: NativeMemoryPhoto?
    @State private var viewingTripPhoto: TripMemoryPhoto?
    @State private var linkingPhoto: TripMemoryPhoto?
    @State private var error: String?
    @State private var didStartCamera = false

    public init(startWithCamera: Bool = false) { self.startWithCamera = startWithCamera }

    private var photoPlaces: [Place] { store.places.filter { $0.image != nil } }
    private var tripPhotos: [TripMemoryPhoto] {
        store.data.tripMemories.filter { !$0.deleted }.sorted { $0.createdAt > $1.createdAt }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                if photoPlaces.isEmpty && tripPhotos.isEmpty { emptyState } else { photoGrid }
            }
            .background(PaperBackground())
            .navigationTitle("Erinnerungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44) }
                        .accessibilityLabel("Erinnerungen schließen")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { photoPickerPresented = true } label: { Label("Foto aus Mediathek", systemImage: "photo.on.rectangle") }
                        .accessibilityIdentifier("memories-library")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { openCamera() } label: {
                    Image(systemName: "camera.fill").font(.title2.weight(.semibold)).frame(width: 72, height: 72)
                }
                .buttonStyle(.plain).foregroundStyle(Stitch.onAction).background(Stitch.actionFill, in: Circle())
                .frame(width: 72, height: 72).contentShape(Circle())
                .accessibilityLabel("Mit Kamera fotografieren")
                .accessibilityIdentifier("memories-camera")
                .padding(.bottom, Stitch.Space.s)
            }
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
                photoLoadTask = Task {
                    do {
                        let data = try await item.loadTransferable(type: Data.self)
                        guard !Task.isCancelled else { return }
                        await MainActor.run { if photoItem != nil { save(data: data) } }
                    } catch {
                        guard !Task.isCancelled else { return }
                        await MainActor.run { self.error = "Das Foto konnte nicht geladen werden." }
                    }
                    await MainActor.run { photoItem = nil; photoLoadTask = nil }
                }
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
            .fullScreenCover(item: $viewingTripPhoto) { photo in
                NativeTripMemoryZoom(photo: photo, imageURL: store.tripMemoryURL(for: photo))
            }
            .sheet(item: $linkingPhoto) { photo in
                NavigationStack {
                    List {
                        Section("Foto zuordnen") {
                            Button("Ohne Ortszuordnung") { setPlace(nil, for: photo) }
                            ForEach(store.places.filter { !$0.deleted }) { place in
                                Button(place.title) { setPlace(place.id, for: photo) }.foregroundStyle(Stitch.ink)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden).background(PaperBackground())
                    .navigationTitle("Ort verknüpfen").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { linkingPhoto = nil } } }
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                guard startWithCamera, !didStartCamera else { return }
                didStartCamera = true
                openCamera()
            }
            .task { await store.refreshAuthenticatedUserID() }
            .onDisappear { photoLoadTask?.cancel(); photoLoadTask = nil }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Image(systemName: "photo.on.rectangle.angled").font(.title2).foregroundStyle(Stitch.action)
            Text("Noch keine Erinnerungen").font(.headline).foregroundStyle(Stitch.ink)
            Text("Teile Fotos mit eurer Reisegruppe. Du kannst sie später freiwillig mit einem Ort verknüpfen.")
                .font(.subheadline).foregroundStyle(Stitch.inkSoft).fixedSize(horizontal: false, vertical: true)
            Button("Foto aufnehmen") { openCamera() }.buttonStyle(TextActionButton())
        }
        .padding(Stitch.Space.page).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photoGrid: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.l) {
            if !tripPhotos.isEmpty {
                VStack(alignment: .leading, spacing: Stitch.Space.s) {
                    Text("Gemeinsame Fotos").font(.headline).foregroundStyle(Stitch.ink)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Stitch.Space.s)], spacing: Stitch.Space.s) {
                        ForEach(tripPhotos) { tripMemoryCard($0) }
                    }
                }
            }
            if !photoPlaces.isEmpty {
                VStack(alignment: .leading, spacing: Stitch.Space.s) {
                    Text("Fotos von Orten").font(.headline).foregroundStyle(Stitch.ink)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Stitch.Space.s)], spacing: Stitch.Space.s) {
                        ForEach(photoPlaces) { memoryCard($0) }
                    }
                }
            }
        }
        .padding(.horizontal, Stitch.Space.page).padding(.top, Stitch.Space.s).padding(.bottom, 110)
    }

    private func tripMemoryCard(_ photo: TripMemoryPhoto) -> some View {
        let imageURL = store.tripMemoryURL(for: photo, thumbnail: true)
        return Button { viewingTripPhoto = photo } label: {
            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                Group {
                    if let image = UIImage(contentsOfFile: imageURL.path) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        ZStack { Stitch.paper; Image(systemName: "photo").foregroundStyle(Stitch.inkSoft) }
                    }
                }
                .frame(height: 150).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
                Text(photo.placeID.flatMap { id in store.places.first(where: { $0.id == id })?.title } ?? "Ohne Ortszuordnung")
                    .font(.body.weight(.semibold)).foregroundStyle(Stitch.ink).lineLimit(2)
                Text(photo.authorName.isEmpty ? photo.createdAt.formatted(date: .abbreviated, time: .omitted) : "Von \(photo.authorName)")
                    .font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading).stitchCard(padding: Stitch.Space.s)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if canManage(photo) {
                Button("Mit einem Ort verknüpfen", systemImage: "mappin.and.ellipse") { linkingPhoto = photo }
                if photo.placeID != nil {
                    Button("Ortsverknüpfung entfernen", systemImage: "link.badge.minus") { setPlace(nil, for: photo) }
                }
                Button("Foto löschen", systemImage: "trash", role: .destructive) { store.deleteTripMemory(id: photo.id) }
            }
        }
        .accessibilityLabel(photo.placeID == nil ? "Reisefoto ohne Ortszuordnung, vergrößern" : "Reisefoto mit Ort, vergrößern")
    }

    private func memoryCard(_ place: Place) -> some View {
        Button {
            if let asset = place.displayImage { viewing = NativeMemoryPhoto(place: place, asset: asset) }
        } label: {
            VStack(alignment: .leading, spacing: Stitch.Space.xs) {
                AlbumPhoto(asset: place.displayImage, root: store.root, thumbnailWidth: 500)
                    .frame(height: 150).clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
                Text(place.title).font(.body.weight(.semibold)).foregroundStyle(Stitch.ink).lineLimit(2)
                Text(place.category).font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading).stitchCard(padding: Stitch.Space.s)
        }
        .buttonStyle(.plain).accessibilityLabel("Foto von \(place.title), vergrößern")
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { cameraUnavailable = true; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted: cameraUnavailable = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in if granted { cameraPresented = true } else { cameraUnavailable = true } }
            }
        case .authorized: cameraPresented = true
        @unknown default: cameraUnavailable = true
        }
    }

    private func save(data: Data?) {
        guard let data, store.addTripMemory(data: data) != nil else {
            error = "Das Foto konnte nicht gespeichert werden."
            return
        }
    }

    private func setPlace(_ placeID: String?, for photo: TripMemoryPhoto) {
        var updated = photo
        updated.placeID = placeID
        store.updateTripMemory(updated)
        linkingPhoto = nil
    }

    private func canManage(_ photo: TripMemoryPhoto) -> Bool {
        if !photo.authorID.isEmpty { return photo.authorID.caseInsensitiveCompare(store.authenticatedUserID ?? "") == .orderedSame }
        return store.data.dirty.contains("photo-" + photo.id)
    }

    private struct NativeMemoryPhoto: Identifiable {
        let id = UUID(); let place: Place; let asset: PlaceImageAsset
    }
}

private struct NativeTripMemoryZoom: View {
    let photo: TripMemoryPhoto
    let imageURL: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1

    var body: some View {
        ZStack {
            Stitch.scrim.ignoresSafeArea()
            if let imageURL, let image = UIImage(contentsOfFile: imageURL.path) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(scale)
                    .gesture(MagnificationGesture().onChanged { value in scale = min(max(baseScale * value, 1), 4) }.onEnded { _ in baseScale = scale })
                    .accessibilityLabel("Gemeinsames Reisefoto")
            } else {
                ProgressView().tint(.white)
            }
            VStack { HStack { Spacer(); Button("Schließen", systemImage: "xmark") { dismiss() }.buttonStyle(.bordered).tint(.white).frame(minWidth: 44, minHeight: 44) }; Spacer() }
                .padding()
        }
        .statusBarHidden(true)
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
