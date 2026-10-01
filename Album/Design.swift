import SwiftUI
import LinkPresentation
import UniformTypeIdentifiers
import UIKit

struct AlbumPhoto: View {
    var asset: PlaceImageAsset?
    var root: URL? = nil
    /// Für Vorschaubilder: kleinere Datei laden (nur Wikimedia bietet Breiten an).
    var thumbnailWidth: Int? = nil
    @State private var preview: UIImage?
    var body: some View {
        GeometryReader { geo in
            Group {
                if case .uploaded(let uploaded) = asset, let root, let image = UIImage(contentsOfFile: PlaceImageStorage.localURL(for: uploaded, root: root).path) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if let remote = thumbnailWidth.flatMap({ asset?.remoteURL(width: $0) }) ?? asset?.remoteURL, let url = URL(string: remote) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { fallback }
                    }
                } else if let preview {
                    Image(uiImage: preview).resizable().scaledToFill()
                } else { fallback }
            }
            .frame(width: geo.size.width, height: geo.size.height).clipped()
            // `clipped()` beschneidet nur das Bild, nicht die Tippfläche: Ein hohes Foto würde sonst Knöpfe darüber verdecken.
            .contentShape(Rectangle())
        }.task(id: asset?.sourceURL) {
            guard case .linkPreview(let pageURL, nil, _) = asset, let url = URL(string: pageURL) else { preview = nil; return }
            preview = await LinkPreviewImageLoader.load(url)
        }
    }
    @ViewBuilder var fallback: some View {
        if let asset, !asset.bundledName.isEmpty { Image(asset.bundledName).resizable().scaledToFill() }
        else { empty }
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
            LinearGradient(colors: [.clear, .black.opacity(0.06), .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
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
