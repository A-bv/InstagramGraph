import Foundation

protocol InstagramGraphCredentialsProviding: Sendable {
    var facebookToken: String? { get }
    var instagramBusinessAccountId: String? { get }
    func validCredentials() -> Result<InstagramGraphCredentials, Error>
}

public protocol InstagramGraphAccessTokenProviding: Sendable {
    var facebookToken: String? { get }
}

struct InstagramGraphCredentials {
    let facebookToken: String
    let instagramBusinessAccountId: String
}

struct StaticInstagramGraphCredentialsProvider: InstagramGraphCredentialsProviding {
    let facebookToken: String?
    let instagramBusinessAccountId: String?

    init(facebookToken: String, instagramBusinessAccountId: String) {
        self.facebookToken = facebookToken
        self.instagramBusinessAccountId = instagramBusinessAccountId
    }

    init(credentials: InstagramGraphCredentials) {
        self.facebookToken = credentials.facebookToken
        self.instagramBusinessAccountId = credentials.instagramBusinessAccountId
    }
}

final class SettingsInstagramGraphCredentialsProvider: InstagramGraphCredentialsProviding, Sendable {
    private let settings: any ConnectedInsightsSettingsProtocol
    private let tokenProvider: (any InstagramGraphAccessTokenProviding)?

    init(
        settings: any ConnectedInsightsSettingsProtocol = UserDefaultsConnectedInsightsSettings(),
        tokenProvider: (any InstagramGraphAccessTokenProviding)? = nil
    ) {
        self.settings = settings
        self.tokenProvider = tokenProvider
    }

    var facebookToken: String? {
        tokenProvider?.facebookToken ?? settings.facebookToken
    }

    var instagramBusinessAccountId: String? {
        settings.instagramBusinessAccountId
    }
}

extension InstagramGraphCredentialsProviding {
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
