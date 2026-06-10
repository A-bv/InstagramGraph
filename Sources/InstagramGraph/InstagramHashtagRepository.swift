import Foundation

public protocol InstagramHashtagRepositoryProtocol: HashtagSearchProviding {
    func searchHashtag(searchedHashtag: String) async throws -> [DataMedia]
}

public final class InstagramHashtagRepository: InstagramHashtagRepositoryProtocol, Sendable {
    private let credentialsProvider: any InstagramGraphCredentialsProviding
    private let endpointBuilder: InstagramGraphEndpointBuilder
    private let client: any InstagramGraphClientProtocol

    public init(
        credentialsProvider: any InstagramGraphCredentialsProviding,
        endpointBuilder: InstagramGraphEndpointBuilder,
        client: any InstagramGraphClientProtocol
    ) {
        self.credentialsProvider = credentialsProvider
        self.endpointBuilder = endpointBuilder
        self.client = client
    }

    public func searchHashtag(searchedHashtag: String) async throws -> [DataMedia] {
        let mediaSearchURL = try await findHashtagURL(searchedHashtag: searchedHashtag)
        return try await getMedia(for: mediaSearchURL)
    }

    private func findHashtagURL(searchedHashtag: String) async throws -> String {
        let credentials = try credentialsProvider.validCredentials().get()
        guard let searchURL = endpointBuilder.hashtagSearchURL(
            searchedHashtag: searchedHashtag,
            credentials: credentials
        ) else {
            throw InstagramGraphServiceError.invalidURL(searchedHashtag)
        }

        let data = try await client.fetchGraphData(from: searchURL)
        return try resolveMediaSearchURL(from: data, credentials: credentials)
    }

    private func resolveMediaSearchURL(
        from data: Data,
        credentials: InstagramGraphCredentials
    ) throws -> String {
        let response = try JSONDecoder().decode(HashtagIdResponse.self, from: data)
        guard let id = response.data.first?.id else {
            throw InstagramGraphServiceError.decodingFailed(
                type: String(describing: HashtagIdResponse.self),
                body: InstagramGraphLogger.responsePreview(data)
            )
        }
        guard let mediaSearchURL = endpointBuilder.hashtagMediaSearchURL(
            hashtagID: id,
            credentials: credentials
        ) else {
            throw InstagramGraphServiceError.invalidURL(id)
        }
        return mediaSearchURL
    }

    private func getMedia(for url: String) async throws -> [DataMedia] {
        let data = try await client.fetchGraphData(from: url)
        guard let media = try? JSONDecoder().decode(Media.self, from: data) else {
            let error = InstagramGraphServiceError.decodingFailed(
                type: String(describing: Media.self),
                body: InstagramGraphLogger.responsePreview(data)
            )
            InstagramGraphLogger.logFailure(error, url: url)
            throw error
        }
        return media.data
    }
}
