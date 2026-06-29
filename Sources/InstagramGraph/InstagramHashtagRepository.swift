import Foundation

final class InstagramHashtagRepository: HashtagSearchProviding, Sendable {
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

    func searchHashtag(searchedHashtag: String) async throws -> [InstagramPost] {
        // A hashtag with no match is "no results", not an error — return an empty list so
        // callers can show a "check your entry" state, distinct from a thrown failure
        // (network / server) that warrants a retry.
        guard let mediaSearchURL = try await findHashtagURL(searchedHashtag: searchedHashtag) else {
            return []
        }
        return try await getMedia(for: mediaSearchURL)
    }

    private func findHashtagURL(searchedHashtag: String) async throws -> String? {
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

    /// Resolves the media-search URL for the matched hashtag, or `nil` when the search
    /// decoded successfully but matched no hashtag (i.e. the term doesn't exist).
    private func resolveMediaSearchURL(
        from data: Data,
        credentials: InstagramGraphCredentials
    ) throws -> String? {
        let response = try JSONDecoder().decode(HashtagIdResponse.self, from: data)
        guard let id = response.data.first?.id else {
            return nil
        }
        guard let mediaSearchURL = endpointBuilder.hashtagMediaSearchURL(
            hashtagID: id,
            credentials: credentials
        ) else {
            throw InstagramGraphServiceError.invalidURL(id)
        }
        return mediaSearchURL
    }

    private func getMedia(for url: String) async throws -> [InstagramPost] {
        let data = try await client.fetchGraphData(from: url)
        do {
            let media = try JSONDecoder.instagram().decode(Media.self, from: data)
            return media.data
        } catch {
            let serviceError = instagramDecodingFailed(type: Media.self, data: data, underlying: error)
            InstagramGraphLogger.logFailure(serviceError, url: url)
            throw serviceError
        }
    }
}
