import XCTest

final class NativeShareUITests: XCTestCase {
    func testNativeShareRequiresPaidEntitlements() throws {
        throw XCTSkip("Native Share benötigt App-Group- und Share-Extension-Entitlements; der Personal-Team-Installationsweg verwendet Kopieren → +")
    }
}
