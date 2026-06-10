import Foundation
import OSLog

public enum InstagramGraphServiceError: LocalizedError {
    case invalidURL(String)
    case missingCredentials(hasToken: Bool, hasInstagramBusinessId: Bool)
    case instagramAccountNotFound
    case emptyResponse
    case unexpectedResponse
    case graphHTTPError(statusCode: Int, body: String)
    case decodingFailed(type: String, body: String)

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
        case .unexpectedResponse:
            return "Instagram Graph returned an unexpected response."
        case let .graphHTTPError(statusCode, body):
            return "Instagram Graph HTTP error \(statusCode): \(body)"
        case let .decodingFailed(type, body):
            return "Could not decode Instagram Graph response as \(type): \(body)"
        }
    }
}

public protocol InstagramGraphClientProtocol: Sendable {
    func fetchGraphData(from urlString: String) async throws -> Data
}

public final class InstagramGraphClient: InstagramGraphClientProtocol, Sendable {
    private let apiGraphVersion: String
    private let session: URLSession

    public init(
        apiGraphVersion: String = ConnectedInsightsConfiguration.production.graphAPIVersion,
        session: URLSession = .shared
    ) {
        self.apiGraphVersion = apiGraphVersion
        self.session = session
    }

    public func fetchGraphData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw InstagramGraphServiceError.invalidURL(InstagramGraphLogRedactor.redacted(urlString))
        }

        InstagramGraphLogger.logRequest(version: apiGraphVersion, url: urlString)

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstagramGraphServiceError.unexpectedResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            throw InstagramGraphServiceError.graphHTTPError(
                statusCode: httpResponse.statusCode,
                body: InstagramGraphLogRedactor.redacted(String(body.prefix(1_500)))
            )
        }

        return data
    }
}

public enum InstagramGraphLogRedactor {
    public static func redacted(_ value: String) -> String {
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
