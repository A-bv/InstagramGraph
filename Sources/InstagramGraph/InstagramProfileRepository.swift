import Foundation

protocol InstagramProfileRepositoryProtocol: ProfileDataProviding {
    func loadProfileForAnalytics(mediaLimit: Int?) async throws -> Profile
}

final class InstagramProfileRepository: InstagramProfileRepositoryProtocol, Sendable {
    private let credentialsProvider: any InstagramGraphCredentialsProviding
    private let endpointBuilder: InstagramGraphEndpointBuilder
    private let client: any InstagramGraphClientProtocol

    init(
        credentialsProvider: any InstagramGraphCredentialsProviding,
        endpointBuilder: InstagramGraphEndpointBuilder,
        client: any InstagramGraphClientProtocol
    ) {
        self.credentialsProvider = credentialsProvider
        self.endpointBuilder = endpointBuilder
        self.client = client
    }

    func loadProfileForAnalytics(mediaLimit: Int? = nil) async throws -> Profile {
        let credentials = try credentialsProvider.validCredentials().get()
        guard let encodedUrl = endpointBuilder.analyticsProfileURL(
            mediaLimit: mediaLimit,
            credentials: credentials
        ) else {
            throw InstagramGraphServiceError.invalidURL("analytics profile")
        }

        let data = try await client.fetchGraphData(from: encodedUrl)

        guard let profile = try? JSONDecoder.instagram().decode(Profile.self, from: data) else {
            let error = InstagramGraphServiceError.decodingFailed(
                type: String(describing: Profile.self),
                body: InstagramGraphLogger.responsePreview(data)
            )
            InstagramGraphLogger.logFailure(error, url: encodedUrl)
            throw error
        }

        return profile
    }
}
