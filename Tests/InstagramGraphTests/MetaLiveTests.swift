import XCTest
@testable import InstagramGraph

final class MetaLiveTests: XCTestCase {
    private let environment = ProcessInfo.processInfo.environment

    func testMeAccountsEndpointAgainstMeta() throws {
        let token = try requiredEnvironmentValue("META_GRAPH_TOKEN")
        let version = graphAPIVersion
        let url = "https://graph.facebook.com/\(version)/me/accounts?fields=id,name,access_token,tasks&access_token=\(token)"

        let data = try fetchGraphData(from: url, version: version)
        let response = try JSONDecoder().decode(MeAccountsResponse.self, from: data)

        XCTAssertFalse(response.data.isEmpty, "Expected /me/accounts to return at least one page.")
        response.data.forEach { page in
            print("[MetaLive] Page id=\(page.id) name=\(page.name ?? "<none>") tasks=\(page.tasks ?? [])")
        }
    }

    func testPageInstagramBusinessAccountAgainstMeta() throws {
        let token = try requiredEnvironmentValue("META_GRAPH_TOKEN")
        let pageID = try requiredEnvironmentValue("META_PAGE_ID")
        let version = graphAPIVersion
        let url = "https://graph.facebook.com/\(version)/\(pageID)?fields=instagram_business_account{id,username}&access_token=\(token)"

        let data = try fetchGraphData(from: url, version: version)
        let response = try JSONDecoder().decode(PageInstagramBusinessAccountResponse.self, from: data)
        let account = try XCTUnwrap(
            response.instagramBusinessAccount,
            "The selected page has no instagram_business_account field in Meta's response."
        )

        print("[MetaLive] Instagram business id=\(account.id) username=\(account.username ?? "<none>")")
    }

    func testAnalyticsProfileEndpointAgainstMeta() throws {
        let token = try requiredEnvironmentValue("META_GRAPH_TOKEN")
        let instagramBusinessId = try requiredEnvironmentValue("META_IG_BUSINESS_ID")
        let version = graphAPIVersion
        let credentials = InstagramGraphCredentials(
            facebookToken: token,
            instagramBusinessAccountId: instagramBusinessId
        )
        let endpointBuilder = InstagramGraphEndpointBuilder(apiGraphVersion: version)
        let mediaLimit = Int(environment["META_MEDIA_LIMIT"] ?? "") ?? 1
        let url = try XCTUnwrap(endpointBuilder.analyticsProfileURL(
            mediaLimit: mediaLimit,
            credentials: credentials
        ))

        let data = try fetchGraphData(from: url, version: version)
        XCTAssertNoThrow(try JSONDecoder().decode(Profile.self, from: data))
    }

    func testHashtagSearchAgainstMeta() throws {
        let token = try requiredEnvironmentValue("META_GRAPH_TOKEN")
        let instagramBusinessId = try requiredEnvironmentValue("META_IG_BUSINESS_ID")
        let hashtag = try requiredEnvironmentValue("META_TEST_HASHTAG")
        let version = graphAPIVersion
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
        let expectation = expectation(description: "Fetch hashtag media")
        var receivedResult: Result<[DataMedia], Error>?

        repository.searchHashtag(searchedHashtag: hashtag) { result in
            receivedResult = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 45)
        let media = try XCTUnwrap(receivedResult).get()
        XCTAssertFalse(media.isEmpty, "Expected hashtag search to return at least one media item.")
    }

    private var graphAPIVersion: String {
        environment["META_GRAPH_VERSION"] ?? ConnectedInsightsConfiguration.production.graphAPIVersion
    }

    private func requiredEnvironmentValue(_ key: String) throws -> String {
        guard let value = environment[key], !value.isEmpty else {
            throw XCTSkip("Set \(key) to run Meta live integration tests.")
        }
        return value
    }

    private func fetchGraphData(from url: String, version: String) throws -> Data {
        let client = InstagramGraphClient(apiGraphVersion: version)
        let expectation = expectation(description: "Fetch Graph data")
        var receivedResult: Result<Data, Error>?

        client.fetchGraphData(from: url) { result in
            receivedResult = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30)
        return try XCTUnwrap(receivedResult).get()
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

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case accessToken = "access_token"
        case tasks
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
