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


    func testLegacyExpenseDecodesWithoutDeletionMarker() throws {
        let json = Data(#"{"id":"old","title":"Taxi","amountCents":500,"originalMinor":500,"currency":"EUR","exchangeRateHundredths":100,"payer":"Mia","participants":["Mia"],"createdAt":0,"updatedAt":0}"#.utf8)
        let expense = try JSONDecoder().decode(TravelExpense.self, from: json)
        XCTAssertNil(expense.deletedAt)
        XCTAssertEqual(TravelLedger.visibleExpenses([expense]).map(\.id), ["old"])
    }

    func testTombstoneRoundTripsAndIsExcludedFromLedger() throws {
        let date = Date(timeIntervalSince1970: 500)
        let expense = TravelExpense(id: "deleted", title: "Taxi", amountCents: 500, payer: "Mia", participants: ["Luke", "Mia"], createdAt: Date(timeIntervalSince1970: 100), updatedAt: date, deletedAt: date)
        let decoded = try JSONDecoder().decode(TravelExpense.self, from: JSONEncoder().encode(expense))
        XCTAssertEqual(decoded, expense)
        XCTAssertTrue(TravelLedger.visibleExpenses([decoded]).isEmpty)
        XCTAssertTrue(TravelLedger.balances(expenses: [decoded]).isEmpty)
    }

    func testExpenseTombstoneWinsAgainstOlderRowEvenWhenRemoteTripIsNewer() {
        let stamp = Date(timeIntervalSince1970: 200)
        let live = TravelExpense(id: "same", title: "Dinner", amountCents: 2_000, payer: "Luke", participants: ["Luke", "Mia"], updatedAt: Date(timeIntervalSince1970: 100))
        let deleted = TravelExpense(id: "same", title: "Dinner", amountCents: 2_000, payer: "Luke", participants: ["Luke", "Mia"], updatedAt: stamp, deletedAt: stamp)
        var local = TripInfo(); local.expenses = [deleted]; local.updatedAt = Date(timeIntervalSince1970: 100)
        var remote = TripInfo(); remote.expenses = [live]; remote.updatedAt = Date(timeIntervalSince1970: 900)
        let merged = AlbumMerge.trip(local: local, remote: remote)
        XCTAssertEqual(merged.expenses?.first?.deletedAt, stamp)
        XCTAssertTrue(TravelLedger.visibleExpenses(merged.expenses ?? []).isEmpty)
    }

    func testExpenseTombstoneWinsEqualUpdatedAtTie() {
        let stamp = Date(timeIntervalSince1970: 200)
        let live = TravelExpense(id: "same", title: "Dinner", amountCents: 2_000, payer: "Luke", participants: ["Luke", "Mia"], updatedAt: stamp)
        let deleted = TravelExpense(id: "same", title: "Dinner", amountCents: 2_000, payer: "Luke", participants: ["Luke", "Mia"], updatedAt: stamp, deletedAt: stamp)
        var local = TripInfo(); local.expenses = [live]
        var remote = TripInfo(); remote.expenses = [deleted]
        XCTAssertNotNil(AlbumMerge.trip(local: local, remote: remote).expenses?.first?.deletedAt)
    }

    func testExpenseEditKeepsIdentityAndCreationDate() throws {
        let created = Date(timeIntervalSince1970: 10)
        let original = TravelExpense(id: "stable", title: "Taxi", amountCents: 1_000, payer: "Luke", participants: ["Luke"], createdAt: created, updatedAt: created)
        var edited = try TravelExpense.make(title: "Taxi zum Hotel", amountText: "12,00", currency: .eur, exchangeRateText: nil, payer: "Luke", participants: ["Luke"], id: original.id, now: Date(timeIntervalSince1970: 20))
        edited.createdAt = original.createdAt
        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.createdAt, created)
        XCTAssertGreaterThan(edited.updatedAt, original.updatedAt)
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

    @MainActor func testStoreDeletePersistsTombstoneAndRemovesExpenseFromLedger() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        let expense = TravelExpense(id: "persisted-delete", title: "Taxi", amountCents: 1_000, payer: "Luke", participants: ["Luke", "Mia"])
        XCTAssertTrue(store.saveExpense(expense))
        XCTAssertTrue(store.deleteExpense(id: expense.id, now: Date(timeIntervalSince1970: 2_000)))
        XCTAssertTrue(TravelLedger.visibleExpenses(store.data.trip.expenses ?? []).isEmpty)
        XCTAssertTrue(TravelLedger.balances(expenses: store.data.trip.expenses ?? []).isEmpty)

        let reopened = AlbumStore(root: directory)
        let stored = try XCTUnwrap(reopened.data.trip.expenses?.first { $0.id == expense.id })
        XCTAssertNotNil(stored.deletedAt)
        XCTAssertEqual(stored.updatedAt, stored.deletedAt)
    }

    @MainActor func testStoreExpenseEditPreservesIDAndCreatedAt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AlbumStore(root: directory)
        let created = Date(timeIntervalSince1970: 10)
        let original = TravelExpense(id: "edited", title: "Taxi", amountCents: 1_000, payer: "Luke", participants: ["Luke"], createdAt: created, updatedAt: created)
        XCTAssertTrue(store.saveExpense(original))
        let edit = TravelExpense(id: original.id, title: "Taxi Hotel", amountCents: 1_500, payer: "Luke", participants: ["Luke"], createdAt: Date(timeIntervalSince1970: 99))
        XCTAssertTrue(store.saveExpense(edit))
        let saved = try XCTUnwrap(store.data.trip.expenses?.first)
        XCTAssertEqual(saved.id, original.id)
        XCTAssertEqual(saved.createdAt, created)
        XCTAssertGreaterThan(saved.updatedAt, original.updatedAt)
        XCTAssertEqual(saved.title, "Taxi Hotel")
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
