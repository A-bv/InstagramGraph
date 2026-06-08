import Foundation

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

public protocol HashtagSearchProviding {
    func searchHashtag(
        searchedHashtag: String,
        completion: @escaping (Result<[DataMedia], Error>) -> Void
    )
}

public protocol ProfileDataProviding {
    func loadProfileForAnalytics(completion: @escaping (Result<Profile, Error>) -> Void)
}

public protocol ConnectedInsightsGatewayProtocol {
    var hashtagProvider: any HashtagSearchProviding { get }
    var profileProvider: any ProfileDataProviding { get }

    func accessState() -> ConnectedInsightsAccessState
}

public final class ConnectedInsightsGateway: ConnectedInsightsGatewayProtocol {
    private let settings: any ConnectedInsightsSettingsProtocol
    public let hashtagProvider: any HashtagSearchProviding
    public let profileProvider: any ProfileDataProviding

    public convenience init(
        settings: any ConnectedInsightsSettingsProtocol = UserDefaultsConnectedInsightsSettings(),
        configuration: ConnectedInsightsConfiguration = .production
    ) {
        let credentialsProvider = SettingsInstagramGraphCredentialsProvider(settings: settings)
        let endpointBuilder = InstagramGraphEndpointBuilder(apiGraphVersion: configuration.graphAPIVersion)
        let client = InstagramGraphClient(apiGraphVersion: configuration.graphAPIVersion)
        self.init(
            settings: settings,
            hashtagProvider: InstagramHashtagRepository(
                credentialsProvider: credentialsProvider,
                endpointBuilder: endpointBuilder,
                client: client
            ),
            profileProvider: InstagramProfileRepository(
                credentialsProvider: credentialsProvider,
                endpointBuilder: endpointBuilder,
                client: client
            )
        )
    }

    public init(
        settings: any ConnectedInsightsSettingsProtocol,
        hashtagProvider: any HashtagSearchProviding,
        profileProvider: any ProfileDataProviding
    ) {
        self.settings = settings
        self.hashtagProvider = hashtagProvider
        self.profileProvider = profileProvider
    }

    public func accessState() -> ConnectedInsightsAccessState {
        guard settings.isCorrectSetup else {
            return .needsSetup(.setupRequired)
        }

        guard let facebookToken = settings.facebookToken, !facebookToken.isEmpty else {
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

    public func searchHashtag(
        searchedHashtag: String,
        completion: @escaping (Result<[DataMedia], Error>) -> Void
    ) {
        completion(.failure(ConnectedInsightsError.dataProviderUnavailable))
    }
}

public struct UnavailableProfileProvider: ProfileDataProviding {
    public init() {}

    public func loadProfileForAnalytics(completion: @escaping (Result<Profile, Error>) -> Void) {
        completion(.failure(ConnectedInsightsError.dataProviderUnavailable))
    }
}
