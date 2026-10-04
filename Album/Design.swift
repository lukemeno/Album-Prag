import SwiftUI
import LinkPresentation
import UniformTypeIdentifiers
import UIKit
import CoreLocation

struct AlbumPhoto: View {
    var asset: PlaceImageAsset?
    var root: URL? = nil
    var fallbackLocation: ResolvedPlaceIdentity? = nil
    /// Für Vorschaubilder: kleinere Datei laden (nur Wikimedia bietet Breiten an).
    var thumbnailWidth: Int? = nil
    /// Blendet den Beschnitt während eines gemeinsamen Übergangs stufenlos in das vollständige Foto über.
    var fitProgress: CGFloat = 0
    @State private var preview: UIImage?
    @State private var unavailablePreview: UIImage?
    @State private var unavailablePreviewKey: String?
    var body: some View {
        GeometryReader { geo in
            Group {
                if case .uploaded(let uploaded) = asset, let root, let image = UIImage(contentsOfFile: PlaceImageStorage.localURL(for: uploaded, root: root).path) {
                    imageLayers(Image(uiImage: image), size: geo.size)
                        .overlay(alignment: .bottom) {
                            if let source = uploaded.generatedSource {
                                Text(source.credit)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, Stitch.Space.s)
                                    .padding(.vertical, Stitch.Space.xs)
                                    .background(.black.opacity(0.68), in: Capsule())
                                    .padding(Stitch.Space.s)
                            }
                        }
                } else if case .uploaded(let uploaded) = asset,
                          uploaded.generatedSource != nil,
                          let resolvedFor = uploaded.resolvedFor {
                    unavailablePhotoPreview(key: "uploaded-\(uploaded.id)", resolvedFor: resolvedFor, size: geo.size)
                } else if let remote = thumbnailWidth.flatMap({ asset?.remoteURL(width: $0) }) ?? asset?.remoteURL, let url = URL(string: remote) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            imageLayers(image, size: geo.size)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(asset?.isSourcePreview == true ? "Bild der Quelle" : "Ortsfoto")
                                .accessibilityIdentifier("place-photo-loaded")
                        } else if phase.error != nil, let resolvedFor = asset?.resolvedFor {
                            unavailablePhotoPreview(key: remote, resolvedFor: resolvedFor, size: geo.size)
                        } else {
                            fallback(size: geo.size)
                        }
                    }
                } else if let preview {
                    imageLayers(Image(uiImage: preview), size: geo.size)
                } else { fallback(size: geo.size) }
            }
            .frame(width: geo.size.width, height: geo.size.height).clipped()
            // `clipped()` beschneidet nur das Bild, nicht die Tippfläche: Ein hohes Foto würde sonst Knöpfe darüber verdecken.
            .contentShape(Rectangle())
        }.task(id: asset?.sourceURL) {
            guard case .linkPreview(let pageURL, nil, _) = asset, let url = URL(string: pageURL) else { preview = nil; return }
            preview = await LinkPreviewImageLoader.load(url)
        }
    }
    private func unavailablePhotoPreview(key: String, resolvedFor: ResolvedPlaceIdentity, size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            if unavailablePreviewKey == key, let unavailablePreview {
                imageLayers(Image(uiImage: unavailablePreview), size: size)
            } else {
                empty
            }
            VStack(spacing: 2) {
                Text("Foto nicht verfügbar")
                if unavailablePreviewKey == key, unavailablePreview != nil {
                    Text("Apple Karten · Kartenansicht")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Stitch.Space.s)
            .padding(.vertical, Stitch.Space.xs)
            .background(.black.opacity(0.68), in: Capsule())
            .padding(Stitch.Space.s)
        }
        .task(id: key) {
            unavailablePreviewKey = key
            unavailablePreview = nil
            let coordinate = CLLocationCoordinate2D(latitude: resolvedFor.latitude, longitude: resolvedFor.longitude)
            guard let data = await PlaceImageResolver.mapSnapshot(at: coordinate), !Task.isCancelled,
                  unavailablePreviewKey == key else { return }
            unavailablePreview = UIImage(data: data)
        }
        .accessibilityLabel(unavailablePreviewKey == key && unavailablePreview != nil
                            ? "Foto nicht verfügbar, Apple Karten Kartenansicht"
                            : "Foto nicht verfügbar")
    }
    private func imageLayers(_ image: Image, size: CGSize) -> some View {
        ZStack {
            image.resizable().scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
                .opacity(1 - fitProgress)
            image.resizable().scaledToFit()
                .frame(width: size.width, height: size.height)
                .opacity(fitProgress)
        }
        .frame(width: size.width, height: size.height)
    }
    @ViewBuilder private func fallback(size: CGSize) -> some View {
        if let asset, !asset.bundledName.isEmpty { imageLayers(Image(asset.bundledName), size: size) }
        else if let fallbackLocation {
            unavailablePhotoPreview(key: "location-\(fallbackLocation.latitude)-\(fallbackLocation.longitude)", resolvedFor: fallbackLocation, size: size)
        } else { empty }
    }
    var empty: some View {
        ZStack {
            Stitch.paperDeep
            Image(systemName: "photo").font(.title2).foregroundStyle(Stitch.inkSoft.opacity(0.7))
                .accessibilityHidden(true)
        }
    }
}

struct PhotoCard: View {
    var asset: PlaceImageAsset?
    var root: URL? = nil
    var title: String
    var subtitle: String
    var detail: String = ""
    var display = false
    /// Kleinere Fassung laden (nur Wikimedia bietet Breiten an); nil: wie geliefert.
    var thumbnailWidth: Int? = nil
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AlbumPhoto(asset: asset, root: root, thumbnailWidth: thumbnailWidth)
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.06), location: 0.48),
                .init(color: .black.opacity(0.58), location: 0.68),
                .init(color: .black.opacity(0.84), location: 1)
            ], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: Stitch.Space.xxs) {
                Text(title).font(display ? Stitch.Face.place(40, relativeTo: .largeTitle) : Stitch.Face.place(32, relativeTo: .title))
                Text(subtitle).font(.subheadline.weight(.medium))
                if !detail.isEmpty { Text(detail).font(.footnote) }
            }.foregroundStyle(.white).padding(Stitch.Space.m)
        }.clipShape(RoundedRectangle(cornerRadius: Stitch.Radius.card, style: .continuous))
    }
}

private enum LinkPreviewImageLoader {
    static func load(_ url: URL) async -> UIImage? {
        do {
            let metadata = try await LPMetadataProvider().startFetchingMetadata(for: url)
            guard let provider = metadata.imageProvider else { return nil }
            return try await withCheckedThrowingContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    if let data, let image = UIImage(data: data) { continuation.resume(returning: image) }
                    else { continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown)) }
                }
            }
        } catch { return nil }
    }
}
