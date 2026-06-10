import Foundation

public protocol InstagramProfileRepositoryProtocol: ProfileDataProviding {
    func loadProfileForAnalytics(mediaLimit: Int?) async throws -> Profile
}

public final class InstagramProfileRepository: InstagramProfileRepositoryProtocol {
    private let credentialsProvider: any InstagramGraphCredentialsProviding
    private let endpointBuilder: InstagramGraphEndpointBuilder
    private let client: any InstagramGraphClientProtocol
    private let onDataFetched: ((Data) -> Void)?

    public init(
        credentialsProvider: any InstagramGraphCredentialsProviding,
        endpointBuilder: InstagramGraphEndpointBuilder,
        client: any InstagramGraphClientProtocol,
        onDataFetched: ((Data) -> Void)? = nil
    ) {
        self.credentialsProvider = credentialsProvider
        self.endpointBuilder = endpointBuilder
        self.client = client
        self.onDataFetched = onDataFetched
    }

    public func loadProfileForAnalytics(mediaLimit: Int? = nil) async throws -> Profile {
        let credentials = try credentialsProvider.validCredentials().get()
        guard let encodedUrl = endpointBuilder.analyticsProfileURL(
            mediaLimit: mediaLimit,
            credentials: credentials
        ) else {
            throw InstagramGraphServiceError.invalidURL("analytics profile")
        }

        let data = try await client.fetchGraphData(from: encodedUrl)

        guard let profile = try? JSONDecoder().decode(Profile.self, from: data) else {
            let error = InstagramGraphServiceError.decodingFailed(
                type: String(describing: Profile.self),
                body: InstagramGraphLogger.responsePreview(data)
            )
            InstagramGraphLogger.logFailure(error, url: encodedUrl)
            throw error
        }

        onDataFetched?(data)
        return profile
    }
}
