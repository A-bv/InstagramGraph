import Foundation

public protocol ConnectedInsightsSettingsProtocol {
    var isCorrectSetup: Bool { get set }
    var facebookToken: String? { get set }
    var instagramBusinessAccountId: String? { get set }
    var setupInfoShown: Bool { get set }
    var pressedFacebookLoginButton: Bool { get set }
}

public struct ConnectedInsightsConfiguration {
    public var graphAPIVersion: String

    public init(graphAPIVersion: String) {
        self.graphAPIVersion = graphAPIVersion
    }

    public static let production = ConnectedInsightsConfiguration(graphAPIVersion: "v23.0")
}

public final class UserDefaultsConnectedInsightsSettings: ConnectedInsightsSettingsProtocol {
    private enum Key {
        static let isCorrectSetup = "isCorrectSetup"
        static let facebookToken = "fbToken"
        static let instagramBusinessAccountId = "IgBId"
        static let setupInfoShown = "setupInfoShownOnce"
        static let pressedFacebookLoginButton = "pressedFBLoginButton"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isCorrectSetup: Bool {
        get { defaults.bool(forKey: Key.isCorrectSetup) }
        set { defaults.set(newValue, forKey: Key.isCorrectSetup) }
    }

    public var facebookToken: String? {
        get { defaults.string(forKey: Key.facebookToken) }
        set { defaults.set(newValue, forKey: Key.facebookToken) }
    }

    public var instagramBusinessAccountId: String? {
        get { defaults.string(forKey: Key.instagramBusinessAccountId) }
        set { defaults.set(newValue, forKey: Key.instagramBusinessAccountId) }
    }

    public var setupInfoShown: Bool {
        get { defaults.bool(forKey: Key.setupInfoShown) }
        set { defaults.set(newValue, forKey: Key.setupInfoShown) }
    }

    public var pressedFacebookLoginButton: Bool {
        get { defaults.bool(forKey: Key.pressedFacebookLoginButton) }
        set { defaults.set(newValue, forKey: Key.pressedFacebookLoginButton) }
    }
}
