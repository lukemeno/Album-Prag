import Foundation
import PDFKit
import UIKit
import XCTest
@testable import Album

@MainActor
final class DownloadRegressionTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("download-regression-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        try super.tearDownWithError()
    }

    func testMissingEmptyAndCorruptPDFsAreRepairedIncludingSameUpdatedAt() async throws {
        let valid = makePDF()
        let updatedAt = Date(timeIntervalSince1970: 1_000)
        let document = TravelDocument(id: "doc-repair", name: "QA", filename: "doc-repair.pdf", extractedText: "Text", updatedAt: updatedAt)
        let destination = root.appendingPathComponent(document.filename)

        for initial in [Data?](arrayLiteral: nil, Data(), Data("not a PDF".utf8)) {
            try? FileManager.default.removeItem(at: destination)
            if let initial { try initial.write(to: destination) }
            let transport = DownloadProbe(bytes: valid)
            let sync = SupabaseSync(storageDownloadTransport: transport)
            let result = try await sync.reconcileDocumentForTesting(
                local: document,
                remote: document,
                storagePath: "trip-files/doc-repair.pdf",
                root: root
            )
            XCTAssertEqual(result?.id, document.id)
            XCTAssertEqual(transport.requests, [DownloadProbe.Request(bucket: "trip-files", path: "trip-files/doc-repair.pdf")])
            XCTAssertNotNil(PDFDocument(url: destination))
            XCTAssertEqual(try Data(contentsOf: destination), valid)
        }
    }

    func testMissingEmptyAndCorruptImagesAreRepaired() async throws {
        let tripID = UUID()
        let image = UploadedPlaceImage(id: "image-repair", storagePath: "\(tripID.uuidString)/place-repair/image-repair.jpg", pixelWidth: 10, pixelHeight: 10)
        let updatedAt = Date(timeIntervalSince1970: 1_000)
        let place = Place(id: "place-repair", title: "QA", image: .uploaded(image), updatedAt: updatedAt)
        let destination = PlaceImageStorage.localURL(for: image, root: root)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let valid = makeImage()

        for initial in [Data?](arrayLiteral: nil, Data(), Data("not an image".utf8)) {
            try? FileManager.default.removeItem(at: destination)
            if let initial { try initial.write(to: destination) }
            let transport = DownloadProbe(bytes: valid)
            let sync = SupabaseSync(storageDownloadTransport: transport)
            let result = try await sync.reconcilePlaceForTesting(local: place, remote: place, tripID: tripID, root: root)
            XCTAssertEqual(result?.id, place.id)
            XCTAssertEqual(transport.requests, [DownloadProbe.Request(bucket: "trip-images", path: image.storagePath!)])
            XCTAssertNotNil(UIImage(contentsOfFile: destination.path))
            XCTAssertEqual(try Data(contentsOf: destination), valid)
        }
    }

    func testValidCachesSkipDownload() async throws {
        let tripID = UUID()
        let updatedAt = Date(timeIntervalSince1970: 1_000)
        let image = UploadedPlaceImage(id: "image-valid", storagePath: "\(tripID.uuidString)/place-valid/image-valid.jpg", pixelWidth: 10, pixelHeight: 10)
        let place = Place(id: "place-valid", title: "QA", image: .uploaded(image), updatedAt: updatedAt)
        let imageURL = PlaceImageStorage.localURL(for: image, root: root)
        try FileManager.default.createDirectory(at: imageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try makeImage().write(to: imageURL)

        let document = TravelDocument(id: "doc-valid", name: "QA", filename: "doc-valid.pdf", extractedText: "Text", updatedAt: updatedAt)
        let documentURL = root.appendingPathComponent(document.filename)
        let pdf = makePDF()
        try pdf.write(to: documentURL)

        let transport = DownloadProbe(bytes: Data("should not be used".utf8))
        let sync = SupabaseSync(storageDownloadTransport: transport)
        _ = try await sync.reconcilePlaceForTesting(local: place, remote: place, tripID: tripID, root: root)
        _ = try await sync.reconcileDocumentForTesting(local: document, remote: document, storagePath: "trip-files/doc-valid.pdf", root: root)

        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(try Data(contentsOf: documentURL), pdf)
    }

    func testInvalidRemoteResponseDoesNotReplaceExistingFiles() async throws {
        let tripID = UUID()
        let updatedAt = Date(timeIntervalSince1970: 1_000)
        let document = TravelDocument(id: "doc-invalid", name: "QA", filename: "doc-invalid.pdf", extractedText: "Text", updatedAt: updatedAt)
        let documentURL = root.appendingPathComponent(document.filename)
        let oldPDF = Data("old local PDF bytes".utf8)
        try oldPDF.write(to: documentURL)

        let image = UploadedPlaceImage(id: "image-invalid", storagePath: "\(tripID.uuidString)/place-invalid/image-invalid.jpg", pixelWidth: 10, pixelHeight: 10)
        let place = Place(id: "place-invalid", title: "QA", image: .uploaded(image), updatedAt: updatedAt)
        let imageURL = PlaceImageStorage.localURL(for: image, root: root)
        try FileManager.default.createDirectory(at: imageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let oldImage = Data("old local image bytes".utf8)
        try oldImage.write(to: imageURL)

        let transport = DownloadProbe(bytes: Data("invalid remote bytes".utf8))
        let sync = SupabaseSync(storageDownloadTransport: transport)
        do {
            _ = try await sync.reconcileDocumentForTesting(local: document, remote: document, storagePath: "trip-files/doc-invalid.pdf", root: root)
            XCTFail("Invalides PDF-Remoteartefakt muss abgewiesen werden")
        } catch { }
        XCTAssertEqual(try Data(contentsOf: documentURL), oldPDF)

        do {
            _ = try await sync.reconcilePlaceForTesting(local: place, remote: place, tripID: tripID, root: root)
            XCTFail("Invalides Bild-Remoteartefakt muss abgewiesen werden")
        } catch { }
        XCTAssertEqual(try Data(contentsOf: imageURL), oldImage)
    }

    func testNewerDirtyLocalVersionsAreNeverReplacedByOlderRemoteFiles() async throws {
        let tripID = UUID()
        let localDate = Date(timeIntervalSince1970: 2_000)
        let remoteDate = Date(timeIntervalSince1970: 1_000)
        let localDocument = TravelDocument(id: "doc-dirty", name: "Lokal", filename: "doc-dirty.pdf", extractedText: "Lokal", updatedAt: localDate)
        let remoteDocument = TravelDocument(id: localDocument.id, name: "Remote", filename: localDocument.filename, extractedText: "Remote", updatedAt: remoteDate)
        let documentURL = root.appendingPathComponent(localDocument.filename)
        let localPDF = makePDF()
        try localPDF.write(to: documentURL)

        let image = UploadedPlaceImage(id: "image-dirty", storagePath: "\(tripID.uuidString)/place-dirty/image-dirty.jpg", pixelWidth: 10, pixelHeight: 10)
        let localPlace = Place(id: "place-dirty", title: "Lokal", image: .uploaded(image), updatedAt: localDate)
        let remotePlace = Place(id: localPlace.id, title: "Remote", image: .uploaded(image), updatedAt: remoteDate)
        let imageURL = PlaceImageStorage.localURL(for: image, root: root)
        try FileManager.default.createDirectory(at: imageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let localImage = makeImage()
        try localImage.write(to: imageURL)

        let transport = DownloadProbe(bytes: Data("must not be used".utf8))
        let sync = SupabaseSync(storageDownloadTransport: transport)
        let documentResult = try await sync.reconcileDocumentForTesting(local: localDocument, remote: remoteDocument, storagePath: "trip-files/doc-dirty.pdf", root: root, dirty: true)
        let placeResult = try await sync.reconcilePlaceForTesting(local: localPlace, remote: remotePlace, tripID: tripID, root: root, dirty: true)

        XCTAssertEqual(documentResult?.name, localDocument.name)
        XCTAssertEqual(placeResult?.title, localPlace.title)
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(try Data(contentsOf: documentURL), localPDF)
        XCTAssertEqual(try Data(contentsOf: imageURL), localImage)
    }

    func testDocumentMutationDuringDownloadKeepsCurrentMetadataAndFile() async throws {
        let document = TravelDocument(id: "doc-race", name: "Vorher", filename: "doc-race.pdf", extractedText: "alt", updatedAt: Date(timeIntervalSince1970: 1_000))
        let destination = root.appendingPathComponent(document.filename)
        let oldBytes = Data("old local bytes".utf8)
        try oldBytes.write(to: destination)
        let remote = TravelDocument(id: document.id, name: "Remote", filename: document.filename, extractedText: "remote", updatedAt: Date(timeIntervalSince1970: 2_000))
        let transport = PausingDownloadProbe(bytes: makePDF(), bucket: "trip-files")
        let sync = SupabaseSync(storageDownloadTransport: transport)
        let store = AlbumStore(root: root)
        store.data.documents = [document]
        let task = Task { try await sync.reconcileDocumentForTesting(store: store, remote: remote, storagePath: "trip-files/doc-race.pdf") }
        while !transport.entered { try await Task.sleep(for: .milliseconds(5)) }

        var changed = document
        changed.name = "Neu während Download"
        changed.updatedAt = Date(timeIntervalSince1970: 3_000)
        store.data.documents[0] = changed
        store.data.dirty.insert("doc-" + document.id)
        let newLocalBytes = Data("new local bytes".utf8)
        try newLocalBytes.write(to: destination, options: .atomic)
        transport.resume()
        try await task.value

        XCTAssertEqual(store.data.documents.first?.name, changed.name)
        XCTAssertTrue(store.data.dirty.contains("doc-" + document.id))
        XCTAssertEqual(try Data(contentsOf: destination), newLocalBytes)
    }

    func testRemovedPlaceDuringDownloadIsNotReinserted() async throws {
        let tripID = UUID()
        let image = UploadedPlaceImage(id: "image-removed", storagePath: "\(tripID.uuidString)/place-removed/image-removed.jpg", pixelWidth: 10, pixelHeight: 10)
        let place = Place(id: "place-removed", title: "Vorher", image: .uploaded(image), updatedAt: Date(timeIntervalSince1970: 1_000))
        let destination = PlaceImageStorage.localURL(for: image, root: root)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let oldBytes = Data("old local image".utf8)
        try oldBytes.write(to: destination)
        let remote = Place(id: place.id, title: "Remote", image: .uploaded(image), updatedAt: Date(timeIntervalSince1970: 2_000))
        let transport = PausingDownloadProbe(bytes: makeImage(), bucket: "trip-images")
        let sync = SupabaseSync(storageDownloadTransport: transport)
        let store = AlbumStore(root: root)
        store.data.places = [place]
        let task = Task { try await sync.reconcilePlaceForTesting(store: store, remote: remote, tripID: tripID) }
        while !transport.entered { try await Task.sleep(for: .milliseconds(5)) }

        store.data.places.removeAll { $0.id == place.id }
        store.data.dirty.insert(place.id)
        transport.resume()
        try await task.value

        XCTAssertTrue(store.data.places.isEmpty)
        XCTAssertTrue(store.data.dirty.contains(place.id))
        XCTAssertEqual(try Data(contentsOf: destination), oldBytes)
    }

    func testReorderedPlacesKeepCurrentOrderWhileDownloadFinishes() async throws {
        let tripID = UUID()
        let image = UploadedPlaceImage(id: "image-reorder", storagePath: "\(tripID.uuidString)/place-reorder/image-reorder.jpg", pixelWidth: 10, pixelHeight: 10)
        let target = Place(id: "place-reorder", title: "Ziel", image: .uploaded(image), updatedAt: Date(timeIntervalSince1970: 1_000))
        let other = Place(id: "place-other", title: "Andere", updatedAt: Date(timeIntervalSince1970: 1_000))
        let destination = PlaceImageStorage.localURL(for: image, root: root)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("old local image".utf8).write(to: destination)
        let remote = Place(id: target.id, title: target.title, image: .uploaded(image), updatedAt: Date(timeIntervalSince1970: 1_000))
        let transport = PausingDownloadProbe(bytes: makeImage(), bucket: "trip-images")
        let sync = SupabaseSync(storageDownloadTransport: transport)
        let store = AlbumStore(root: root)
        store.data.places = [target, other]
        let task = Task { try await sync.reconcilePlaceForTesting(store: store, remote: remote, tripID: tripID) }
        while !transport.entered { try await Task.sleep(for: .milliseconds(5)) }

        store.data.places = [other, target]
        transport.resume()
        try await task.value

        XCTAssertEqual(store.data.places.map(\.id), [other.id, target.id])
        XCTAssertNotNil(UIImage(contentsOfFile: destination.path))
        XCTAssertEqual(try Data(contentsOf: destination), transport.bytes)
    }

    private func makePDF() -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 100)).pdfData { context in
            context.beginPage()
            NSString(string: "QA").draw(at: CGPoint(x: 10, y: 10), withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
        }
    }

    private func makeImage() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in
            UIColor.systemBlue.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10)).fill()
        }.jpegData(compressionQuality: 0.9)!
    }
}

@MainActor
private final class DownloadProbe: SupabaseStorageDownloadTransport {
    struct Request: Equatable {
        let bucket: String
        let path: String
    }

    let bytes: Data
    var requests: [Request] = []

    init(bytes: Data) { self.bytes = bytes }

    func download(bucket: String, path: String) async throws -> Data {
        requests.append(Request(bucket: bucket, path: path))
        return bytes
    }
}

@MainActor
private final class PausingDownloadProbe: SupabaseStorageDownloadTransport {
    let bytes: Data
    let bucket: String
    var entered = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(bytes: Data, bucket: String) {
        self.bytes = bytes
        self.bucket = bucket
    }

    func download(bucket: String, path: String) async throws -> Data {
        XCTAssertEqual(bucket, self.bucket)
        entered = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.continuation = continuation
        }
        return bytes
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}
