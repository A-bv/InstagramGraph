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
                print("Error finding hashtag URL: \(error)")
                completion(.failure(error))
            }
        }
    }

    private func getMedia(
        for url: String,
        completion: @escaping (Result<[DataMedia], Error>) -> Void
    ) {
        fetchDecodedData(of: Media.self, from: url) { result in
            switch result {
            case .failure(let error):
                print("Error: \(error)")
                completion(.failure(error))
            case .success(let data):
                guard let dataMedia = data as? [DataMedia] else {
                    print("Error: getMedia has no dataMedia")
                    completion(.failure(InstagramGraphServiceError.unexpectedResponse))
                    return
                }
                completion(.success(dataMedia))
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
                    self.logGraphFailure(error, url: searchURL)
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
                    body: responsePreview(data)
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

    private func fetchDecodedData<T: Decodable>(
        of type: T.Type,
        from url: String,
        completion: @escaping (Result<Any, Error>) -> Void
    ) {
        client.fetchGraphData(from: url) { result in
            switch result {
            case .failure(let error):
                self.logGraphFailure(error, url: url)
                completion(.failure(error))
            case .success(let data):
                self.handleSuccessResult(of: T.self, data: data, sourceURL: url, completion: completion)
            }
        }
    }

    private func handleSuccessResult<T: Decodable>(
        of type: T.Type,
        data: Data,
        sourceURL: String,
        completion: @escaping (Result<Any, Error>) -> Void
    ) {
        if T.self == Media.self {
            guard let decodedMedia = try? JSONDecoder().decode(Media.self, from: data) else {
                completion(.failure(decodingError(for: T.self, data: data, sourceURL: sourceURL)))
                return
            }
            completion(.success(decodedMedia.data.compactMap { $0 }))
        } else {
            guard let decodedObject = try? JSONDecoder().decode([T].self, from: data) else {
                completion(.failure(decodingError(for: T.self, data: data, sourceURL: sourceURL)))
                return
            }
            completion(.success(decodedObject))
        }
    }

    private func decodingError<T: Decodable>(
        for type: T.Type,
        data: Data,
        sourceURL: String
    ) -> Error {
        let error = InstagramGraphServiceError.decodingFailed(
            type: String(describing: type),
            body: responsePreview(data)
        )
        logGraphFailure(error, url: sourceURL)
        return error
    }

    private func logGraphFailure(_ error: Error, url: String) {
        print("[ConnectedInsights][Graph] Failure: \(error.localizedDescription)")
        print("[ConnectedInsights][Graph] URL: \(InstagramGraphLogRedactor.redacted(url))")
    }

    private func responsePreview(_ data: Data) -> String {
        let body = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
        return InstagramGraphLogRedactor.redacted(String(body.prefix(1_500)))
    }
}
