import XCTest
@testable import Album

/// Fehlerfälle zuerst aufgeschrieben, dann der Code (Beta-Test 1, Einfügen statt Tippen).
final class MoneyAndLinkParsingTests: XCTestCase {
    private func cents(_ text: String) -> Int? { GermanMoneyParser.parseMinorUnits(text) }

    // MARK: Beträge, die erkannt werden müssen

    func testPastedAmountsAreRecognised() {
        XCTAssertEqual(cents("12,50 €"), 1_250)
        XCTAssertEqual(cents("€ 12,50"), 1_250)
        XCTAssertEqual(cents("12,50€"), 1_250)
        XCTAssertEqual(cents("EUR 12,50"), 1_250)
        XCTAssertEqual(cents("12.50"), 1_250)
        XCTAssertEqual(cents("1.250,50 "), 125_050)
        XCTAssertEqual(cents("1.250,50\u{00A0}€"), 125_050)
        XCTAssertEqual(cents(" 7 "), 700)
    }

    // MARK: Mehrdeutige Punkte

    func testDotAmbiguity() {
        XCTAssertEqual(cents("1.250"), 125_000)   // genau 3 Nachkommastellen: Tausenderpunkt
        XCTAssertEqual(cents("12.500"), 1_250_000) // Tausenderpunkt
        XCTAssertEqual(cents("12.5"), 1_250)      // 1 Stelle: Dezimaltrenner
        XCTAssertEqual(cents("12.50"), 1_250)     // 2 Stellen: Dezimaltrenner
        XCTAssertEqual(cents("10.00"), 1_000)
        XCTAssertEqual(cents("1.25"), 125)
        XCTAssertNil(cents("1.250.000"))   // über der Obergrenze
        XCTAssertEqual(cents("123.456"), 12_345_600)
    }

    // MARK: Abzulehnende Eingaben

    func testMalformedAmountsAreRejected() {
        XCTAssertNil(cents("-5"))
        XCTAssertNil(cents("−5,00"))
        XCTAssertNil(cents("0"))
        XCTAssertNil(cents("0,00"))
        XCTAssertNil(cents("0.00"))
        XCTAssertNil(cents(""))
        XCTAssertNil(cents("   "))
        XCTAssertNil(cents("€"))
        XCTAssertNil(cents("1.2.3"))
        XCTAssertNil(cents("1,2,3"))
        XCTAssertNil(cents("1.23,4"))
        XCTAssertNil(cents("1234.567"))   // falsche Gruppierung
        XCTAssertNil(cents("12,345"))
        XCTAssertNil(cents("1,250.50"))   // englisch: Komma vor Punkt
        XCTAssertNil(cents("12.50.00"))
        XCTAssertNil(cents("abc"))
        XCTAssertNil(cents("12,5a"))
        XCTAssertNil(cents("9999999,99"))
        XCTAssertNil(cents("."))
        XCTAssertNil(cents(",50"))
    }

    // MARK: Links

    func testLinksWithoutSchemeGetHTTPS() {
        XCTAssertEqual(LinkValidation.url("www.prague.eu")?.absoluteString, "https://www.prague.eu")
        XCTAssertEqual(LinkValidation.url("prague.eu/x")?.absoluteString, "https://prague.eu/x")
        XCTAssertEqual(LinkValidation.url("  prague.eu  ")?.absoluteString, "https://prague.eu")
        XCTAssertEqual(LinkValidation.url("https://prague.eu/x")?.absoluteString, "https://prague.eu/x")
        XCTAssertEqual(LinkValidation.url("http://prague.eu")?.absoluteString, "http://prague.eu")
    }

    func testEmbeddedLinkTakesFirstLink() {
        XCTAssertEqual(LinkValidation.url("Schau mal: https://prague.eu/x")?.absoluteString, "https://prague.eu/x")
        XCTAssertEqual(LinkValidation.url("Tipp www.prague.eu und https://zweiter.example/b")?.absoluteString, "https://www.prague.eu")
    }

    func testNonLinksAreRejected() {
        XCTAssertNil(LinkValidation.url(""))
        XCTAssertNil(LinkValidation.url("   "))
        XCTAssertNil(LinkValidation.url("hallo"))
        XCTAssertNil(LinkValidation.url("hallo welt"))
        XCTAssertNil(LinkValidation.url("mailto:a@b.de"))
        XCTAssertNil(LinkValidation.url("javascript:alert(1)"))
        XCTAssertNil(LinkValidation.url("ftp://prague.eu"))
        XCTAssertNil(LinkValidation.url("192.168.0.1"))
        XCTAssertNil(LinkValidation.url("1.5"))
    }
}
