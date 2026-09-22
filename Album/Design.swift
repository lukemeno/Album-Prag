import SwiftUI
import LinkPresentation
import UniformTypeIdentifiers
import UIKit

enum AlbumStyle {
    static let paper = Color(red: 244/255, green: 239/255, blue: 228/255)
    static let deep = Color(red: 232/255, green: 223/255, blue: 208/255)
    static let ink = Color(red: 28/255, green: 25/255, blue: 21/255)
    static let muted = Color(red: 107/255, green: 100/255, blue: 92/255)
    static let red = Color(red: 182/255, green: 69/255, blue: 50/255)
    static let gold = Color(red: 196/255, green: 165/255, blue: 116/255)
    static let white = Color(red: 251/255, green: 248/255, blue: 242/255)
    static func display(_ size: CGFloat = 32) -> Font { .custom("Fraunces-Regular", size: size, relativeTo: .largeTitle).weight(.semibold) }
    static func serif(_ size: CGFloat = 22) -> Font { .custom("InstrumentSerif-Regular", size: size, relativeTo: .title2) }
    static func body(_ size: CGFloat = 15) -> Font { .custom("IBMPlexSans-Regular", size: size, relativeTo: .body) }
    static let ticket = Font.custom("IBMPlexMono-Regular", size: 12, relativeTo: .caption)
}

struct AlbumButton: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(AlbumStyle.ticket).tracking(0.6)
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(primary ? AlbumStyle.white : AlbumStyle.ink)
            .background(primary ? AlbumStyle.red : AlbumStyle.deep, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AlbumStyle.gold.opacity(primary ? 0 : 1), lineWidth: 0.75))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct AlbumPhoto: View {
    var asset: PlaceImageAsset?
    var root: URL? = nil
    @State private var preview: UIImage?
    var body: some View {
        GeometryReader { geo in
            Group {
                if case .uploaded(let uploaded) = asset, let root, let image = UIImage(contentsOfFile: PlaceImageStorage.localURL(for: uploaded, root: root).path) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if let remote = asset?.remoteURL, let url = URL(string: remote) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { fallback }
                    }
                } else if let preview {
                    Image(uiImage: preview).resizable().scaledToFill()
                } else { fallback }
            }.frame(width: geo.size.width, height: geo.size.height).clipped()
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
            AlbumStyle.deep
            VStack(spacing: 14) {
                Image("imgSculpture").resizable().scaledToFit().frame(width: 120, height: 120)
                Text("Neue Idee").font(AlbumStyle.serif(24)).foregroundStyle(AlbumStyle.muted)
            }
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
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AlbumPhoto(asset: asset, root: root)
            LinearGradient(colors: [.clear, .black.opacity(0.06), .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(display ? AlbumStyle.display() : AlbumStyle.serif(27))
                Text(subtitle).font(AlbumStyle.body())
                if !detail.isEmpty { Text(detail).font(AlbumStyle.body(12)) }
            }.foregroundStyle(AlbumStyle.white).padding(18)
        }.clipShape(RoundedRectangle(cornerRadius: 20))
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

struct StampPin: View {
    let title: String
    let category: String
    let selected: Bool
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: category == "Essen & Trinken" ? "cup.and.saucer.fill" : "mappin.and.ellipse").font(.system(size: 18))
            Text(String(title.prefix(13))).font(AlbumStyle.ticket).lineLimit(1)
        }.padding(9).foregroundStyle(selected ? AlbumStyle.white : AlbumStyle.red)
            .background(selected ? AlbumStyle.red : AlbumStyle.white)
            .overlay(Rectangle().strokeBorder(AlbumStyle.gold, style: StrokeStyle(lineWidth: 3, dash: [2, 3])))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
            .accessibilityLabel(title)
    }
}
