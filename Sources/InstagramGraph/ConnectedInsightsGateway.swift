import Foundation
import OSLog

/// Errors thrown by ``ConnectedInsightsGateway`` when the gateway is not properly configured.
public enum ConnectedInsightsError: LocalizedError {
    /// ``ConnectedInsightsGatewayProtocol/setup(facebookToken:)`` has not been called successfully yet.
    case setupRequired
    /// No Facebook access token is available in settings or from the token provider.
    case missingFacebookToken
    /// No Instagram Business Account ID was stored during setup.
    case missingInstagramBusinessAccountId

    public var errorDescription: String? {
        switch self {
        case .setupRequired:
            return "Connected Insights setup is required."
        case .missingFacebookToken:
            return "Facebook token is missing."
        case .missingInstagramBusinessAccountId:
            return "Instagram business account id is missing."
        }
    }
}

/// Describes whether the gateway is ready to make API calls.
public enum ConnectedInsightsAccessState {
    /// All credentials are in place; data calls can proceed.
    case ready
    /// Setup is incomplete or credentials are missing. The associated error explains why.
    case needsSetup(ConnectedInsightsError)
}

protocol HashtagSearchProviding: Sendable {
    func searchHashtag(searchedHashtag: String) async throws -> [InstagramPost]
}

protocol ProfileDataProviding: Sendable {
    func loadProfileForAnalytics(mediaLimit: Int?) async throws -> Profile
}

/// The main entry point for Instagram Graph API operations.
///
/// Create a single instance, call ``setup(facebookToken:)`` once after the user authenticates
/// with Facebook Login, then check ``accessState()`` before making data calls:
///
/// ```swift
/// let gateway = ConnectedInsightsGateway()
///
/// // Call once after login
/// try await gateway.setup(facebookToken: metaToken)
///
/// // Check state before each call
/// switch gateway.accessState() {
/// case .ready:
///     let profile = try await gateway.loadProfileForAnalytics()
/// case .needsSetup(let reason):
///     print(reason.localizedDescription)
/// }
/// ```
///
/// Credentials are persisted securely in the Keychain and survive app restarts.
@MainActor
public protocol ConnectedInsightsGatewayProtocol {
    /// Returns whether the gateway has valid credentials and is ready for data calls.
    func accessState() -> ConnectedInsightsAccessState

    /// Resolves the Instagram Business Account linked to `facebookToken` and persists credentials locally.
    ///
    /// Call this once after the user authenticates with Facebook Login. Credentials survive app
    /// restarts; you do not need to call setup on every launch.
    ///
    /// - Parameter facebookToken: A valid Meta user access token with `instagram_basic`,
    ///   `instagram_manage_insights`, and `pages_show_list` permissions.
    /// - Throws: ``InstagramGraphServiceError`` if account resolution fails.
    func setup(facebookToken: String) async throws

    /// Clears all stored credentials, requiring a new ``setup(facebookToken:)`` call.
    func reset()

    /// Returns recent public posts for a hashtag.
    ///
    /// - Parameter searchedHashtag: The hashtag to search, without the `#` prefix.
    /// - Returns: An array of ``InstagramPost`` values ordered by recency.
    /// - Throws: ``InstagramGraphServiceError``.
    func searchHashtag(searchedHashtag: String) async throws -> [InstagramPost]

    /// Returns the authenticated account's profile, insights, and recent media.
    ///
    /// - Parameter mediaLimit: Maximum number of media items to include. Pass `nil` for all available media.
    /// - Returns: A ``Profile`` containing follower counts, engagement insights, and recent posts.
    /// - Throws: ``InstagramGraphServiceError``.
    func loadProfileForAnalytics(mediaLimit: Int?) async throws -> Profile

    // TODO: func businessDiscovery(account: String) async throws -> Profile
    // Fetches a competitor account's public Instagram data via Meta's business_discovery
    // field. Needs live testing against the API before being made public.
}

public extension ConnectedInsightsGatewayProtocol {
    /// Convenience overload that loads all available media without a limit.
    func loadProfileForAnalytics() async throws -> Profile {
        try await loadProfileForAnalytics(mediaLimit: nil)
    }
}

/// Concrete implementation of ``ConnectedInsightsGatewayProtocol``.
///
/// See ``ConnectedInsightsGatewayProtocol`` for full usage documentation.
@MainActor
public final class ConnectedInsightsGateway: ConnectedInsightsGatewayProtocol {
    private var settings: any ConnectedInsightsSettingsProtocol
    private let tokenProvider: (any InstagramGraphAccessTokenProviding)?
    private let hashtagProvider: any HashtagSearchProviding
    private let profileProvider: any ProfileDataProviding
    private let accountResolver: InstagramGraphAccountResolver

    public convenience init(
        configuration: ConnectedInsightsConfiguration = .production,
        tokenProvider: (any InstagramGraphAccessTokenProviding)? = nil
    ) {
        let settings = KeychainConnectedInsightsSettings()
        let credentialsProvider = SettingsInstagramGraphCredentialsProvider(
            settings: settings,
            tokenProvider: tokenProvider
        )
        let endpointBuilder = InstagramGraphEndpointBuilder(apiGraphVersion: configuration.graphAPIVersion)
        let client = InstagramGraphClient(apiGraphVersion: configuration.graphAPIVersion)
        self.init(
            settings: settings,
            tokenProvider: tokenProvider,
            hashtagProvider: InstagramHashtagRepository(
                credentialsProvider: credentialsProvider,
                endpointBuilder: endpointBuilder,
                client: client
            ),
            profileProvider: InstagramProfileRepository(
                credentialsProvider: credentialsProvider,
                endpointBuilder: endpointBuilder,
                client: client
            ),
            accountResolver: InstagramGraphAccountResolver(apiGraphVersion: configuration.graphAPIVersion)
        )
    }

    init(
        settings: any ConnectedInsightsSettingsProtocol,
        tokenProvider: (any InstagramGraphAccessTokenProviding)? = nil,
        hashtagProvider: any HashtagSearchProviding,
        profileProvider: any ProfileDataProviding,
        accountResolver: InstagramGraphAccountResolver = InstagramGraphAccountResolver()
    ) {
        self.settings = settings
        self.tokenProvider = tokenProvider
        self.hashtagProvider = hashtagProvider
        self.profileProvider = profileProvider
        self.accountResolver = accountResolver
    }

    public func searchHashtag(searchedHashtag: String) async throws -> [InstagramPost] {
        try await hashtagProvider.searchHashtag(searchedHashtag: searchedHashtag)
    }

    public func loadProfileForAnalytics(mediaLimit: Int?) async throws -> Profile {
        try await profileProvider.loadProfileForAnalytics(mediaLimit: mediaLimit)
    }

    public func setup(facebookToken: String) async throws {
        do {
            let account = try await accountResolver.resolveAccount(facebookToken: facebookToken)
            settings.facebookToken = facebookToken
            settings.instagramBusinessAccountId = account.instagramBusinessAccountId
            settings.isCorrectSetup = true
        } catch {
            InstagramGraphLogger.logFailure(error, url: "setup/account-resolution")
            settings.isCorrectSetup = false
            throw error
        }
    }

    public func reset() {
        settings.facebookToken = nil
        settings.instagramBusinessAccountId = nil
        settings.isCorrectSetup = false
    }

    public func accessState() -> ConnectedInsightsAccessState {
        guard settings.isCorrectSetup else {
            return .needsSetup(.setupRequired)
        }

        guard let facebookToken = tokenProvider?.facebookToken ?? settings.facebookToken,
              !facebookToken.isEmpty
        else {
            return .needsSetup(.missingFacebookToken)
        }

        guard let instagramBusinessAccountId = settings.instagramBusinessAccountId,
              !instagramBusinessAccountId.isEmpty
        else {
            return .needsSetup(.missingInstagramBusinessAccountId)
        }

        return .ready
    }
}
