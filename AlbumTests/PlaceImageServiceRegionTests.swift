import XCTest
@testable import Album

final class PlaceImageServiceRegionTests: XCTestCase {
    func testTestStoreWithoutImageFixtureReturnsDeterministicEmptyResult() throws {
        let result = try XCTUnwrap(PlaceImageService.testStoreResponse(environment: [
            "ALBUM_TEST_STORE": "ui-region-test",
        ]))

        XCTAssertNil(result.image)
        XCTAssertEqual(result.candidates?.count, 0)
        XCTAssertEqual(result.selectionVersion, PlaceImageService.ranking)
    }

    func testNormalRunDoesNotUseTestStoreFallback() throws {
        XCTAssertNil(try PlaceImageService.testStoreResponse(environment: [:]))
    }

    func testLiveImagePreviewRequiresExplicitOptIn() throws {
        XCTAssertNil(try PlaceImageService.testStoreResponse(environment: [
            "ALBUM_TEST_STORE": "live-preview", "ALBUM_LIVE_IMAGE_QA": "1"
        ]))
        XCTAssertNotNil(try PlaceImageService.testStoreResponse(environment: [
            "ALBUM_TEST_STORE": "live-preview", "ALBUM_LIVE_IMAGE_QA": "0"
        ]))
    }

    func testExplicitImageFixtureTakesPriorityOverLivePreview() throws {
        let fixture = Data(#"{"selection_version":4,"image":null,"candidates":[]}"#.utf8)
        XCTAssertNotNil(try PlaceImageService.testStoreResponse(environment: [
            "ALBUM_TEST_STORE": "live-preview", "ALBUM_LIVE_IMAGE_QA": "1",
            "ALBUM_IMAGE_RESPONSE_BASE64": fixture.base64EncodedString()
        ]))
    }
}
