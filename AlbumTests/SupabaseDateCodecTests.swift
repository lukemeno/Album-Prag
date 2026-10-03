import Foundation
import Supabase
import XCTest
@testable import Album

final class SupabaseDateCodecTests: XCTestCase {
    private struct DateEnvelope: Codable {
        var updatedAt: Date
    }

    private struct MixedRow: Codable {
        var updatedAt: Date
        var payload: DateEnvelope
    }

    func testMixedISOAndNumericDatesDecode() throws {
        let data = Data(#"{"updatedAt":"2026-10-02T20:20:20Z","payload":{"updatedAt":-62135769600}}"#.utf8)
        let row = try SupabaseConfiguration.databaseOptions().decoder.decode(MixedRow.self, from: data)
        XCTAssertEqual(row.updatedAt.timeIntervalSince1970, 1_790_972_420, accuracy: 0.001)
        XCTAssertEqual(row.payload.updatedAt.timeIntervalSince1970, -62_135_769_600, accuracy: 0.001)
    }

    func testFractionalISODateDecodes() throws {
        let data = Data(#"{"updatedAt":"2026-10-02T20:20:20.123Z"}"#.utf8)
        let value = try SupabaseConfiguration.databaseOptions().decoder.decode(DateEnvelope.self, from: data)

        XCTAssertEqual(value.updatedAt.timeIntervalSince1970, 1_790_972_420.123, accuracy: 0.001)
    }

    func testReferenceDateNumbersDecodeWithoutUnixHeuristic() throws {
        let normal = try SupabaseConfiguration.databaseOptions().decoder.decode(
            DateEnvelope.self,
            from: Data(#"{"updatedAt":123456789}"#.utf8)
        )
        let large = try SupabaseConfiguration.databaseOptions().decoder.decode(
            DateEnvelope.self,
            from: Data(#"{"updatedAt":123456789012}"#.utf8)
        )

        XCTAssertEqual(normal.updatedAt.timeIntervalSinceReferenceDate, 123_456_789, accuracy: 0.001)
        XCTAssertEqual(large.updatedAt.timeIntervalSinceReferenceDate, 123_456_789_012, accuracy: 0.001)
    }

    func testCurrentDateRoundTripsThroughSDKEncoder() throws {
        let original = Date(timeIntervalSince1970: 1_790_000_123.456)
        let encoded = try PostgrestClient.Configuration.jsonEncoder.encode(DateEnvelope(updatedAt: original))
        let decoded = try SupabaseConfiguration.databaseOptions().decoder.decode(DateEnvelope.self, from: encoded)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        XCTAssertTrue(object["updatedAt"] is String)
        XCTAssertEqual(decoded.updatedAt.timeIntervalSince1970, original.timeIntervalSince1970, accuracy: 0.001)
    }

    func testInvalidDateThrows() {
        let data = Data(#"{"updatedAt":"not-a-date"}"#.utf8)

        XCTAssertThrowsError(try SupabaseConfiguration.databaseOptions().decoder.decode(DateEnvelope.self, from: data))
    }

    func testBackendDefaultDoesNotOverwriteNewerLocalTrip() {
        var local = TripInfo()
        local.notes = "Lokal neu"
        local.updatedAt = Date(timeIntervalSince1970: 1_790_000_123)

        var backendDefault = TripInfo()
        backendDefault.notes = "Backend-Default"
        backendDefault.updatedAt = Date(timeIntervalSince1970: -62_135_769_600)

        let merged = AlbumMerge.trip(local: local, remote: backendDefault)

        XCTAssertEqual(merged.notes, "Lokal neu")
        XCTAssertEqual(merged.updatedAt, local.updatedAt)
    }
}
