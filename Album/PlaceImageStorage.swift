import Foundation
import UIKit

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
