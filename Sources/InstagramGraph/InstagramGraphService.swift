import Foundation

public protocol InstagramGraphServicing: HashtagSearchProviding, ProfileDataProviding {
    func searchHashtag(searchedHashtag: String) async throws -> [DataMedia]
    func loadProfileForAnalytics(mediaLimit: Int?) async throws -> Profile
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

    public convenience init(
        credentials: InstagramGraphCredentials,
        apiGraphVersion: String = ConnectedInsightsConfiguration.production.graphAPIVersion
    ) {
        let credentialsProvider = StaticInstagramGraphCredentialsProvider(credentials: credentials)
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

    public func searchHashtag(searchedHashtag: String) async throws -> [DataMedia] {
        try await hashtagRepository.searchHashtag(searchedHashtag: searchedHashtag)
    }

    public func loadProfileForAnalytics(mediaLimit: Int? = nil) async throws -> Profile {
        try await profileRepository.loadProfileForAnalytics(mediaLimit: mediaLimit)
    }

    public func businessDiscoveryURL(account: String) -> String? {
        guard case let .success(credentials) = credentialsProvider.validCredentials() else {
            return nil
        }
        return endpointBuilder.businessDiscoveryURL(account: account, credentials: credentials)
    }
}
