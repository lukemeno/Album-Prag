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
}
