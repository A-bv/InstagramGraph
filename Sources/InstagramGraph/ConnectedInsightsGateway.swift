import Foundation
import OSLog

public struct ConnectedInsightsSession {
    public let facebookToken: String
    public let instagramBusinessAccountId: String

    public init(facebookToken: String, instagramBusinessAccountId: String) {
        self.facebookToken = facebookToken
        self.instagramBusinessAccountId = instagramBusinessAccountId
    }
}

public enum ConnectedInsightsError: LocalizedError {
    case setupRequired
    case missingFacebookToken
    case missingInstagramBusinessAccountId
    case dataProviderUnavailable

    public var errorDescription: String? {
        switch self {
        case .setupRequired:
            return "Connected Insights setup is required."
        case .missingFacebookToken:
            return "Facebook token is missing."
        case .missingInstagramBusinessAccountId:
            return "Instagram business account id is missing."
        case .dataProviderUnavailable:
            return "Connected Insights data provider is unavailable."
        }
    }
}

public enum ConnectedInsightsAccessState {
    case ready(ConnectedInsightsSession)
    case needsSetup(ConnectedInsightsError)
}

public protocol HashtagSearchProviding: Sendable {
    func searchHashtag(searchedHashtag: String) async throws -> [DataMedia]
}

public protocol ProfileDataProviding: Sendable {
    func loadProfileForAnalytics(mediaLimit: Int?) async throws -> Profile
}

public extension ProfileDataProviding {
    func loadProfileForAnalytics() async throws -> Profile {
        try await loadProfileForAnalytics(mediaLimit: nil)
    }
}

@MainActor
public protocol ConnectedInsightsGatewayProtocol: HashtagSearchProviding, ProfileDataProviding {
    func accessState() -> ConnectedInsightsAccessState
    func setup(facebookToken: String) async throws
    func reset()

    // TODO: func businessDiscoveryURL(account: String) -> String?
    // Builds a Graph API URL for fetching a competitor account's public Instagram data
    // via Meta's business_discovery field. Needs live testing against the API before
    // being made public — the endpoint behaviour has not been verified.
}

@MainActor
public final class ConnectedInsightsGateway: ConnectedInsightsGatewayProtocol {
    private var settings: any ConnectedInsightsSettingsProtocol
    private let tokenProvider: (any InstagramGraphAccessTokenProviding)?
    private let hashtagProvider: any HashtagSearchProviding
    private let profileProvider: any ProfileDataProviding
    private let accountResolver: InstagramGraphAccountResolver

    public convenience init(
        settings: any ConnectedInsightsSettingsProtocol = UserDefaultsConnectedInsightsSettings(),
        configuration: ConnectedInsightsConfiguration = .production,
        tokenProvider: (any InstagramGraphAccessTokenProviding)? = nil
    ) {
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

    public func searchHashtag(searchedHashtag: String) async throws -> [DataMedia] {
        try await hashtagProvider.searchHashtag(searchedHashtag: searchedHashtag)
    }

    public func loadProfileForAnalytics(mediaLimit: Int?) async throws -> Profile {
        try await profileProvider.loadProfileForAnalytics(mediaLimit: mediaLimit)
    }

    public func setup(facebookToken: String) async throws {
        do {
            let account = try await accountResolver.resolveAccount(facebookToken: facebookToken)
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

        return .ready(ConnectedInsightsSession(
            facebookToken: facebookToken,
            instagramBusinessAccountId: instagramBusinessAccountId
        ))
    }
}

public struct UnavailableHashtagProvider: HashtagSearchProviding {
    public init() {}

    public func searchHashtag(searchedHashtag: String) async throws -> [DataMedia] {
        throw ConnectedInsightsError.dataProviderUnavailable
    }
}

public struct UnavailableProfileProvider: ProfileDataProviding {
    public init() {}

    public func loadProfileForAnalytics(mediaLimit: Int? = nil) async throws -> Profile {
        throw ConnectedInsightsError.dataProviderUnavailable
    }
}
