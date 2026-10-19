import XCTest
@testable import Album

final class TravelExpenseTests: XCTestCase {
    func testLegacyTripInfoDecodesWithoutLedgerFields() throws {
        let json = Data(#"{"hotel":"Altstadt","outbound":"","arrival":"","route":"","flightNumber":"","notes":"","updatedAt":0}"#.utf8)
        let trip = try JSONDecoder().decode(TripInfo.self, from: json)
        XCTAssertEqual(trip.hotel, "Altstadt")
        XCTAssertNil(trip.expenses)
        XCTAssertNil(trip.settlements)
    }

    func testGermanMoneyParserAcceptsGroupedDecimalAndRejectsMalformedInput() {
        XCTAssertEqual(GermanMoneyParser.parseMinorUnits("1.234,56"), 123_456)
        XCTAssertEqual(GermanMoneyParser.parseMinorUnits("10"), 1_000)
        XCTAssertNil(GermanMoneyParser.parseMinorUnits("1.23,4"))
        XCTAssertNil(GermanMoneyParser.parseMinorUnits("1234.567"))
        XCTAssertNil(GermanMoneyParser.parseMinorUnits("12,345"))
        XCTAssertNil(GermanMoneyParser.parseMinorUnits("10.00"))
        XCTAssertNil(GermanMoneyParser.parseMinorUnits("0"))
        XCTAssertEqual(GermanMoneyParser.parseMinorUnits("999.999,99"), 99_999_999)
        XCTAssertNil(GermanMoneyParser.parseMinorUnits("9999999,99"))
    }

    func testRemainderAllocationAndSettlementReachZero() throws {
        let expense = try TravelExpense.make(title: "Abendessen", amountText: "10", currency: .eur,
                                              exchangeRateText: nil, payer: "Alice",
                                              participants: ["Alice", "Bob", "Cara"])
        XCTAssertEqual(expense.amountCents, 1_000)
        XCTAssertEqual(TravelLedger.shareCents(for: expense, participant: "Alice"), 334)
        XCTAssertEqual(TravelLedger.shareCents(for: expense, participant: "Bob"), 333)
        XCTAssertEqual(TravelLedger.shareCents(for: expense, participant: "Cara"), 333)
        let transfers = TravelLedger.transfers(expenses: [expense])
        let settlements = transfers.map { TravelSettlement(from: $0.from, to: $0.to, amountCents: $0.amountCents) }
        XCTAssertTrue(TravelLedger.balances(expenses: [expense], settlements: settlements).values.allSatisfy { $0 == 0 })
    }

    func testManualCzkRateConvertsToEuroCents() throws {
        let expense = try TravelExpense.make(title: "Taxi", amountText: "250", currency: .czk,
                                              exchangeRateText: "25", payer: "Alice", participants: ["Alice"])
        XCTAssertEqual(expense.originalMinor, 25_000)
        XCTAssertEqual(expense.amountCents, 1_000)
    }

    func testTripMergeUnionsIndependentLedgerEntries() {
        let localExpense = TravelExpense(title: "Tram", amountCents: 250, payer: "Ich", participants: ["Ich"])
        let remoteExpense = TravelExpense(title: "Hotel", amountCents: 5_000, payer: "Mia", participants: ["Mia"])
        var local = TripInfo(); local.hotel = "Lokales Hotel"; local.updatedAt = Date(timeIntervalSince1970: 100); local.expenses = [localExpense]
        var remote = TripInfo(); remote.hotel = "Remote Hotel"; remote.updatedAt = Date(timeIntervalSince1970: 200); remote.expenses = [remoteExpense]
        let merged = AlbumMerge.trip(local: local, remote: remote)
        XCTAssertEqual(merged.hotel, "Remote Hotel")
        XCTAssertEqual(Set(merged.expenses?.map(\.id) ?? []), Set([localExpense.id, remoteExpense.id]))
    }

    func testTripMergeUsesNewestEntryForSameExpenseIDAndMergesSettlements() {
        let id = "same-expense"
        let older = TravelExpense(id: id, title: "alt", amountCents: 100, payer: "Ich", participants: ["Ich"],
                                  updatedAt: Date(timeIntervalSince1970: 100))
        let newer = TravelExpense(id: id, title: "neu", amountCents: 200, payer: "Ich", participants: ["Ich"],
                                  updatedAt: Date(timeIntervalSince1970: 200))
        let settlement = TravelSettlement(id: "settlement", from: "Mia", to: "Ich", amountCents: 100)
        var local = TripInfo(); local.expenses = [newer]; local.settlements = [settlement]
        var remote = TripInfo(); remote.expenses = [older]
        let merged = AlbumMerge.trip(local: local, remote: remote)
        XCTAssertEqual(merged.expenses?.first?.title, "neu")
        XCTAssertEqual(merged.settlements?.map(\.id), ["settlement"])
    }
}
