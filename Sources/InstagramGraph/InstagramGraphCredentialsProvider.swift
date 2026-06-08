import Foundation

public protocol InstagramGraphCredentialsProviding {
    var facebookToken: String? { get }
    var instagramBusinessAccountId: String? { get }
}

public struct InstagramGraphCredentials {
    public let facebookToken: String
    public let instagramBusinessAccountId: String

    public init(facebookToken: String, instagramBusinessAccountId: String) {
        self.facebookToken = facebookToken
        self.instagramBusinessAccountId = instagramBusinessAccountId
    }
}

public final class SettingsInstagramGraphCredentialsProvider: InstagramGraphCredentialsProviding {
    private let settings: any ConnectedInsightsSettingsProtocol

    public init(settings: any ConnectedInsightsSettingsProtocol = UserDefaultsConnectedInsightsSettings()) {
        self.settings = settings
    }

    public var facebookToken: String? {
        settings.facebookToken
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
