import Foundation
import UIKit
import CryptoKit

enum PlaceImageStorage {
    static func localURL(for image: UploadedPlaceImage, root: URL) -> URL {
        root.appendingPathComponent("images", isDirectory: true).appendingPathComponent(image.filename)
    }

    static func save(_ source: Data, root: URL, id: String = UUID().uuidString) throws -> UploadedPlaceImage {
        guard let original = UIImage(data: source) else { throw CocoaError(.fileReadCorruptFile) }
        let maximum: CGFloat = 2_048
        let ratio = min(1, maximum / max(original.size.width, original.size.height))
        let size = CGSize(width: max(1, floor(original.size.width * ratio)), height: max(1, floor(original.size.height * ratio)))
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let normalized = renderer.image { _ in original.draw(in: CGRect(origin: .zero, size: size)) }
        let qualities: [CGFloat] = [0.82, 0.70, 0.55]
        guard let jpeg = qualities.lazy.compactMap({ normalized.jpegData(compressionQuality: $0) }).first(where: { $0.count <= 5_000_000 }) else {
            throw NSError(domain: "Album", code: 5, userInfo: [NSLocalizedDescriptionKey: "Das Foto ist zu groß. Bitte wähle ein anderes Bild."])
        }
        let image = UploadedPlaceImage(id: id, storagePath: nil, pixelWidth: Int(size.width), pixelHeight: Int(size.height))
        let directory = root.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try jpeg.write(to: localURL(for: image, root: root), options: .atomic)
        return image
    }

    static func remove(_ image: UploadedPlaceImage, root: URL) {
        try? FileManager.default.removeItem(at: localURL(for: image, root: root))
    }
}

enum TripMemoryStorage {
    static func localURL(for photo: TripMemoryPhoto, thumbnail: Bool, root: URL) -> URL {
        root.appendingPathComponent("trip-memories", isDirectory: true)
            .appendingPathComponent(thumbnail ? photo.thumbnailFilename : photo.filename)
    }

    static func save(_ source: Data, root: URL, id: String = UUID().uuidString.lowercased(), placeID: String? = nil, caption: String = "", authorName: String) throws -> TripMemoryPhoto {
        guard let original = UIImage(data: source), original.size.width > 0, original.size.height > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let maximum: CGFloat = 2_048
        let ratio = min(1, maximum / max(original.size.width, original.size.height))
        let size = CGSize(width: max(1, floor(original.size.width * ratio)), height: max(1, floor(original.size.height * ratio)))
        let format = UIGraphicsImageRendererFormat.preferred(); format.scale = 1; format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in original.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = normalized.jpegData(compressionQuality: 0.82), jpeg.count <= 5_000_000 else {
            throw NSError(domain: "Album", code: 5, userInfo: [NSLocalizedDescriptionKey: "Das Foto ist zu groß. Bitte wähle ein anderes Bild."])
        }
        let thumbRatio = min(1, 480 / max(size.width, size.height))
        let scaledThumb = CGSize(width: max(1, floor(size.width * thumbRatio)), height: max(1, floor(size.height * thumbRatio)))
        let thumbnail = UIGraphicsImageRenderer(size: scaledThumb, format: format).image { _ in normalized.draw(in: CGRect(origin: .zero, size: scaledThumb)) }
        guard let thumbJPEG = thumbnail.jpegData(compressionQuality: 0.75), thumbJPEG.count <= 300_000 else {
            throw NSError(domain: "Album", code: 5, userInfo: [NSLocalizedDescriptionKey: "Das Vorschaubild ist zu groß. Bitte wähle ein anderes Foto."])
        }
        let photo = TripMemoryPhoto(id: id, placeID: placeID, caption: String(caption.prefix(500)), authorName: authorName,
                                    width: Int(size.width), height: Int(size.height), sha256: digest(jpeg), thumbnailSHA256: digest(thumbJPEG))
        let directory = root.appendingPathComponent("trip-memories", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try jpeg.write(to: localURL(for: photo, thumbnail: false, root: root), options: .atomic)
        do { try thumbJPEG.write(to: localURL(for: photo, thumbnail: true, root: root), options: .atomic) }
        catch { try? FileManager.default.removeItem(at: localURL(for: photo, thumbnail: false, root: root)); throw error }
        return photo
    }

    static func remove(_ photo: TripMemoryPhoto, root: URL) {
        try? FileManager.default.removeItem(at: localURL(for: photo, thumbnail: false, root: root))
        try? FileManager.default.removeItem(at: localURL(for: photo, thumbnail: true, root: root))
    }

    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
