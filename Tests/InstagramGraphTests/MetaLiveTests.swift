import XCTest
@testable import InstagramGraph

final class MetaLiveTests: XCTestCase {
    private let environment = ProcessInfo.processInfo.environment

    func testMeAccountsEndpointAgainstMeta() async throws {
        let token = try requiredEnvironmentValue("META_GRAPH_TOKEN")
        let version = graphAPIVersion
        let url = "https://graph.facebook.com/\(version)/me/accounts?fields=id,name,access_token,tasks,instagram_business_account{id,username}&access_token=\(token)"

        let data = try await InstagramGraphClient(apiGraphVersion: version).fetchGraphData(from: url)
        let response = try JSONDecoder().decode(MeAccountsResponse.self, from: data)

        XCTAssertFalse(response.data.isEmpty, "Expected /me/accounts to return at least one page.")
        response.data.forEach { page in
            print("[MetaLive] Page id=\(page.id) name=\(page.name ?? "<none>") instagram=\(page.instagramBusinessAccount?.username ?? "<none>") tasks=\(page.tasks ?? [])")
        }
    }

    func testPageInstagramBusinessAccountAgainstMeta() async throws {
        let token = try requiredEnvironmentValue("META_GRAPH_TOKEN")
        let version = graphAPIVersion
        let pageID = try await resolvePageId(token: token, version: version)
        let url = "https://graph.facebook.com/\(version)/\(pageID)?fields=instagram_business_account{id,username}&access_token=\(token)"

        let data = try await InstagramGraphClient(apiGraphVersion: version).fetchGraphData(from: url)
        let response = try JSONDecoder().decode(PageInstagramBusinessAccountResponse.self, from: data)
        let account = try XCTUnwrap(
            response.instagramBusinessAccount,
            "The selected page has no instagram_business_account field in Meta's response."
        )

        print("[MetaLive] Instagram business id=\(account.id) username=\(account.username ?? "<none>")")
    }

    func testAnalyticsProfileEndpointAgainstMeta() async throws {
        let token = try requiredEnvironmentValue("META_GRAPH_TOKEN")
        let version = graphAPIVersion
        let pageID = try await resolvePageId(token: token, version: version)
        let instagramBusinessId = try await resolveInstagramBusinessAccountId(
            token: token,
            pageID: pageID,
            version: version
        )
        let credentials = InstagramGraphCredentials(
            facebookToken: token,
            instagramBusinessAccountId: instagramBusinessId
        )
        let endpointBuilder = InstagramGraphEndpointBuilder(apiGraphVersion: version)
        let mediaLimit = environment["META_MEDIA_LIMIT"].flatMap(Int.init)
        let url = try XCTUnwrap(endpointBuilder.analyticsProfileURL(
            mediaLimit: mediaLimit,
            credentials: credentials
        ))

        let data = try await InstagramGraphClient(apiGraphVersion: version).fetchGraphData(from: url)
        XCTAssertNoThrow(try JSONDecoder.instagram().decode(Profile.self, from: data))
    }

    func testHashtagSearchAgainstMeta() async throws {
        let token = try requiredEnvironmentValue("META_GRAPH_TOKEN")
        let hashtag = testHashtag
        let version = graphAPIVersion
        let pageID = try await resolvePageId(token: token, version: version)
        let instagramBusinessId = try await resolveInstagramBusinessAccountId(
            token: token,
            pageID: pageID,
            version: version
        )
        let credentialsProvider = StaticInstagramGraphCredentialsProvider(
            facebookToken: token,
            instagramBusinessAccountId: instagramBusinessId
        )
        let endpointBuilder = InstagramGraphEndpointBuilder(apiGraphVersion: version)
        let repository = InstagramHashtagRepository(
            credentialsProvider: credentialsProvider,
            endpointBuilder: endpointBuilder,
            client: InstagramGraphClient(apiGraphVersion: version)
        )

        let media = try await repository.searchHashtag(searchedHashtag: hashtag)
        XCTAssertFalse(media.isEmpty, "Expected hashtag search to return at least one media item.")
    }

    func testExpensiveCaptionProbeAgainstMeta() async throws {
        guard environment["META_RUN_EXPENSIVE_CAPTION_PROBE"] == "1" else {
            throw XCTSkip("Set META_RUN_EXPENSIVE_CAPTION_PROBE=1 to reproduce Meta's caption page-size failure.")
        }

        let token = try requiredEnvironmentValue("META_GRAPH_TOKEN")
        let hashtag = testHashtag
        let version = graphAPIVersion
        let pageID = try await resolvePageId(token: token, version: version)
        let instagramBusinessId = try await resolveInstagramBusinessAccountId(
            token: token,
            pageID: pageID,
            version: version
        )
        let client = InstagramGraphClient(apiGraphVersion: version)
        let searchURL = "https://graph.facebook.com/\(version)/ig_hashtag_search?user_id=\(instagramBusinessId)&q=\(hashtag)&access_token=\(token)"
        let searchData = try await client.fetchGraphData(from: searchURL)
        let hashtagResponse = try JSONDecoder().decode(HashtagIdResponse.self, from: searchData)
        let hashtagID = try XCTUnwrap(hashtagResponse.data.first?.id)
        let fields = "id,caption"
        let probeURL = "https://graph.facebook.com/\(version)/\(hashtagID)/top_media?fields=\(fields)&user_id=\(instagramBusinessId)&limit=10&access_token=\(token)"

        do {
            _ = try await client.fetchGraphData(from: probeURL)
            XCTFail("Expected graphHTTPError with status 500")
        } catch let error as InstagramGraphServiceError {
            guard case .graphHTTPError(let statusCode, let body) = error else {
                XCTFail("Expected graphHTTPError, got \(error)")
                return
            }
            XCTAssertEqual(statusCode, 500)
            XCTAssertTrue(body.contains("Please reduce the amount of data"))
        }
    }

    private var graphAPIVersion: String {
        environment["META_GRAPH_VERSION"] ?? ConnectedInsightsConfiguration.production.graphAPIVersion
    }

    private var testHashtag: String {
        environment["META_TEST_HASHTAG"].flatMap { $0.isEmpty ? nil : $0 } ?? "travel"
    }

    private func requiredEnvironmentValue(_ key: String) throws -> String {
        guard let value = environment[key], !value.isEmpty else {
            throw XCTSkip("Set \(key) to run Meta live integration tests.")
        }
        return value
    }

    private func optionalEnvironmentValue(_ key: String) -> String? {
        guard let value = environment[key], !value.isEmpty else {
            return nil
        }
        return value
    }

    private func resolvePageId(token: String, version: String) async throws -> String {
        if let pageID = optionalEnvironmentValue("META_PAGE_ID") {
            return pageID
        }

        let url = "https://graph.facebook.com/\(version)/me/accounts?fields=id,name,instagram_business_account{id,username}&access_token=\(token)"
        let data = try await InstagramGraphClient(apiGraphVersion: version).fetchGraphData(from: url)
        let response = try JSONDecoder().decode(MeAccountsResponse.self, from: data)
        let page = try XCTUnwrap(
            response.data.first(where: { $0.instagramBusinessAccount != nil }),
            "No Facebook Page connected to an Instagram Business / Creator account was found. Set META_PAGE_ID to force a specific Page."
        )
        print("[MetaLive] Using Page id=\(page.id) name=\(page.name ?? "<none>") instagram=\(page.instagramBusinessAccount?.username ?? "<none>")")
        return page.id
    }

    private func resolveInstagramBusinessAccountId(
        token: String,
        pageID: String,
        version: String
    ) async throws -> String {
        let url = "https://graph.facebook.com/\(version)/\(pageID)?fields=instagram_business_account{id}&access_token=\(token)"
        let data = try await InstagramGraphClient(apiGraphVersion: version).fetchGraphData(from: url)
        let response = try JSONDecoder().decode(PageInstagramBusinessAccountResponse.self, from: data)
        return try XCTUnwrap(
            response.instagramBusinessAccount?.id,
            "The selected page has no connected Instagram Business / Creator account."
        )
    }
}

private struct MeAccountsResponse: Decodable {
    let data: [PageAccount]
}

private struct PageAccount: Decodable {
    let id: String
    let name: String?
    let accessToken: String?
    let tasks: [String]?
    let instagramBusinessAccount: InstagramBusinessAccount?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case accessToken = "access_token"
        case tasks
        case instagramBusinessAccount = "instagram_business_account"
    }
}

private struct PageInstagramBusinessAccountResponse: Decodable {
    let instagramBusinessAccount: InstagramBusinessAccount?

    private enum CodingKeys: String, CodingKey {
        case instagramBusinessAccount = "instagram_business_account"
    }
}

private struct InstagramBusinessAccount: Decodable {
    let id: String
    let username: String?
}

private struct StaticInstagramGraphCredentialsProvider: InstagramGraphCredentialsProviding {
    let facebookToken: String?
    let instagramBusinessAccountId: String?
}
