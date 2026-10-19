import Foundation

enum TravelCurrency: String, Codable, CaseIterable {
    case eur = "EUR"
    case czk = "CZK"

    var label: String { rawValue }
}

struct TravelExpense: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    /// The amount used for the shared ledger, always in Euro cents.
    var amountCents: Int
    var originalMinor: Int
    var currency: TravelCurrency
    /// For CZK this is the manually entered number of CZK per EUR, in hundredths.
    /// EUR entries use 100 (1 EUR = 1 EUR).
    var exchangeRateHundredths: Int
    var payer: String
    var participants: [String]
    var createdAt = Date()
    var updatedAt = Date()

    init(id: String = UUID().uuidString, title: String, amountCents: Int,
         originalMinor: Int? = nil, currency: TravelCurrency = .eur,
         exchangeRateHundredths: Int = 100, payer: String, participants: [String],
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.amountCents = amountCents
        self.originalMinor = originalMinor ?? amountCents
        self.currency = currency
        self.exchangeRateHundredths = max(1, exchangeRateHundredths)
        self.payer = payer
        self.participants = participants
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var amount: Decimal { Decimal(amountCents) / 100 }
    var originalAmount: Decimal {
        currency == .eur ? Decimal(originalMinor) / 100 : Decimal(originalMinor) / 100
    }
    var currencyAmountText: String {
        let value = Decimal(originalMinor) / 100
        return value.formatted(.number.precision(.fractionLength(2))) + " " + currency.rawValue
    }

    static func make(title: String, amountText: String, currency: TravelCurrency,
                     exchangeRateText: String?, payer: String, participants: [String],
                     id: String = UUID().uuidString, now: Date = Date()) throws -> TravelExpense {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TravelExpenseError.emptyTitle }
        guard let originalMinor = GermanMoneyParser.parseMinorUnits(amountText) else { throw TravelExpenseError.invalidAmount }
        let rate: Int
        if currency == .eur {
            rate = 100
        } else {
            guard let parsed = exchangeRateText.flatMap(GermanMoneyParser.parseRateHundredths), parsed > 0 else {
                throw TravelExpenseError.invalidExchangeRate
            }
            rate = parsed
        }
        guard !payer.isEmpty, !participants.isEmpty else {
            throw TravelExpenseError.invalidParticipants
        }
        let cents = currency == .eur
            ? originalMinor
            : (originalMinor * 100 + rate / 2) / rate
        guard cents > 0 else { throw TravelExpenseError.invalidAmount }
        var uniqueParticipants: [String] = []
        for participant in participants where !uniqueParticipants.contains(participant) { uniqueParticipants.append(participant) }
        return TravelExpense(id: id, title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                             amountCents: cents, originalMinor: originalMinor, currency: currency,
                             exchangeRateHundredths: rate, payer: payer,
                             participants: uniqueParticipants,
                             createdAt: now, updatedAt: now)
    }
}

struct TravelSettlement: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var from: String
    var to: String
    var amountCents: Int
    var createdAt = Date()
    var updatedAt = Date()

    init(id: String = UUID().uuidString, from: String, to: String, amountCents: Int,
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id; self.from = from; self.to = to; self.amountCents = amountCents
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

enum TravelExpenseError: LocalizedError, Equatable {
    case emptyTitle, invalidAmount, invalidExchangeRate, invalidParticipants

    var errorDescription: String? {
        switch self {
        case .emptyTitle: "Bitte einen Titel eingeben."
        case .invalidAmount: "Betrag im deutschen Format eingeben, zum Beispiel 1.234,56."
        case .invalidExchangeRate: "Bitte einen gültigen manuellen Wechselkurs eingeben."
        case .invalidParticipants: "Mindestens eine Person auswählen."
        }
    }
}

enum GermanMoneyParser {
    static let maximumMinorUnits = 99_999_999
    static func parse(_ input: String) -> Int? { parseMinorUnits(input) }

    /// Strictly parses German notation into minor units. Thousands use dots,
    /// decimals use one comma and have one or two digits.
    static func parseMinorUnits(_ input: String) -> Int? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.range(of: #"^(?:[0-9]+|[0-9]{1,3}(?:\.[0-9]{3})+)(?:,[0-9]{1,2})?$"#, options: .regularExpression) != nil else { return nil }
        let pieces = value.split(separator: ",", omittingEmptySubsequences: false)
        let integer = pieces[0].replacingOccurrences(of: ".", with: "")
        guard let whole = Int(integer), whole <= (Int.max / 100) else { return nil }
        let decimal = pieces.count == 2 ? String(pieces[1]) : ""
        let minor = Int(decimal.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        guard whole < (Int.max / 100) || minor <= (Int.max % 100),
              whole <= maximumMinorUnits / 100,
              whole * 100 + minor <= maximumMinorUnits else { return nil }
        let result = whole * 100 + minor
        return result > 0 ? result : nil
    }

    static func parseRateHundredths(_ input: String) -> Int? {
        guard let minor = parseMinorUnits(input), minor > 0 else { return nil }
        return minor
    }
}

struct TravelTransfer: Equatable, Identifiable {
    var id: String { "\(from)->\(to)-\(amountCents)" }
    let from: String
    let to: String
    let amountCents: Int
}

enum TravelLedger {
    static func shareCents(for expense: TravelExpense, participant: String) -> Int {
        guard let index = expense.participants.firstIndex(of: participant), !expense.participants.isEmpty else { return 0 }
        let base = expense.amountCents / expense.participants.count
        let remainder = expense.amountCents % expense.participants.count
        return base + (index < remainder ? 1 : 0)
    }

    static func balances(expenses: [TravelExpense], settlements: [TravelSettlement] = []) -> [String: Int] {
        var result: [String: Int] = [:]
        for expense in expenses {
            result[expense.payer, default: 0] += expense.amountCents
            for participant in expense.participants {
                result[participant, default: 0] -= shareCents(for: expense, participant: participant)
            }
        }
        for settlement in settlements {
            result[settlement.from, default: 0] += settlement.amountCents
            result[settlement.to, default: 0] -= settlement.amountCents
        }
        return result
    }

    static func transfers(expenses: [TravelExpense], settlements: [TravelSettlement] = []) -> [TravelTransfer] {
        let balances = balances(expenses: expenses, settlements: settlements)
        var debtors = balances.filter { $0.value < 0 }.map { ($0.key, -$0.value) }
            .sorted { $0.0 < $1.0 }
        var creditors = balances.filter { $0.value > 0 }.map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
        var result: [TravelTransfer] = []
        var debtorIndex = 0, creditorIndex = 0
        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let amount = min(debtors[debtorIndex].1, creditors[creditorIndex].1)
            if amount > 0 { result.append(TravelTransfer(from: debtors[debtorIndex].0, to: creditors[creditorIndex].0, amountCents: amount)) }
            debtors[debtorIndex].1 -= amount; creditors[creditorIndex].1 -= amount
            if debtors[debtorIndex].1 == 0 { debtorIndex += 1 }
            if creditors[creditorIndex].1 == 0 { creditorIndex += 1 }
        }
        return result
    }
}
