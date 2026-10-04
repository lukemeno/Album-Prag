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
    /// Ohne Foto: Symbol und Pastellfarbe der Kategorie statt eines grauen Kastens.
    var placeholderSymbol: String? = nil
    var placeholderTint: Color? = nil
    /// Große Fotos (Ideenkarte, Ortsdetail, Vollbild) ohne eigene Breite: die größte erlaubte Wikimedia-Breite
    /// unterhalb der 1600 px, die der Server anfragt. 1600 selbst ist keine erlaubte Breite.
    static let fullWidth = 1280
    static let maxRetries = 2
    @State private var preview: UIImage?
    @State private var retries = 0
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
                } else if let remote = asset?.remoteURL(width: thumbnailWidth ?? Self.fullWidth), let url = URL(string: remote) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            imageLayers(image, size: geo.size)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(asset?.isSourcePreview == true ? "Bild der Quelle" : "Ortsfoto")
                                .accessibilityIdentifier("place-photo-loaded")
                        } else if phase.error != nil, case .linkPreview(let pageURL, _, _) = asset {
                            // TikTok signiert Vorschaubilder nur für ein bis zwei Tage. Danach frisch von der Seite holen.
                            refreshedLinkPreview(pageURL: pageURL, size: geo.size)
                        } else if phase.error != nil, retries < Self.maxRetries {
                            // Wechselndes Netz unterwegs: kurz warten und dieselbe Adresse erneut laden.
                            fallback(size: geo.size)
                                .task {
                                    try? await Task.sleep(for: .seconds(1 + retries * 2))
                                    guard !Task.isCancelled else { return }
                                    retries += 1
                                }
                        } else if phase.error != nil, let resolvedFor = asset?.resolvedFor {
                            unavailablePhotoPreview(key: remote, resolvedFor: resolvedFor, size: geo.size)
                        } else {
                            fallback(size: geo.size)
                        }
                    }
                    // Neue Identität startet einen neuen Ladeversuch.
                    .id("\(remote)#\(retries)")
                } else if let preview {
                    imageLayers(Image(uiImage: preview), size: geo.size)
                } else { fallback(size: geo.size) }
            }
            .frame(width: geo.size.width, height: geo.size.height).clipped()
            // `clipped()` beschneidet nur das Bild, nicht die Tippfläche: Ein hohes Foto würde sonst Knöpfe darüber verdecken.
            .contentShape(Rectangle())
        }.task(id: asset?.sourceURL) {
            retries = 0
            guard case .linkPreview(let pageURL, nil, _) = asset, let url = URL(string: pageURL) else { preview = nil; return }
            preview = await LinkPreviewImageLoader.load(url)
        }
    }
    private func refreshedLinkPreview(pageURL: String, size: CGSize) -> some View {
        Group {
            if let preview { imageLayers(Image(uiImage: preview), size: size) } else { fallback(size: size) }
        }
        .task(id: pageURL) {
            guard preview == nil, let url = URL(string: pageURL) else { return }
            preview = await LinkPreviewImageLoader.refresh(url)
        }
    }
    private func unavailablePhotoPreview(key: String, resolvedFor: ResolvedPlaceIdentity, size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            if unavailablePreviewKey == key, let unavailablePreview {
                imageLayers(Image(uiImage: unavailablePreview), size: size)
            } else {
                empty(size: size)
            }
            Text(unavailablePreviewKey == key && unavailablePreview != nil ? "Kein Foto · Kartenausschnitt" : "Kein Foto")
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
                            ? "Kein Foto, Kartenausschnitt von Apple Karten"
                            : "Kein Foto")
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
        } else { empty(size: size) }
    }
    private func empty(size: CGSize) -> some View {
        ZStack {
            placeholderTint ?? Stitch.paperDeep
            Image(systemName: placeholderSymbol ?? "photo")
                .font(.system(size: min(max(min(size.width, size.height) * 0.26, 14), 56), weight: .light))
                .foregroundStyle(placeholderSymbol == nil ? Stitch.inkSoft.opacity(0.7) : Stitch.ink.opacity(0.42))
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
    /// Solange die App läuft, wird jede Seite nur einmal gelesen, auch wenn Listen Zellen neu aufbauen.
    private static let cache = NSCache<NSString, UIImage>()

    static func load(_ url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString
        if let cached = cache.object(forKey: key) { return cached }
        do {
            let metadata = try await LPMetadataProvider().startFetchingMetadata(for: url)
            guard let provider = metadata.imageProvider else { return nil }
            let image: UIImage = try await withCheckedThrowingContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    if let data, let image = UIImage(data: data) { continuation.resume(returning: image) }
                    else { continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown)) }
                }
            }
            cache.setObject(image, forKey: key)
            return image
        } catch { return nil }
    }

    /// Frisches Vorschaubild, wenn die gespeicherte Adresse abgelaufen ist: zuerst oEmbed (TikTok), dann die Seite selbst.
    static func refresh(_ page: URL) async -> UIImage? {
        let key = ("refresh:" + page.absoluteString) as NSString
        if let cached = cache.object(forKey: key) { return cached }
        if let preview = try? await OEmbedService.preview(page),
           let thumbnail = preview.thumbnail_url.flatMap({ URL(string: $0) }),
           let fresh = await download(thumbnail) {
            cache.setObject(fresh, forKey: key)
            return fresh
        }
        return await load(page)
    }

    private static func download(_ url: URL) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return UIImage(data: data)
        } catch { return nil }
    }
}
