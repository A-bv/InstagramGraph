import Foundation

final class InstagramProfileRepository: ProfileDataProviding, Sendable {
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

        do {
            return try JSONDecoder.instagram().decode(Profile.self, from: data)
        } catch {
            let serviceError = instagramDecodingFailed(type: Profile.self, data: data, underlying: error)
            InstagramGraphLogger.logFailure(serviceError, url: encodedUrl)
            throw serviceError
        }
    }
}
