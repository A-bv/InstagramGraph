import Foundation

protocol ConnectedInsightsSettingsProtocol: Sendable {
    var isCorrectSetup: Bool { get set }
    var facebookToken: String? { get set }
    var instagramBusinessAccountId: String? { get set }
}

public struct ConnectedInsightsConfiguration {
    public var graphAPIVersion: String

    public init(graphAPIVersion: String) {
        self.graphAPIVersion = graphAPIVersion
    }

    public static let production = ConnectedInsightsConfiguration(graphAPIVersion: "v23.0")
}

final class UserDefaultsConnectedInsightsSettings: ConnectedInsightsSettingsProtocol, @unchecked Sendable {
    private enum Key {
        static let isCorrectSetup = "isCorrectSetup"
        static let facebookToken = "fbToken"
        static let instagramBusinessAccountId = "IgBId"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isCorrectSetup: Bool {
        get { defaults.bool(forKey: Key.isCorrectSetup) }
        set { defaults.set(newValue, forKey: Key.isCorrectSetup) }
    }

    var facebookToken: String? {
        get { defaults.string(forKey: Key.facebookToken) }
        set { defaults.set(newValue, forKey: Key.facebookToken) }
    }

    var instagramBusinessAccountId: String? {
        get { defaults.string(forKey: Key.instagramBusinessAccountId) }
        set { defaults.set(newValue, forKey: Key.instagramBusinessAccountId) }
    }


}
