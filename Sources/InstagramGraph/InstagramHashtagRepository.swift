import Foundation

public protocol InstagramHashtagRepositoryProtocol: HashtagSearchProviding {
    func searchHashtag(
        searchedHashtag: String,
        completion: @escaping (Result<[DataMedia], Error>) -> Void
    )
}

public final class InstagramHashtagRepository: InstagramHashtagRepositoryProtocol {
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

    public func searchHashtag(
        searchedHashtag: String,
        completion: @escaping (Result<[DataMedia], Error>) -> Void
    ) {
        findHashtagUrl(searchedHashtag: searchedHashtag) { result in
            switch result {
            case .success(let mediaSearchURL):
                self.getMedia(for: mediaSearchURL, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func getMedia(
        for url: String,
        completion: @escaping (Result<[DataMedia], Error>) -> Void
    ) {
        client.fetchGraphData(from: url) { result in
            switch result {
            case .failure(let error):
                InstagramGraphLogger.logFailure(error, url: url)
                completion(.failure(error))
            case .success(let data):
                guard let media = try? JSONDecoder().decode(Media.self, from: data) else {
                    let error = InstagramGraphServiceError.decodingFailed(
                        type: String(describing: Media.self),
                        body: InstagramGraphLogger.responsePreview(data)
                    )
                    InstagramGraphLogger.logFailure(error, url: url)
                    completion(.failure(error))
                    return
                }
                completion(.success(media.data.compactMap { $0 }))
            }
        }
    }

    private func findHashtagUrl(
        searchedHashtag: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        switch credentialsProvider.validCredentials() {
        case .failure(let error):
            completion(.failure(error))
        case .success(let credentials):
            guard let searchURL = endpointBuilder.hashtagSearchURL(
                searchedHashtag: searchedHashtag,
                credentials: credentials
            ) else {
                completion(.failure(InstagramGraphServiceError.invalidURL(searchedHashtag)))
                return
            }

            client.fetchGraphData(from: searchURL) { result in
                switch result {
                case .success(let data):
                    self.handleHashtagIdResponse(data: data, credentials: credentials, completion: completion)
                case .failure(let error):
                    InstagramGraphLogger.logFailure(error, url: searchURL)
                    completion(.failure(error))
                }
            }
        }
    }

    private func handleHashtagIdResponse(
        data: Data,
        credentials: InstagramGraphCredentials,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        do {
            let response = try JSONDecoder().decode(HashtagIdResponse.self, from: data)
            guard let id = response.data.first?.id else {
                completion(.failure(InstagramGraphServiceError.decodingFailed(
                    type: String(describing: HashtagIdResponse.self),
                    body: InstagramGraphLogger.responsePreview(data)
                )))
                return
            }
            guard let mediaSearchURL = endpointBuilder.hashtagMediaSearchURL(
                hashtagID: id,
                credentials: credentials
            ) else {
                completion(.failure(InstagramGraphServiceError.invalidURL(id)))
                return
            }
            completion(.success(mediaSearchURL))
        } catch {
            completion(.failure(error))
        }
    }

}
