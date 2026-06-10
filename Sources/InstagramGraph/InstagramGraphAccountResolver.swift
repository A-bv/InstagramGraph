import Foundation

public struct InstagramGraphResolvedAccount {
    public let facebookPageId: String
    public let facebookPageName: String?
    public let instagramBusinessAccountId: String
    public let instagramUsername: String?

    public init(
        facebookPageId: String,
        facebookPageName: String?,
        instagramBusinessAccountId: String,
        instagramUsername: String?
    ) {
        self.facebookPageId = facebookPageId
        self.facebookPageName = facebookPageName
        self.instagramBusinessAccountId = instagramBusinessAccountId
        self.instagramUsername = instagramUsername
    }
}

public final class InstagramGraphAccountResolver {
    private let apiGraphVersion: String
    private let client: any InstagramGraphClientProtocol

    public init(
        apiGraphVersion: String = ConnectedInsightsConfiguration.production.graphAPIVersion
    ) {
        self.apiGraphVersion = apiGraphVersion
        self.client = InstagramGraphClient(apiGraphVersion: apiGraphVersion)
    }

    public init(
        apiGraphVersion: String = ConnectedInsightsConfiguration.production.graphAPIVersion,
        client: any InstagramGraphClientProtocol
    ) {
        self.apiGraphVersion = apiGraphVersion
        self.client = client
    }

    public func resolveAccount(facebookToken: String) async throws -> InstagramGraphResolvedAccount {
        guard let url = meAccountsURL(facebookToken: facebookToken) else {
            throw InstagramGraphServiceError.invalidURL("/me/accounts")
        }

        let data = try await client.fetchGraphData(from: url)

        do {
            let response = try JSONDecoder().decode(InstagramGraphMeAccountsResponse.self, from: data)
            guard let page = response.data.first(where: { $0.instagramBusinessAccount != nil }),
                  let instagramAccount = page.instagramBusinessAccount
            else {
                throw InstagramGraphServiceError.instagramAccountNotFound
            }
            return InstagramGraphResolvedAccount(
                facebookPageId: page.id,
                facebookPageName: page.name,
                instagramBusinessAccountId: instagramAccount.id,
                instagramUsername: instagramAccount.username
            )
        } catch let error as InstagramGraphServiceError {
            throw error
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            throw InstagramGraphServiceError.decodingFailed(
                type: "InstagramGraphMeAccountsResponse",
                body: InstagramGraphLogRedactor.redacted(String(body.prefix(1_500)))
            )
        }
    }

    public func resolveCredentials(facebookToken: String) async throws -> InstagramGraphCredentials {
        let account = try await resolveAccount(facebookToken: facebookToken)
        return InstagramGraphCredentials(
            facebookToken: facebookToken,
            instagramBusinessAccountId: account.instagramBusinessAccountId
        )
    }

    private func meAccountsURL(facebookToken: String) -> String? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "graph.facebook.com"
        components.path = "/\(apiGraphVersion)/me/accounts"
        components.queryItems = [
            URLQueryItem(name: "fields", value: "id,name,instagram_business_account{id,username}"),
            URLQueryItem(name: "access_token", value: facebookToken),
        ]
        return components.url?.absoluteString
    }
}

private struct InstagramGraphMeAccountsResponse: Decodable {
    let data: [InstagramGraphPageAccount]
}

private struct InstagramGraphPageAccount: Decodable {
    let id: String
    let name: String?
    let instagramBusinessAccount: InstagramGraphInstagramAccount?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case instagramBusinessAccount = "instagram_business_account"
    }
}

private struct InstagramGraphInstagramAccount: Decodable {
    let id: String
    let username: String?
}
