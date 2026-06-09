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
    func loadProfileForAnalytics(
        mediaLimit: Int?,
        completion: @escaping (Result<Profile, Error>) -> Void
    )
}

public extension ProfileDataProviding {
    func loadProfileForAnalytics(completion: @escaping (Result<Profile, Error>) -> Void) {
        loadProfileForAnalytics(mediaLimit: nil, completion: completion)
    }
}

public protocol ConnectedInsightsGatewayProtocol {
    var hashtagProvider: any HashtagSearchProviding { get }
    var profileProvider: any ProfileDataProviding { get }

    func accessState() -> ConnectedInsightsAccessState
    func setup(facebookToken: String, completion: @escaping (Result<Void, Error>) -> Void)
    func setup(facebookToken: String, completion: @escaping (Bool) -> Void)
    func reset()
}

public final class ConnectedInsightsGateway: ConnectedInsightsGatewayProtocol {
    private var settings: any ConnectedInsightsSettingsProtocol
    private let tokenProvider: (any InstagramGraphAccessTokenProviding)?
    public let hashtagProvider: any HashtagSearchProviding
    public let profileProvider: any ProfileDataProviding
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

    public init(
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

    public func setup(facebookToken: String, completion: @escaping (Result<Void, Error>) -> Void) {
        accountResolver.resolveAccount(facebookToken: facebookToken) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let account):
                self.settings.instagramBusinessAccountId = account.instagramBusinessAccountId
                self.settings.isCorrectSetup = true
                completion(.success(()))
            case .failure(let error):
                print("[ConnectedInsights][Setup] Account resolution failed: \(error.localizedDescription)")
                self.settings.isCorrectSetup = false
                completion(.failure(error))
            }
        }
    }

    public func setup(facebookToken: String, completion: @escaping (Bool) -> Void) {
        setup(facebookToken: facebookToken) { result in
            switch result {
            case .success:
                completion(true)
            case .failure:
                completion(false)
            }
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

    public func searchHashtag(
        searchedHashtag: String,
        completion: @escaping (Result<[DataMedia], Error>) -> Void
    ) {
        completion(.failure(ConnectedInsightsError.dataProviderUnavailable))
    }
}

public struct UnavailableProfileProvider: ProfileDataProviding {
    public init() {}

    public func loadProfileForAnalytics(
        mediaLimit: Int? = nil,
        completion: @escaping (Result<Profile, Error>) -> Void
    ) {
        completion(.failure(ConnectedInsightsError.dataProviderUnavailable))
    }
}
