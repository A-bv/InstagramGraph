import XCTest
@testable import InstagramGraph

final class ConnectedInsightsGraphTests: XCTestCase {
    private let productionGraphAPIVersion = ConnectedInsightsConfiguration.production.graphAPIVersion

    func testAccessState_whenSetupIsMissing_requiresSetup() {
        let sut = makeGateway(settings: FakeConnectedInsightsSettings(isCorrectSetup: false))

        assertNeedsSetup(sut.accessState(), .setupRequired)
    }

    func testAccessState_whenFacebookTokenIsMissing_requiresToken() {
        let settings = FakeConnectedInsightsSettings(
            isCorrectSetup: true,
            facebookToken: nil,
            instagramBusinessAccountId: "ig-business-id"
        )
        let sut = makeGateway(settings: settings)

        assertNeedsSetup(sut.accessState(), .missingFacebookToken)
    }

    func testAccessState_whenTokenProviderHasToken_isReadyWithoutStoredToken() {
        let settings = FakeConnectedInsightsSettings(
            isCorrectSetup: true,
            facebookToken: nil,
            instagramBusinessAccountId: "ig-business-id"
        )
        let sut = makeGateway(
            settings: settings,
            tokenProvider: FakeAccessTokenProvider(facebookToken: "provider-token")
        )

        switch sut.accessState() {
        case .ready(let session):
            XCTAssertEqual(session.facebookToken, "provider-token")
            XCTAssertEqual(session.instagramBusinessAccountId, "ig-business-id")
        case .needsSetup(let error):
            XCTFail("Expected ready state, got setup error: \(error)")
        }
    }

    func testAccessState_whenInstagramBusinessIdIsMissing_requiresInstagramBusinessId() {
        let settings = FakeConnectedInsightsSettings(
            isCorrectSetup: true,
            facebookToken: "facebook-token",
            instagramBusinessAccountId: nil
        )
        let sut = makeGateway(settings: settings)

        assertNeedsSetup(sut.accessState(), .missingInstagramBusinessAccountId)
    }

    func testAccessState_whenCredentialsAreComplete_isReady() {
        let settings = FakeConnectedInsightsSettings(
            isCorrectSetup: true,
            facebookToken: "facebook-token",
            instagramBusinessAccountId: "ig-business-id"
        )
        let sut = makeGateway(settings: settings)

        switch sut.accessState() {
        case .ready(let session):
            XCTAssertEqual(session.facebookToken, "facebook-token")
            XCTAssertEqual(session.instagramBusinessAccountId, "ig-business-id")
        case .needsSetup(let error):
            XCTFail("Expected ready state, got setup error: \(error)")
        }
    }

    func testCredentialsProvider_whenCredentialsExist_returnsValidCredentials() throws {
        let settings = FakeConnectedInsightsSettings(
            facebookToken: "facebook-token",
            instagramBusinessAccountId: "ig-business-id"
        )
        let sut = SettingsInstagramGraphCredentialsProvider(settings: settings)

        let credentials = try sut.validCredentials().get()

        XCTAssertEqual(credentials.facebookToken, "facebook-token")
        XCTAssertEqual(credentials.instagramBusinessAccountId, "ig-business-id")
    }

    func testCredentialsProvider_whenTokenProviderHasToken_doesNotRequireStoredToken() throws {
        let settings = FakeConnectedInsightsSettings(
            facebookToken: nil,
            instagramBusinessAccountId: "ig-business-id"
        )
        let sut = SettingsInstagramGraphCredentialsProvider(
            settings: settings,
            tokenProvider: FakeAccessTokenProvider(facebookToken: "provider-token")
        )

        let credentials = try sut.validCredentials().get()

        XCTAssertEqual(credentials.facebookToken, "provider-token")
        XCTAssertEqual(credentials.instagramBusinessAccountId, "ig-business-id")
    }

    func testCredentialsProvider_whenCredentialsAreMissing_returnsGraphCredentialError() {
        let settings = FakeConnectedInsightsSettings(
            facebookToken: nil,
            instagramBusinessAccountId: "ig-business-id"
        )
        let sut = SettingsInstagramGraphCredentialsProvider(settings: settings)

        switch sut.validCredentials() {
        case .success:
            XCTFail("Expected missing credentials failure")
        case .failure(let error):
            guard case InstagramGraphServiceError.missingCredentials(let hasToken, let hasInstagramBusinessId) = error else {
                XCTFail("Expected missingCredentials error, got \(error)")
                return
            }
            XCTAssertFalse(hasToken)
            XCTAssertTrue(hasInstagramBusinessId)
        }
    }

    func testAccountResolver_resolvesFirstPageWithInstagramAccount() async throws {
        let response = """
        {
          "data": [
            { "id": "page-without-instagram", "name": "No Instagram" },
            {
              "id": "page-id",
              "name": "PackTags",
              "instagram_business_account": {
                "id": "ig-business-id",
                "username": "packtags"
              }
            }
          ]
        }
        """.data(using: .utf8)!
        let client = FakeInstagramGraphClient(responses: [.success(response)])
        let sut = InstagramGraphAccountResolver(apiGraphVersion: productionGraphAPIVersion, client: client)

        let account = try await sut.resolveAccount(facebookToken: "facebook-token")

        XCTAssertEqual(account.facebookPageId, "page-id")
        XCTAssertEqual(account.facebookPageName, "PackTags")
        XCTAssertEqual(account.instagramBusinessAccountId, "ig-business-id")
        XCTAssertEqual(account.instagramUsername, "packtags")
        XCTAssertEqual(client.requestedURLs.count, 1)
        XCTAssertTrue(client.requestedURLs[0].contains("/\(productionGraphAPIVersion)/me/accounts"))
        XCTAssertTrue(client.requestedURLs[0].contains("access_token=facebook-token"))
    }

    func testAccountResolver_resolveCredentialsBuildsServiceCredentials() async throws {
        let response = """
        {
          "data": [
            {
              "id": "page-id",
              "instagram_business_account": {
                "id": "ig-business-id"
              }
            }
          ]
        }
        """.data(using: .utf8)!
        let client = FakeInstagramGraphClient(responses: [.success(response)])
        let sut = InstagramGraphAccountResolver(apiGraphVersion: productionGraphAPIVersion, client: client)

        let credentials = try await sut.resolveCredentials(facebookToken: "facebook-token")

        XCTAssertEqual(credentials.facebookToken, "facebook-token")
        XCTAssertEqual(credentials.instagramBusinessAccountId, "ig-business-id")
    }

    func testAccountResolver_whenNoPageHasInstagramAccountReturnsMissingCredentials() async throws {
        let response = """
        {
          "data": [
            { "id": "page-id", "name": "No Instagram" }
          ]
        }
        """.data(using: .utf8)!
        let client = FakeInstagramGraphClient(responses: [.success(response)])
        let sut = InstagramGraphAccountResolver(apiGraphVersion: productionGraphAPIVersion, client: client)

        do {
            _ = try await sut.resolveAccount(facebookToken: "facebook-token")
            XCTFail("Expected instagramAccountNotFound error")
        } catch let error as InstagramGraphServiceError {
            guard case .instagramAccountNotFound = error else {
                XCTFail("Expected instagramAccountNotFound error, got \(error)")
                return
            }
        }
    }

    func testGatewaySetup_whenAccountResolutionSucceedsStoresOnlyInstagramAccount() async throws {
        let response = """
        {
          "data": [
            {
              "id": "page-id",
              "instagram_business_account": {
                "id": "ig-business-id"
              }
            }
          ]
        }
        """.data(using: .utf8)!
        let settings = FakeConnectedInsightsSettings()
        let client = FakeInstagramGraphClient(responses: [.success(response)])
        let sut = ConnectedInsightsGateway(
            settings: settings,
            tokenProvider: FakeAccessTokenProvider(facebookToken: "provider-token"),
            hashtagProvider: FakeHashtagProvider(),
            profileProvider: FakeProfileProvider(),
            accountResolver: InstagramGraphAccountResolver(apiGraphVersion: productionGraphAPIVersion, client: client)
        )

        try await sut.setup(facebookToken: "setup-token")

        XCTAssertNil(settings.facebookToken)
        XCTAssertEqual(settings.instagramBusinessAccountId, "ig-business-id")
        XCTAssertTrue(settings.isCorrectSetup)
    }

    func testGatewaySetup_whenAccountResolutionFailsReturnsError() async throws {
        let settings = FakeConnectedInsightsSettings()
        let client = FakeInstagramGraphClient(responses: [.failure(InstagramGraphServiceError.instagramAccountNotFound)])
        let sut = ConnectedInsightsGateway(
            settings: settings,
            tokenProvider: FakeAccessTokenProvider(facebookToken: "provider-token"),
            hashtagProvider: FakeHashtagProvider(),
            profileProvider: FakeProfileProvider(),
            accountResolver: InstagramGraphAccountResolver(apiGraphVersion: productionGraphAPIVersion, client: client)
        )

        do {
            try await sut.setup(facebookToken: "setup-token")
            XCTFail("Expected instagramAccountNotFound error")
        } catch let error as InstagramGraphServiceError {
            guard case .instagramAccountNotFound = error else {
                XCTFail("Expected instagramAccountNotFound, got \(error)")
                return
            }
        }

        XCTAssertNil(settings.facebookToken)
        XCTAssertNil(settings.instagramBusinessAccountId)
        XCTAssertFalse(settings.isCorrectSetup)
    }

    func testEndpointBuilder_buildsEncodedHashtagSearchURL() throws {
        let sut = InstagramGraphEndpointBuilder(apiGraphVersion: productionGraphAPIVersion)
        let credentials = InstagramGraphCredentials(
            facebookToken: "token value",
            instagramBusinessAccountId: "1789"
        )

        let url = try XCTUnwrap(sut.hashtagSearchURL(
            searchedHashtag: "summer tag",
            credentials: credentials
        ))

        XCTAssertTrue(url.contains("https://graph.facebook.com/\(productionGraphAPIVersion)/ig_hashtag_search"))
        XCTAssertTrue(url.contains("user_id=1789"))
        XCTAssertTrue(url.contains("q=summer%20tag"))
        XCTAssertTrue(url.contains("access_token=token%20value"))
    }

    func testEndpointBuilder_hashtagMediaURL_containsOnlyFieldsUsedBySmartG() throws {
        let sut = InstagramGraphEndpointBuilder(apiGraphVersion: productionGraphAPIVersion)
        let credentials = InstagramGraphCredentials(
            facebookToken: "facebook-token",
            instagramBusinessAccountId: "1789"
        )

        let url = try XCTUnwrap(sut.hashtagMediaSearchURL(
            hashtagID: "17843819167049166",
            credentials: credentials
        ))

        XCTAssertTrue(url.contains("17843819167049166/top_media"))
        XCTAssertTrue(url.contains("caption"))
        XCTAssertTrue(url.contains("comments_count"))
        XCTAssertTrue(url.contains("like_count"))
        XCTAssertTrue(url.contains("media_type"))
        XCTAssertTrue(url.contains("media_url"))
        XCTAssertTrue(url.contains("timestamp"))
        XCTAssertTrue(url.contains("user_id=1789"))
        // Meta can return "Please reduce the amount of data" for top_media when
        // caption is requested with larger page sizes on high-volume hashtags.
        XCTAssertTrue(url.contains("limit=5"))
        // media_product_type is not a valid top_media field in the production Graph API version.
        XCTAssertFalse(url.contains("media_product_type"))
    }

    func testEndpointBuilder_analyticsProfileURL_containsOnlyFieldsUsedByPackTags() throws {
        let sut = InstagramGraphEndpointBuilder(apiGraphVersion: productionGraphAPIVersion)
        let credentials = InstagramGraphCredentials(
            facebookToken: "facebook-token",
            instagramBusinessAccountId: "1789"
        )

        let url = try XCTUnwrap(sut.analyticsProfileURL(
            mediaLimit: 7,
            credentials: credentials
        ))

        XCTAssertTrue(url.contains("https://graph.facebook.com/\(productionGraphAPIVersion)/1789?fields="))
        XCTAssertTrue(url.contains("media.limit(7)"))
        XCTAssertTrue(url.contains("access_token=facebook-token"))
        XCTAssertFalse(url.contains("checkType=FULL"))
        XCTAssertFalse(url.contains("profile_views"))
        XCTAssertFalse(url.contains("insights.metric(reach%2Cprofile_views"))
        XCTAssertFalse(url.contains("insights.metric(reach%2Cfollower_count"))
        // media_product_type is not a valid field on any endpoint
        XCTAssertFalse(url.contains("media_product_type"))
    }

    func testEndpointBuilder_analyticsProfileURL_whenMediaLimitIsNil_usesDefaultMediaEdge() throws {
        let sut = InstagramGraphEndpointBuilder(apiGraphVersion: productionGraphAPIVersion)
        let credentials = InstagramGraphCredentials(
            facebookToken: "facebook-token",
            instagramBusinessAccountId: "1789"
        )

        let url = try XCTUnwrap(sut.analyticsProfileURL(
            mediaLimit: nil,
            credentials: credentials
        ))

        XCTAssertTrue(url.contains("media%7B"))
        XCTAssertFalse(url.contains("media.limit("))
        XCTAssertTrue(url.contains("caption"))
        XCTAssertTrue(url.contains("insights.metric(reach%2Cimpressions%2Ctotal_interactions)"))
    }

    func testEndpointBuilder_businessDiscoveryURL_buildsValidMediaLimitSyntax() throws {
        let sut = InstagramGraphEndpointBuilder(apiGraphVersion: productionGraphAPIVersion)
        let credentials = InstagramGraphCredentials(
            facebookToken: "facebook-token",
            instagramBusinessAccountId: "1789"
        )

        let url = try XCTUnwrap(sut.businessDiscoveryURL(
            account: "packtags.app",
            credentials: credentials
        ))

        XCTAssertTrue(url.contains("business_discovery.username(packtags.app)"))
        XCTAssertTrue(url.contains("media.limit(12)"))
        XCTAssertFalse(url.contains("media.limit(12%7B"))
    }

    func testHashtagRepository_whenCredentialsAreMissing_doesNotCallGraphClient() async throws {
        let client = FakeInstagramGraphClient()
        let sut = InstagramHashtagRepository(
            credentialsProvider: FakeInstagramGraphCredentialsProvider(
                facebookToken: nil,
                instagramBusinessAccountId: "ig-business-id"
            ),
            endpointBuilder: InstagramGraphEndpointBuilder(apiGraphVersion: productionGraphAPIVersion),
            client: client
        )

        do {
            _ = try await sut.searchHashtag(searchedHashtag: "travel")
            XCTFail("Expected missing credentials failure")
        } catch let error as InstagramGraphServiceError {
            guard case .missingCredentials(let hasToken, let hasInstagramBusinessId) = error else {
                XCTFail("Expected missingCredentials error, got \(error)")
                return
            }
            XCTAssertFalse(hasToken)
            XCTAssertTrue(hasInstagramBusinessId)
        }

        XCTAssertTrue(client.requestedURLs.isEmpty)
    }

    func testHashtagRepository_fetchesHashtagMediaWithGraphClient() async throws {
        let client = FakeInstagramGraphClient(responses: [
            .success(#"{"data":[{"id":"17841562498105353"}]}"#.data(using: .utf8)!),
            .success(#"{"data":[{"media_type":"IMAGE","caption":"Hello","timestamp":"2026-06-07T08:00:00+0000","media_url":"https://example.com/image.jpg","comments_count":3,"like_count":9}]}"#.data(using: .utf8)!)
        ])
        let sut = InstagramHashtagRepository(
            credentialsProvider: FakeInstagramGraphCredentialsProvider(
                facebookToken: "facebook-token",
                instagramBusinessAccountId: "ig-business-id"
            ),
            endpointBuilder: InstagramGraphEndpointBuilder(apiGraphVersion: productionGraphAPIVersion),
            client: client
        )

        let loadedMedia = try await sut.searchHashtag(searchedHashtag: "travel")

        XCTAssertEqual(client.requestedURLs.count, 2)
        XCTAssertTrue(client.requestedURLs[0].contains("ig_hashtag_search"))
        XCTAssertTrue(client.requestedURLs[1].contains("17841562498105353/top_media"))
        let firstMedia = try XCTUnwrap(loadedMedia.first)
        XCTAssertEqual(firstMedia.caption, "Hello")
        XCTAssertEqual(firstMedia.commentsCount, 3)
        XCTAssertEqual(firstMedia.likeCount, 9)
    }

    func testHashtagRepository_whenTopMediaReturns500_propagatesError() async throws {
        let reduceDataError: Result<Data, Error> = .failure(InstagramGraphServiceError.graphHTTPError(
            statusCode: 500,
            body: #"{"error":{"code":1,"message":"Please reduce the amount of data you're asking for, then retry your request"}}"#
        ))
        let client = FakeInstagramGraphClient(responses: [
            .success(#"{"data":[{"id":"17843819167049166"}]}"#.data(using: .utf8)!),
            reduceDataError
        ])
        let sut = InstagramHashtagRepository(
            credentialsProvider: FakeInstagramGraphCredentialsProvider(
                facebookToken: "facebook-token",
                instagramBusinessAccountId: "ig-business-id"
            ),
            endpointBuilder: InstagramGraphEndpointBuilder(apiGraphVersion: productionGraphAPIVersion),
            client: client
        )

        do {
            _ = try await sut.searchHashtag(searchedHashtag: "travel")
            XCTFail("Expected graphHTTPError")
        } catch let error as InstagramGraphServiceError {
            guard case .graphHTTPError(let statusCode, _) = error else {
                XCTFail("Expected graphHTTPError, got \(error)")
                return
            }
            XCTAssertEqual(statusCode, 500)
        }
    }

    func testProfileRepository_whenInsightsMetricInvalid_propagates400Error() async throws {
        let invalidMetricBody = #"{"error":{"message":"(#100) metric[1] must be one of the following values: reach, follower_count, ...","type":"OAuthException","code":100}}"#
        let failure: Result<Data, Error> = .failure(InstagramGraphServiceError.graphHTTPError(statusCode: 400, body: invalidMetricBody))
        let client = FakeInstagramGraphClient(responses: [failure])
        let sut = InstagramProfileRepository(
            credentialsProvider: FakeInstagramGraphCredentialsProvider(
                facebookToken: "facebook-token",
                instagramBusinessAccountId: "ig-business-id"
            ),
            endpointBuilder: InstagramGraphEndpointBuilder(apiGraphVersion: productionGraphAPIVersion),
            client: client,
            onDataFetched: { _ in }
        )

        do {
            _ = try await sut.loadProfileForAnalytics(mediaLimit: nil)
            XCTFail("Expected graphHTTPError")
        } catch let error as InstagramGraphServiceError {
            guard case .graphHTTPError(let statusCode, _) = error else {
                XCTFail("Expected graphHTTPError, got \(error)")
                return
            }
            XCTAssertEqual(statusCode, 400)
        }
    }

    func testUnavailableProvidersReturnUnavailableError() async throws {
        do {
            _ = try await UnavailableHashtagProvider().searchHashtag(searchedHashtag: "travel")
            XCTFail("Expected unavailable provider failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, ConnectedInsightsError.dataProviderUnavailable.localizedDescription)
        }

        do {
            _ = try await UnavailableProfileProvider().loadProfileForAnalytics(mediaLimit: nil)
            XCTFail("Expected unavailable provider failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, ConnectedInsightsError.dataProviderUnavailable.localizedDescription)
        }
    }

    private func makeGateway(
        settings: FakeConnectedInsightsSettings,
        tokenProvider: (any InstagramGraphAccessTokenProviding)? = nil
    ) -> ConnectedInsightsGateway {
        ConnectedInsightsGateway(
            settings: settings,
            tokenProvider: tokenProvider,
            hashtagProvider: FakeHashtagProvider(),
            profileProvider: FakeProfileProvider()
        )
    }

    private func assertNeedsSetup(
        _ state: ConnectedInsightsAccessState,
        _ expectedError: ConnectedInsightsError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch state {
        case .ready:
            XCTFail("Expected needsSetup state", file: file, line: line)
        case .needsSetup(let error):
            XCTAssertEqual(error.errorDescription, expectedError.errorDescription, file: file, line: line)
        }
    }
}

private final class FakeConnectedInsightsSettings: ConnectedInsightsSettingsProtocol {
    var isCorrectSetup: Bool
    var facebookToken: String?
    var instagramBusinessAccountId: String?
    var setupInfoShown: Bool
    var pressedFacebookLoginButton: Bool

    init(
        isCorrectSetup: Bool = false,
        facebookToken: String? = nil,
        instagramBusinessAccountId: String? = nil,
        setupInfoShown: Bool = false,
        pressedFacebookLoginButton: Bool = false
    ) {
        self.isCorrectSetup = isCorrectSetup
        self.facebookToken = facebookToken
        self.instagramBusinessAccountId = instagramBusinessAccountId
        self.setupInfoShown = setupInfoShown
        self.pressedFacebookLoginButton = pressedFacebookLoginButton
    }
}

private struct FakeInstagramGraphCredentialsProvider: InstagramGraphCredentialsProviding {
    let facebookToken: String?
    let instagramBusinessAccountId: String?
}

private struct FakeAccessTokenProvider: InstagramGraphAccessTokenProviding {
    let facebookToken: String?
}

private final class FakeInstagramGraphClient: InstagramGraphClientProtocol {
    private var responses: [Result<Data, Error>]
    private(set) var requestedURLs: [String] = []

    init(responses: [Result<Data, Error>] = []) {
        self.responses = responses
    }

    func fetchGraphData(from urlString: String) async throws -> Data {
        requestedURLs.append(urlString)
        guard !responses.isEmpty else {
            throw InstagramGraphServiceError.emptyResponse
        }
        return try responses.removeFirst().get()
    }
}

private struct FakeHashtagProvider: HashtagSearchProviding {
    func searchHashtag(searchedHashtag: String) async throws -> [DataMedia] {
        return []
    }
}

private struct FakeProfileProvider: ProfileDataProviding {
    func loadProfileForAnalytics(mediaLimit: Int?) async throws -> Profile {
        throw ConnectedInsightsError.dataProviderUnavailable
    }
}
