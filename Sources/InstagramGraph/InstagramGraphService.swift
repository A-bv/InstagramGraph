import Foundation

public protocol InstagramGraphServicing: HashtagSearchProviding, ProfileDataProviding {
    func searchHashtag(
        searchedHashtag: String,
        completion: @escaping (Result<[DataMedia], Error>) -> Void
    )

    func loadProfileForAnalytics(completion: @escaping (Result<Profile, Error>) -> Void)
}

public final class InstagramGraphService: InstagramGraphServicing {
    private let hashtagRepository: any InstagramHashtagRepositoryProtocol
    private let profileRepository: any InstagramProfileRepositoryProtocol
    private let credentialsProvider: any InstagramGraphCredentialsProviding
    private let endpointBuilder: InstagramGraphEndpointBuilder

    public convenience init(
        settings: any ConnectedInsightsSettingsProtocol = UserDefaultsConnectedInsightsSettings(),
        apiGraphVersion: String = ConnectedInsightsConfiguration.production.graphAPIVersion
    ) {
        let credentialsProvider = SettingsInstagramGraphCredentialsProvider(settings: settings)
        let endpointBuilder = InstagramGraphEndpointBuilder(apiGraphVersion: apiGraphVersion)
        let client = InstagramGraphClient(apiGraphVersion: apiGraphVersion)
        self.init(
            credentialsProvider: credentialsProvider,
            endpointBuilder: endpointBuilder,
            hashtagRepository: InstagramHashtagRepository(
                credentialsProvider: credentialsProvider,
                endpointBuilder: endpointBuilder,
                client: client
            ),
            profileRepository: InstagramProfileRepository(
                credentialsProvider: credentialsProvider,
                endpointBuilder: endpointBuilder,
                client: client
            )
        )
    }

    public init(
        credentialsProvider: any InstagramGraphCredentialsProviding,
        endpointBuilder: InstagramGraphEndpointBuilder,
        hashtagRepository: any InstagramHashtagRepositoryProtocol,
        profileRepository: any InstagramProfileRepositoryProtocol
    ) {
        self.credentialsProvider = credentialsProvider
        self.endpointBuilder = endpointBuilder
        self.hashtagRepository = hashtagRepository
        self.profileRepository = profileRepository
    }

    public func searchHashtag(
        searchedHashtag: String,
        completion: @escaping (Result<[DataMedia], Error>) -> Void
    ) {
        hashtagRepository.searchHashtag(searchedHashtag: searchedHashtag, completion: completion)
    }

    public func loadProfileForAnalytics(completion: @escaping (Result<Profile, Error>) -> Void) {
        profileRepository.loadProfileForAnalytics(completion: completion)
    }

    public func business_discovery_url(account: String) -> String? {
        guard case let .success(credentials) = credentialsProvider.validCredentials() else {
            return nil
        }
        return endpointBuilder.businessDiscoveryURL(account: account, credentials: credentials)
    }
}
