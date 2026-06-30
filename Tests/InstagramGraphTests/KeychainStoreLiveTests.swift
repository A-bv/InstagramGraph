import XCTest
@testable import InstagramGraph

/// Exercises the real `KeychainStore` against the system Keychain (not the in-memory fake used by
/// the unit tests). Gated behind `RUN_KEYCHAIN_LIVE=1` because Keychain access can be unavailable
/// in headless / unsigned CI environments.
///
///     RUN_KEYCHAIN_LIVE=1 swift test --filter KeychainStoreLiveTests
final class KeychainStoreLiveTests: XCTestCase {
    private var service = ""
    private var store: KeychainStore!

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_KEYCHAIN_LIVE"] == "1",
            "Set RUN_KEYCHAIN_LIVE=1 to run the live Keychain round-trip tests."
        )
        service = "InstagramGraph.test.\(UUID().uuidString)"
        store = KeychainStore(service: service)
    }

    override func tearDown() {
        store?.set(nil, forKey: "fbToken")
        store?.set(nil, forKey: "IgBId")
    }

    func testRealKeychain_writeReadUpdateDeleteRoundTrip() {
        XCTAssertNil(store.string(forKey: "fbToken"))

        XCTAssertTrue(store.set("token-1", forKey: "fbToken"))
        XCTAssertEqual(store.string(forKey: "fbToken"), "token-1")

        // Overwriting an existing item must succeed (SecItemUpdate path).
        XCTAssertTrue(store.set("token-2", forKey: "fbToken"))
        XCTAssertEqual(store.string(forKey: "fbToken"), "token-2")

        XCTAssertTrue(store.set(nil, forKey: "fbToken"))
        XCTAssertNil(store.string(forKey: "fbToken"))
    }

    func testRealKeychain_migratesLegacyUserDefaultsCredentials() throws {
        let suiteName = "KeychainLiveTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("legacy-token", forKey: "fbToken")
        defaults.set("legacy-ig-id", forKey: "IgBId")

        let settings = KeychainConnectedInsightsSettings(defaults: defaults, keychain: store)

        XCTAssertEqual(settings.facebookToken, "legacy-token")
        XCTAssertEqual(settings.instagramBusinessAccountId, "legacy-ig-id")
        // Plaintext copies cleared once safely in the Keychain.
        XCTAssertNil(defaults.string(forKey: "fbToken"))
        XCTAssertNil(defaults.string(forKey: "IgBId"))
    }
}
