import SwiftUI
import CoreLocation

/// Ordnet besuchte Orte und eigene Fotos den Reisetagen zu. „Besucht“ wird hier abgeleitet, nicht
/// gespeichert: abgehakt, ein Foto direkt am Ort oder ein Foto am geplanten Tag in dessen Nähe.
struct AlbumRecap {
    struct Day: Identifiable {
        let day: TripDay?
        let places: [Place]
        let photos: [TripMemoryPhoto]
        var id: String { day?.rawValue ?? "ohne-reisetag" }
    }

    static let nearbyMeters: CLLocationDistance = 300

    let days: [Day]
    /// Fotos, deren Tag außerhalb der Reisedaten liegt.
    let otherPhotos: [TripMemoryPhoto]

    init(places: [Place], photos: [TripMemoryPhoto], calendar: TripCalendar) {
        let photos = photos.filter { !$0.deleted }.sorted { ($0.takenAt ?? $0.createdAt) < ($1.takenAt ?? $1.createdAt) }
        let photoDay = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, calendar.day(from: $0.takenAt ?? $0.createdAt)) })
        let tripHasDates = !calendar.days.isEmpty

        func isVisited(_ place: Place) -> Bool {
            if place.visited { return true }
            return photos.contains { photo in
                if photo.placeID == place.id { return true }
                guard let day = place.plannedDate, photoDay[photo.id] == day,
                      let a = place.coordinate, let b = photo.coordinate else { return false }
                return CLLocation(latitude: a.latitude, longitude: a.longitude)
                    .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)) <= Self.nearbyMeters
            }
        }

        let visited = places.filter(isVisited)
        var placesByDay = Dictionary(grouping: visited, by: \.plannedDate)
        var photosByDay: [TripDay: [TripMemoryPhoto]] = [:]
        var other: [TripMemoryPhoto] = []
        for photo in photos {
            guard let day = photoDay[photo.id] else { continue }
            if !tripHasDates || calendar.contains(day) { photosByDay[day, default: []].append(photo) } else { other.append(photo) }
        }
        let undated = placesByDay.removeValue(forKey: nil) ?? []
        let dated = Set(placesByDay.keys.compactMap { $0 }).union(photosByDay.keys).sorted()
        var days = dated.map { day in
            Day(day: day, places: (placesByDay[day] ?? []).sorted { ($0.dayOrder ?? .max, $0.title) < ($1.dayOrder ?? .max, $1.title) },
                photos: photosByDay[day] ?? [])
        }
        if !undated.isEmpty { days.append(Day(day: nil, places: undated.sorted { $0.title < $1.title }, photos: [])) }
        self.days = days
        otherPhotos = other
    }
}

/// Das Album nach der Reise: pro Tag die besuchten Orte und die eigenen Fotos (siehe `AlbumRecap`).
/// Foto-Stapel und Vollbild-Viewer verwenden dieselben Gesten wie das Ortsdetail.
struct TripMemoriesView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedPlace: Place?
    @State private var viewing: MemoryPhoto?
    @State private var viewingOwn: TripMemoryPhoto?

    var openMap: () -> Void

    private var recap: AlbumRecap {
        AlbumRecap(places: store.franked, photos: store.data.tripMemories, calendar: store.tripCalendar)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                    let recap = recap
                    introduction(recap)
                    if recap.days.isEmpty && recap.otherPhotos.isEmpty {
                        emptyState
                    } else {
                        ForEach(recap.days) { daySection($0) }
                        if !recap.otherPhotos.isEmpty {
                            VStack(alignment: .leading, spacing: Stitch.Space.s) {
                                SectionTitle(title: "Weitere Fotos") {
                                    Text(photoCount(recap.otherPhotos.count)).font(.footnote).foregroundStyle(Stitch.inkSoft)
                                }
                                photoGrid(recap.otherPhotos)
                            }
                        }
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
            .navigationTitle(dynamicTypeSize.isAccessibilitySize ? "" : "Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !dynamicTypeSize.isAccessibilitySize {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { dismiss() }
                            .font(.body)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if dynamicTypeSize.isAccessibilitySize {
                    Button("Fertig") { dismiss() }
                        .buttonStyle(StitchButton(primary: true))
                        .padding(.horizontal, Stitch.Space.page)
                        .padding(.vertical, Stitch.Space.xs)
                        .background {
                            PaperBackground()
                                .overlay(alignment: .top) { Stitch.line.frame(height: 1) }
                        }
                }
            }
            .sheet(item: $selectedPlace) { PlaceDetail(placeID: $0.id) }
            .fullScreenCover(item: $viewing) {
                PhotoViewer(place: $0.place, root: store.root, source: $0.source, photo: $0.asset)
            }
            .fullScreenCover(item: $viewingOwn) { NativeTripMemoryZoom(photo: $0, imageURL: store.tripMemoryURL(for: $0)) }
        }
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("Reiseerinnerungen")
    }

    private func introduction(_ recap: AlbumRecap) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Text("\(store.tripName), wie es war")
                .font(Stitch.Face.display(36, relativeTo: .largeTitle)).foregroundStyle(Stitch.ink)
                .accessibilityAddTraits(.isHeader)
            Text(summary(recap))
                .font(.subheadline).foregroundStyle(Stitch.inkSoft)
        }
        .padding(.top, Stitch.Space.xs)
    }

    private func summary(_ recap: AlbumRecap) -> String {
        let placeCount = recap.days.reduce(0) { $0 + $1.places.count }
        let photos = recap.days.reduce(recap.otherPhotos.count) { $0 + $1.photos.count }
        let places = placeCount == 1 ? "1 Ort" : "\(placeCount) Orte"
        return photos == 0 ? places : "\(places) · \(photoCount(photos))"
    }

    private func photoCount(_ count: Int) -> String { count == 1 ? "1 eigenes Foto" : "\(count) eigene Fotos" }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title2).foregroundStyle(Stitch.action)
                .accessibilityHidden(true)
            Text("Noch nichts im Album")
                .font(.headline).foregroundStyle(Stitch.ink)
            Text("Fotos, die ihr unterwegs macht, und besuchte Orte erscheinen hier, sortiert nach Reisetag.")
                .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button("Karte öffnen", action: openMap).buttonStyle(TextActionButton())
                .padding(.top, Stitch.Space.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stitchCard(.pinned)
    }

    private func daySection(_ entry: AlbumRecap.Day) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            SectionTitle(title: entry.day.map(store.tripCalendar.dayTitle)
                         ?? (entry.places.contains(where: { $0.day != nil }) ? "Alter Reisetag prüfen" : "Ohne Reisetag")) {
                Text([entry.places.isEmpty ? nil : (entry.places.count == 1 ? "1 Ort" : "\(entry.places.count) Orte"),
                      entry.photos.isEmpty ? nil : (entry.photos.count == 1 ? "1 Foto" : "\(entry.photos.count) Fotos")]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
            ForEach(entry.places) { place in placeMemory(place, day: entry.day) }
            if !entry.photos.isEmpty { photoGrid(entry.photos) }
        }
    }

    /// Eigene Fotos eines Tages als Raster; Tippen öffnet das Foto groß.
    private func photoGrid(_ photos: [TripMemoryPhoto]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Stitch.Space.xs)], spacing: Stitch.Space.xs) {
            ForEach(photos) { photo in
                Button { viewingOwn = photo } label: {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if let image = UIImage(contentsOfFile: store.tripMemoryURL(for: photo, thumbnail: true).path) {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                Stitch.paper.overlay { Image(systemName: "photo").foregroundStyle(Stitch.inkSoft) }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(photo.caption.isEmpty ? "Eigenes Foto, vergrößern" : "Eigenes Foto: \(photo.caption), vergrößern")
                .accessibilityIdentifier("album-photo-\(photo.id)")
            }
        }
    }

    private func placeMemory(_ place: Place, day: TripDay?) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            if place.photoAssets.count > 1 {
                PhotoStack(photos: place.photoAssets, root: store.root, title: place.title,
                           subtitle: day.map(shortDate) ?? place.category) { asset, source in
                    viewing = MemoryPhoto(place: place, asset: asset, source: source)
                }
                .frame(height: 300)
            } else if let asset = place.image {
                MemorySinglePhoto(place: place, asset: asset, root: store.root,
                                  subtitle: day.map(shortDate) ?? place.category) { photo, source in
                    viewing = MemoryPhoto(place: place, asset: photo, source: source)
                }
                .frame(height: 300)
            } else {
                Button { selectedPlace = place } label: {
                    HStack(spacing: Stitch.Space.m) {
                        Image(systemName: place.symbol)
                            .font(.title2).foregroundStyle(Stitch.action)
                            .frame(width: 52, height: 60)
                            .background(Stitch.paper, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
                        VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                            Text(place.title).font(Stitch.Face.place(24, relativeTo: .title3)).foregroundStyle(Stitch.ink)
                            Text("Foto ergänzen").font(.subheadline).foregroundStyle(Stitch.inkSoft)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.inkSoft)
                    }
                    .frame(minHeight: 76)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .stitchCard()
                .accessibilityLabel("\(place.title), Foto ergänzen")
            }

            Button { selectedPlace = place } label: {
                HStack(spacing: Stitch.Space.xs) {
                    Text(place.category).font(.footnote).foregroundStyle(Stitch.inkSoft)
                    Spacer(minLength: 0)
                    Text("Ort ansehen").font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.action)
                    Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.action)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: Stitch.Size.touch)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ort ansehen: \(place.title)")
        }
        .padding(.bottom, Stitch.Space.xs)
    }

    private func shortDate(_ day: TripDay) -> String { store.tripCalendar.dayMonth(day) }
}

private struct MemoryPhoto: Identifiable {
    let id = UUID()
    let place: Place
    let asset: PlaceImageAsset
    let source: CGRect
}

/// Ein einzelnes Foto behält denselben Quellrahmen-Übergang wie die Karten im Stapel.
private struct MemorySinglePhoto: View {
    let place: Place
    let asset: PlaceImageAsset
    let root: URL
    let subtitle: String
    var onOpen: (PlaceImageAsset, CGRect) -> Void
    @State private var frame: CGRect = .zero

    var body: some View {
        Button { onOpen(asset, frame) } label: {
            PhotoCard(asset: asset, root: root, title: place.title, subtitle: subtitle, thumbnailWidth: 960)
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .accessibilityLabel("Foto von \(place.title), vergrößern")
    }
}
