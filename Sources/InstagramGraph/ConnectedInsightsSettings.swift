import Foundation

protocol ConnectedInsightsSettingsProtocol: Sendable {
    var isCorrectSetup: Bool { get set }
    var facebookToken: String? { get set }
    var instagramBusinessAccountId: String? { get set }
}

/// Configuration for the Instagram Graph API connection.
public struct ConnectedInsightsConfiguration {
    /// The Graph API version used in all requests (e.g. `"v23.0"`).
    public var graphAPIVersion: String

    /// Creates a configuration with the specified Graph API version string.
    public init(graphAPIVersion: String) {
        self.graphAPIVersion = graphAPIVersion
    }

    /// The default production configuration targeting the latest supported Graph API version.
    public static let production = ConnectedInsightsConfiguration(graphAPIVersion: "v23.0")
}
