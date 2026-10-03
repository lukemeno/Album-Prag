import XCTest
import MapKit
@testable import Album

final class MapPinClusteringTests: XCTestCase {
    func testOnlyNearbyProjectedPinsShareACluster() {
        let groups = MapPinClustering.clusters(from: [
            MapPinProjection(id: "c", point: CGPoint(x: 260, y: 120)),
            MapPinProjection(id: "a", point: CGPoint(x: 10, y: 10)),
            MapPinProjection(id: "b", point: CGPoint(x: 50, y: 20))
        ], collisionDistance: 64)

        XCTAssertEqual(groups.map(\.memberIDs), [["a", "b"], ["c"]])
        XCTAssertEqual(groups[0].center, CGPoint(x: 30, y: 15))
    }

    func testOverlappingChainIsKeptTogether() {
        let groups = MapPinClustering.clusters(from: [
            MapPinProjection(id: "a", point: CGPoint(x: 0, y: 0)),
            MapPinProjection(id: "b", point: CGPoint(x: 55, y: 0)),
            MapPinProjection(id: "c", point: CGPoint(x: 110, y: 0))
        ], collisionDistance: 64)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].memberIDs, ["a", "b", "c"])
        XCTAssertEqual(groups[0].center, CGPoint(x: 55, y: 0))
    }

    func testClusterIdentityDoesNotDependOnInputOrder() {
        let first = [
            MapPinProjection(id: "b", point: CGPoint(x: 1, y: 1)),
            MapPinProjection(id: "a", point: CGPoint(x: 2, y: 1))
        ]
        let second = Array(first.reversed())

        XCTAssertEqual(
            MapPinClustering.clusters(from: first, collisionDistance: 64),
            MapPinClustering.clusters(from: second, collisionDistance: 64)
        )
    }

    func testInitialCameraRectIsNilForEmptyCoordinates() {
        XCTAssertNil(TripMapView.initialCameraRect(for: []))
    }

    func testInitialCameraRectForSingleCoordinateHasFinitePositiveExtent() throws {
        let coordinate = CLLocationCoordinate2D(latitude: 50.087, longitude: 14.423)
        let rect = try XCTUnwrap(TripMapView.initialCameraRect(for: [coordinate]))

        XCTAssertTrue(rect.origin.x.isFinite)
        XCTAssertTrue(rect.origin.y.isFinite)
        XCTAssertTrue(rect.size.width.isFinite)
        XCTAssertTrue(rect.size.height.isFinite)
        XCTAssertGreaterThan(rect.size.width, 0)
        XCTAssertGreaterThan(rect.size.height, 0)
        XCTAssertTrue(rect.contains(MKMapPoint(coordinate)))
    }

    func testInitialCameraRectContainsAllMultipleCoordinates() throws {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 50.087, longitude: 14.423),
            CLLocationCoordinate2D(latitude: 50.090, longitude: 14.430),
            CLLocationCoordinate2D(latitude: 50.084, longitude: 14.418)
        ]
        let rect = try XCTUnwrap(TripMapView.initialCameraRect(for: coordinates))

        XCTAssertTrue(rect.origin.x.isFinite)
        XCTAssertTrue(rect.origin.y.isFinite)
        XCTAssertTrue(rect.size.width.isFinite)
        XCTAssertTrue(rect.size.height.isFinite)
        XCTAssertGreaterThan(rect.size.width, 0)
        XCTAssertGreaterThan(rect.size.height, 0)
        for coordinate in coordinates {
            XCTAssertTrue(rect.contains(MKMapPoint(coordinate)))
        }
    }

    func testProjectionCacheIgnoresSubpixelJitterButDetectsMaterialMovement() {
        let stable = [MapPinProjection(id: "a", point: CGPoint(x: 10, y: 20))]
        let jitter = [MapPinProjection(id: "a", point: CGPoint(x: 10.4, y: 20.4))]
        let moved = [MapPinProjection(id: "a", point: CGPoint(x: 10.6, y: 20))]

        XCTAssertFalse(TripMapView.projectionsChanged(jitter, comparedTo: stable))
        XCTAssertTrue(TripMapView.projectionsChanged(moved, comparedTo: stable))
    }
}
