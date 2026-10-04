import SwiftUI

/// Chronologischer Rückblick auf Orte, die tatsächlich als besucht markiert wurden.
/// Foto-Stapel und Vollbild-Viewer verwenden dieselben Gesten wie das Ortsdetail.
struct TripMemoriesView: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedPlace: Place?
    @State private var viewing: MemoryPhoto?

    var openMap: () -> Void

    private var visitedPlaces: [Place] {
        store.franked.filter(\.visited).sorted {
            ($0.day ?? .max, $0.dayOrder ?? .max, $0.title)
                < ($1.day ?? .max, $1.dayOrder ?? .max, $1.title)
        }
    }

    private var groups: [(day: Int?, places: [Place])] {
        let grouped = Dictionary(grouping: visitedPlaces, by: \.day)
        return grouped.keys.sorted { ($0 ?? .max) < ($1 ?? .max) }
            .compactMap { day in grouped[day].map { (day, $0) } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stitch.Space.xl) {
                    introduction
                    if visitedPlaces.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(groups.enumerated()), id: \.offset) { element in
                            daySection(element.element.day, places: element.element.places)
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
            .navigationTitle(dynamicTypeSize.isAccessibilitySize ? "" : "Erinnerungen")
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
                                .overlay(alignment: .top) { Stitch.rule.frame(height: 1) }
                        }
                }
            }
            .sheet(item: $selectedPlace) { PlaceDetail(placeID: $0.id) }
            .fullScreenCover(item: $viewing) {
                PhotoViewer(place: $0.place, root: store.root, source: $0.source, photo: $0.asset)
            }
        }
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("Reiseerinnerungen")
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.xs) {
            Text("Prag, wie es war")
                .font(Stitch.Face.display(36, relativeTo: .largeTitle)).foregroundStyle(Stitch.ink)
                .accessibilityAddTraits(.isHeader)
            Text(summary)
                .font(.subheadline).foregroundStyle(Stitch.inkSoft)
        }
        .padding(.top, Stitch.Space.xs)
    }

    private var summary: String {
        let placeCount = visitedPlaces.count
        let photoCount = visitedPlaces.reduce(0) { $0 + $1.photoAssets.count }
        if photoCount == 0 {
            return placeCount == 1 ? "Ein besuchter Ort" : "\(placeCount) besuchte Orte"
        }
        return "\(placeCount) \(placeCount == 1 ? "Ort" : "Orte") · \(photoCount) \(photoCount == 1 ? "Foto" : "Fotos") zum Durchblättern"
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title2).foregroundStyle(Stitch.red)
                .accessibilityHidden(true)
            Text("Noch keine besuchten Orte")
                .font(.headline).foregroundStyle(Stitch.ink)
            Text("Markiert einen Ort als besucht. Dann taucht er hier mit seinen Fotos auf.")
                .font(.subheadline).foregroundStyle(Stitch.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button("Karte öffnen", action: openMap).buttonStyle(TextActionButton())
                .padding(.top, Stitch.Space.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stitchCard(.pinned)
    }

    private func daySection(_ day: Int?, places: [Place]) -> some View {
        VStack(alignment: .leading, spacing: Stitch.Space.s) {
            SectionTitle(title: day.map(TripDates.dayTitle) ?? "Ohne Reisetag") {
                Text(places.count == 1 ? "1 Ort" : "\(places.count) Orte")
                    .font(.footnote).foregroundStyle(Stitch.inkSoft)
            }
            ForEach(places) { place in placeMemory(place, day: day) }
        }
    }

    private func placeMemory(_ place: Place, day: Int?) -> some View {
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
                            .font(.title2).foregroundStyle(Stitch.red)
                            .frame(width: 52, height: 60)
                            .background(Stitch.paperDeep, in: RoundedRectangle(cornerRadius: Stitch.Radius.thumb, style: .continuous))
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
                    Text("Ort ansehen").font(.subheadline.weight(.semibold)).foregroundStyle(Stitch.red)
                    Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(Stitch.red)
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

    private func shortDate(_ day: Int) -> String { "\(day). Oktober" }
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
