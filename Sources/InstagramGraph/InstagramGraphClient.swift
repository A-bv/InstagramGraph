import Foundation
import OSLog

/// Errors thrown by the Instagram Graph API networking layer.
///
/// These surface from ``ConnectedInsightsGatewayProtocol/loadProfileForAnalytics(mediaLimit:)``
/// and ``ConnectedInsightsGatewayProtocol/searchHashtag(searchedHashtag:)``.
public enum InstagramGraphServiceError: LocalizedError {
    /// A URL could not be constructed for the given path or identifier.
    case invalidURL(String)
    /// Required credentials (token or account ID) are absent from settings.
    case missingCredentials(hasToken: Bool, hasInstagramBusinessId: Bool)
    /// The token is valid but no Instagram Business or Creator account is linked to a Facebook Page.
    case instagramAccountNotFound
    /// The API returned a 2xx status with an empty body.
    case emptyResponse
    /// The API returned a non-2xx HTTP status.
    case graphHTTPError(statusCode: Int, body: String)
    /// The response body could not be decoded into the expected model type.
    case decodingFailed(type: String, body: String)
    /// A network-level failure occurred before a response was received.
    case networkError(URLError)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid Instagram Graph URL: \(url)"
        case let .missingCredentials(hasToken, hasInstagramBusinessId):
            return "Missing Instagram Graph credentials. hasToken=\(hasToken), hasInstagramBusinessId=\(hasInstagramBusinessId)"
        case .instagramAccountNotFound:
            return "No Instagram Business / Creator account connected to a Facebook Page was found for this token."
        case .emptyResponse:
            return "Instagram Graph returned an empty response."
        case let .graphHTTPError(statusCode, body):
            return "Instagram Graph HTTP error \(statusCode): \(body)"
        case let .decodingFailed(type, body):
            return "Could not decode Instagram Graph response as \(type): \(body)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

protocol URLSessionDataFetching: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionDataFetching {}

protocol InstagramGraphClientProtocol: Sendable {
    func fetchGraphData(from urlString: String) async throws -> Data
}

final class InstagramGraphClient: InstagramGraphClientProtocol, Sendable {
    private let apiGraphVersion: String
    private let session: any URLSessionDataFetching

    init(
        apiGraphVersion: String = ConnectedInsightsConfiguration.production.graphAPIVersion,
        session: any URLSessionDataFetching = URLSession.shared
    ) {
        self.apiGraphVersion = apiGraphVersion
        self.session = session
    }

    func fetchGraphData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw InstagramGraphServiceError.invalidURL(InstagramGraphLogRedactor.redacted(urlString))
        }

        InstagramGraphLogger.logRequest(version: apiGraphVersion, url: urlString)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let urlError as URLError {
            throw InstagramGraphServiceError.networkError(urlError)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstagramGraphServiceError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            throw InstagramGraphServiceError.graphHTTPError(
                statusCode: httpResponse.statusCode,
                body: InstagramGraphLogRedactor.redacted(String(body.prefix(1_500)))
            )
        }

        guard !data.isEmpty else {
            throw InstagramGraphServiceError.emptyResponse
        }

        return data
    }
}

/// Builds a ``InstagramGraphServiceError/decodingFailed(type:body:)`` that names the failing key
/// or type — the most useful detail when Meta changes the response schema — alongside a redacted
/// preview of the body.
func instagramDecodingFailed(type: Any.Type, data: Data, underlying: Error) -> InstagramGraphServiceError {
    let preview = InstagramGraphLogger.responsePreview(data)
    let body: String
    if let decodingError = underlying as? DecodingError {
        body = "\(decodingError.instagramSummary) — \(preview)"
    } else {
        body = preview
    }
    return .decodingFailed(type: String(describing: type), body: body)
}

extension DecodingError {
    /// A concise, log-safe summary naming the failing coding path and reason.
    var instagramSummary: String {
        switch self {
        case let .keyNotFound(key, context):
            return "missing key '\(key.stringValue)' at \(context.codingPath.instagramPath)"
        case let .typeMismatch(type, context):
            return "type mismatch for \(type) at \(context.codingPath.instagramPath)"
        case let .valueNotFound(type, context):
            return "missing value for \(type) at \(context.codingPath.instagramPath)"
        case let .dataCorrupted(context):
            return "data corrupted at \(context.codingPath.instagramPath): \(context.debugDescription)"
        @unknown default:
            return "decoding failed"
        }
    }
}

private extension [CodingKey] {
    var instagramPath: String {
        isEmpty ? "<root>" : map(\.stringValue).joined(separator: ".")
    }
}

enum InstagramGraphLogRedactor {
    static func redacted(_ value: String) -> String {
        value.replacingOccurrences(
            of: #"access_token=[^&\s]+"#,
            with: "access_token=<redacted>",
            options: .regularExpression
        )
    }
}

enum InstagramGraphLogger {
    private static let logger = Logger(subsystem: "InstagramGraph", category: "graph")

    static func logRequest(version: String, url: String) {
        logger.debug("Request \(version): \(InstagramGraphLogRedactor.redacted(url))")
    }

    static func logFailure(_ error: Error, url: String) {
        logger.error("Failure: \(error.localizedDescription) — \(InstagramGraphLogRedactor.redacted(url))")
    }

    static func responsePreview(_ data: Data) -> String {
        let body = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
        return InstagramGraphLogRedactor.redacted(String(body.prefix(1_500)))
    }
}
