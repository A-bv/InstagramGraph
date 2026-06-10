import Foundation

public protocol InstagramGraphCredentialsProviding: Sendable {
    var facebookToken: String? { get }
    var instagramBusinessAccountId: String? { get }
    func validCredentials() -> Result<InstagramGraphCredentials, Error>
}

public protocol InstagramGraphAccessTokenProviding: Sendable {
    var facebookToken: String? { get }
}

public struct InstagramGraphCredentials {
    public let facebookToken: String
    public let instagramBusinessAccountId: String

    public init(facebookToken: String, instagramBusinessAccountId: String) {
        self.facebookToken = facebookToken
        self.instagramBusinessAccountId = instagramBusinessAccountId
    }
}

public struct StaticInstagramGraphCredentialsProvider: InstagramGraphCredentialsProviding {
    public let facebookToken: String?
    public let instagramBusinessAccountId: String?

    public init(facebookToken: String, instagramBusinessAccountId: String) {
        self.facebookToken = facebookToken
        self.instagramBusinessAccountId = instagramBusinessAccountId
    }

    public init(credentials: InstagramGraphCredentials) {
        self.facebookToken = credentials.facebookToken
        self.instagramBusinessAccountId = credentials.instagramBusinessAccountId
    }
}

public final class SettingsInstagramGraphCredentialsProvider: InstagramGraphCredentialsProviding, Sendable {
    private let settings: any ConnectedInsightsSettingsProtocol
    private let tokenProvider: (any InstagramGraphAccessTokenProviding)?

    public init(
        settings: any ConnectedInsightsSettingsProtocol = UserDefaultsConnectedInsightsSettings(),
        tokenProvider: (any InstagramGraphAccessTokenProviding)? = nil
    ) {
        self.settings = settings
        self.tokenProvider = tokenProvider
    }

    public var facebookToken: String? {
        tokenProvider?.facebookToken ?? settings.facebookToken
    }

    public var instagramBusinessAccountId: String? {
        settings.instagramBusinessAccountId
    }
}

public extension InstagramGraphCredentialsProviding {
    func validCredentials() -> Result<InstagramGraphCredentials, Error> {
        let token = facebookToken ?? ""
        let instagramBusinessAccountId = instagramBusinessAccountId ?? ""

        guard !token.isEmpty, !instagramBusinessAccountId.isEmpty else {
            return .failure(InstagramGraphServiceError.missingCredentials(
                hasToken: !token.isEmpty,
                hasInstagramBusinessId: !instagramBusinessAccountId.isEmpty
            ))
        }

        return .success(InstagramGraphCredentials(
            facebookToken: token,
            instagramBusinessAccountId: instagramBusinessAccountId
        ))
    }
}
