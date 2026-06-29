import XCTest
@testable import InstagramGraph

@MainActor
final class ConnectedInsightsGraphTests: XCTestCase {
    private let productionGraphAPIVersion = ConnectedInsightsConfiguration.production.graphAPIVersion

    // MARK: - Access State

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
        case .ready:
            break
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
        case .ready:
            break
        case .needsSetup(let error):
            XCTFail("Expected ready state, got setup error: \(error)")
        }
    }

    func testReset_clearsAllStoredCredentials() {
        let settings = FakeConnectedInsightsSettings(
            isCorrectSetup: true,
            facebookToken: "facebook-token",
            instagramBusinessAccountId: "ig-business-id"
        )
        let sut = makeGateway(settings: settings)

        sut.reset()

        XCTAssertNil(settings.facebookToken)
        XCTAssertNil(settings.instagramBusinessAccountId)
        XCTAssertFalse(settings.isCorrectSetup)
        assertNeedsSetup(sut.accessState(), .setupRequired)
    }

    // MARK: - Setup

    private let meAccountsResponse = """
    {
      "data": [
        {
          "id": "page-id",
          "name": "PackTags",
          "instagram_business_account": { "id": "ig-business-id", "username": "packtags" }
        }
      ]
    }
    """.data(using: .utf8)!

    /// Regression test: setup() must persist the token it was handed.
    /// Version 3.0.0 stored only the business id, so accessState() returned
    /// missingFacebookToken right after a successful login — an endless
    /// login loop in the app.
    func testSetup_onSuccess_persistsCredentialsAndBecomesReady() async throws {
        let settings = FakeConnectedInsightsSettings(isCorrectSetup: false)
        let resolver = InstagramGraphAccountResolver(
            client: FakeInstagramGraphClient(responses: [.success(meAccountsResponse)])
        )
        let sut = ConnectedInsightsGateway(
            settings: settings,
            hashtagProvider: FakeHashtagProvider(),
            profileProvider: FakeProfileProvider(),
            accountResolver: resolver
        )

        try await sut.setup(facebookToken: "fresh-token")

        XCTAssertEqual(settings.facebookToken, "fresh-token")
        XCTAssertEqual(settings.instagramBusinessAccountId, "ig-business-id")
        XCTAssertTrue(settings.isCorrectSetup)
        switch sut.accessState() {
        case .ready:
            break
        case .needsSetup(let error):
            XCTFail("Setup must leave the gateway ready without an external token provider — got \(error)")
        }
    }

    func testSetup_onResolutionFailure_marksSetupIncorrectAndThrows() async {
        let settings = FakeConnectedInsightsSettings(isCorrectSetup: true)
        let resolver = InstagramGraphAccountResolver(
            client: FakeInstagramGraphClient(responses: [.failure(InstagramGraphServiceError.instagramAccountNotFound)])
        )
        let sut = ConnectedInsightsGateway(
            settings: settings,
            hashtagProvider: FakeHashtagProvider(),
            profileProvider: FakeProfileProvider(),
            accountResolver: resolver
        )

        do {
            try await sut.setup(facebookToken: "fresh-token")
            XCTFail("Expected setup to throw")
        } catch {
            XCTAssertFalse(settings.isCorrectSetup)
        }
    }

    // MARK: - Credentials Provider

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

    func testCredentialsProvider_whenInstagramAccountIdIsMissing_reportsHasTokenTrueAndHasIdFalse() {
        let settings = FakeConnectedInsightsSettings(
            facebookToken: "facebook-token",
            instagramBusinessAccountId: nil
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
            XCTAssertTrue(hasToken)
            XCTAssertFalse(hasInstagramBusinessId)
        }
    }

    func testCredentialsProvider_whenBothCredentialsAreNil_reportsBothFalse() {
        let settings = FakeConnectedInsightsSettings(
            facebookToken: nil,
            instagramBusinessAccountId: nil
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
            XCTAssertFalse(hasInstagramBusinessId)
        }
    }

    func testCredentialsProvider_whenTokenIsEmptyString_treatsItAsMissing() {
        let settings = FakeConnectedInsightsSettings(
            facebookToken: "",
            instagramBusinessAccountId: "ig-business-id"
        )
        let sut = SettingsInstagramGraphCredentialsProvider(settings: settings)

        switch sut.validCredentials() {
        case .success:
            XCTFail("Expected missing credentials failure")
        case .failure(let error):
            guard case InstagramGraphServiceError.missingCredentials(let hasToken, _) = error else {
                XCTFail("Expected missingCredentials error, got \(error)")
                return
            }
            XCTAssertFalse(hasToken)
        }
    }

    func testCredentialsProvider_whenInstagramAccountIdIsEmptyString_treatsItAsMissing() {
        let settings = FakeConnectedInsightsSettings(
            facebookToken: "facebook-token",
            instagramBusinessAccountId: ""
        )
        let sut = SettingsInstagramGraphCredentialsProvider(settings: settings)

        switch sut.validCredentials() {
        case .success:
            XCTFail("Expected missing credentials failure")
        case .failure(let error):
            guard case InstagramGraphServiceError.missingCredentials(_, let hasInstagramBusinessId) = error else {
                XCTFail("Expected missingCredentials error, got \(error)")
                return
            }
            XCTAssertFalse(hasInstagramBusinessId)
        }
    }

    // MARK: - Account Resolver

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

    func testAccountResolver_whenNoPageHasInstagramAccount_throwsInstagramAccountNotFound() async throws {
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

    // MARK: - Gateway Setup

    func testGatewaySetup_whenAccountResolutionSucceeds_persistsTokenAndInstagramAccount() async throws {
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

        XCTAssertEqual(settings.facebookToken, "setup-token")
        XCTAssertEqual(settings.instagramBusinessAccountId, "ig-business-id")
        XCTAssertTrue(settings.isCorrectSetup)
    }

    func testGatewaySetup_whenAccountResolutionFails_doesNotPersistCredentials() async throws {
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

    // MARK: - Endpoint Builder

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

    func testEndpointBuilder_hashtagSearchURL_encodesInjectionCharactersInQuery() throws {
        let sut = InstagramGraphEndpointBuilder(apiGraphVersion: productionGraphAPIVersion)
        let credentials = InstagramGraphCredentials(
            facebookToken: "facebook-token",
            instagramBusinessAccountId: "1789"
        )

        // A hashtag carrying query-control characters must stay inside the `q` value and
        // never inject extra parameters such as access_token.
        let url = try XCTUnwrap(sut.hashtagSearchURL(
            searchedHashtag: "travel&access_token=attacker+x",
            credentials: credentials
        ))

        XCTAssertTrue(url.contains("q=travel%26access_token%3Dattacker%2Bx"))
        XCTAssertTrue(url.contains("access_token=facebook-token"))
        XCTAssertFalse(url.contains("access_token=attacker"))
    }

    func testEndpointBuilder_hashtagMediaURL_containsOnlyFieldsUsedByPackTags() throws {
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
        XCTAssertTrue(url.contains("insights.metric(reach%2Cviews%2Ctotal_interactions)"))
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

    // MARK: - Hashtag Repository

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

        let posts = try await sut.searchHashtag(searchedHashtag: "travel")

        XCTAssertEqual(client.requestedURLs.count, 2)
        XCTAssertTrue(client.requestedURLs[0].contains("ig_hashtag_search"))
        XCTAssertTrue(client.requestedURLs[1].contains("17841562498105353/top_media"))
        let firstPost = try XCTUnwrap(posts.first)
        XCTAssertEqual(firstPost.caption, "Hello")
        XCTAssertEqual(firstPost.commentsCount, 3)
        XCTAssertEqual(firstPost.likeCount, 9)
        XCTAssertEqual(firstPost.mediaType, .image)
        XCTAssertNotNil(firstPost.timestamp)
        let mediaUrl = try XCTUnwrap(firstPost.mediaUrl)
        XCTAssertEqual(mediaUrl.absoluteString, "https://example.com/image.jpg")
    }

    func testHashtagRepository_whenHashtagNotFound_returnsEmptyResultWithoutError() async throws {
        // The hashtag search decodes fine but matches nothing — that's "no results", not an
        // error, so no media lookup follows and an empty list is returned.
        let client = FakeInstagramGraphClient(responses: [
            .success(#"{"data":[]}"#.data(using: .utf8)!)
        ])
        let sut = InstagramHashtagRepository(
            credentialsProvider: FakeInstagramGraphCredentialsProvider(
                facebookToken: "facebook-token",
                instagramBusinessAccountId: "ig-business-id"
            ),
            endpointBuilder: InstagramGraphEndpointBuilder(apiGraphVersion: productionGraphAPIVersion),
            client: client
        )

        let posts = try await sut.searchHashtag(searchedHashtag: "nonexistenthashtag")

        XCTAssertTrue(posts.isEmpty)
        XCTAssertEqual(client.requestedURLs.count, 1)
        XCTAssertTrue(client.requestedURLs[0].contains("ig_hashtag_search"))
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

    func testHashtagRepository_whenClientThrowsNetworkError_propagatesNetworkError() async throws {
        let client = FakeInstagramGraphClient(responses: [
            .failure(InstagramGraphServiceError.networkError(URLError(.notConnectedToInternet)))
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
            XCTFail("Expected networkError")
        } catch let error as InstagramGraphServiceError {
            guard case .networkError = error else {
                XCTFail("Expected networkError, got \(error)")
                return
            }
        }
    }

    func testHashtagRepository_whenClientReturnsEmptyResponse_propagatesEmptyResponseError() async throws {
        let client = FakeInstagramGraphClient(responses: [
            .failure(InstagramGraphServiceError.emptyResponse)
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
            XCTFail("Expected emptyResponse error")
        } catch let error as InstagramGraphServiceError {
            guard case .emptyResponse = error else {
                XCTFail("Expected emptyResponse, got \(error)")
                return
            }
        }
    }

    // MARK: - Profile Repository

    func testProfileRepository_whenProfileDataIsValid_returnsDecodedProfile() async throws {
        let response = """
        {
          "id": "1789",
          "username": "packtags.app",
          "followers_count": 1500,
          "follows_count": 200,
          "media_count": 85,
          "biography": "Organize your life",
          "media": {
            "data": [
              {
                "media_type": "IMAGE",
                "caption": "Hello world",
                "timestamp": "2026-06-07T08:00:00+0000",
                "like_count": 42,
                "comments_count": 5
              }
            ]
          }
        }
        """.data(using: .utf8)!
        let client = FakeInstagramGraphClient(responses: [.success(response)])
        let sut = InstagramProfileRepository(
            credentialsProvider: FakeInstagramGraphCredentialsProvider(
                facebookToken: "facebook-token",
                instagramBusinessAccountId: "1789"
            ),
            endpointBuilder: InstagramGraphEndpointBuilder(apiGraphVersion: productionGraphAPIVersion),
            client: client
        )

        let profile = try await sut.loadProfileForAnalytics(mediaLimit: nil)

        XCTAssertEqual(profile.username, "packtags.app")
        XCTAssertEqual(profile.followersCount, 1500)
        XCTAssertEqual(profile.followsCount, 200)
        XCTAssertEqual(profile.biography, "Organize your life")
        let firstPost = try XCTUnwrap(profile.media?.data.first)
        XCTAssertEqual(firstPost.mediaType, .image)
        XCTAssertEqual(firstPost.caption, "Hello world")
        XCTAssertEqual(firstPost.likeCount, 42)
        XCTAssertEqual(firstPost.commentsCount, 5)
        XCTAssertNotNil(firstPost.timestamp)
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
            client: client
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

    // MARK: - Keychain Settings

    func testKeychainSettings_storesCredentialsInKeychainNotUserDefaults() {
        let defaults = makeEphemeralDefaults()
        let keychain = FakeKeychainStore()
        let sut = KeychainConnectedInsightsSettings(defaults: defaults, keychain: keychain)

        sut.facebookToken = "secret-token"
        sut.instagramBusinessAccountId = "ig-business-id"
        sut.isCorrectSetup = true

        XCTAssertEqual(sut.facebookToken, "secret-token")
        XCTAssertEqual(sut.instagramBusinessAccountId, "ig-business-id")
        XCTAssertTrue(sut.isCorrectSetup)
        // The sensitive values live in the Keychain, never in UserDefaults.
        XCTAssertEqual(keychain.string(forKey: "fbToken"), "secret-token")
        XCTAssertNil(defaults.string(forKey: "fbToken"))
        XCTAssertNil(defaults.string(forKey: "IgBId"))
    }

    func testKeychainSettings_settingNilDeletesKeychainValue() {
        let keychain = FakeKeychainStore()
        let sut = KeychainConnectedInsightsSettings(defaults: makeEphemeralDefaults(), keychain: keychain)
        sut.facebookToken = "secret-token"

        sut.facebookToken = nil

        XCTAssertNil(sut.facebookToken)
        XCTAssertNil(keychain.string(forKey: "fbToken"))
    }

    func testKeychainSettings_migratesLegacyUserDefaultsCredentialsIntoKeychain() {
        let defaults = makeEphemeralDefaults()
        defaults.set("legacy-token", forKey: "fbToken")
        defaults.set("legacy-ig-id", forKey: "IgBId")
        let keychain = FakeKeychainStore()

        let sut = KeychainConnectedInsightsSettings(defaults: defaults, keychain: keychain)

        XCTAssertEqual(sut.facebookToken, "legacy-token")
        XCTAssertEqual(sut.instagramBusinessAccountId, "legacy-ig-id")
        // The plaintext copies are removed once migrated.
        XCTAssertNil(defaults.string(forKey: "fbToken"))
        XCTAssertNil(defaults.string(forKey: "IgBId"))
    }

    func testKeychainSettings_migrationKeepsPlaintextWhenKeychainWriteFails() {
        // A failed Keychain write must not destroy the only copy of the credential: the
        // plaintext stays in UserDefaults so migration can be retried on the next launch.
        let defaults = makeEphemeralDefaults()
        defaults.set("legacy-token", forKey: "fbToken")
        let keychain = FakeKeychainStore(failWrites: true)

        let sut = KeychainConnectedInsightsSettings(defaults: defaults, keychain: keychain)

        XCTAssertEqual(defaults.string(forKey: "fbToken"), "legacy-token")
        XCTAssertNil(sut.facebookToken)
    }

    func testKeychainSettings_migrationDoesNotOverwriteExistingKeychainValue() {
        let defaults = makeEphemeralDefaults()
        defaults.set("legacy-token", forKey: "fbToken")
        let keychain = FakeKeychainStore()
        keychain.set("current-token", forKey: "fbToken")

        let sut = KeychainConnectedInsightsSettings(defaults: defaults, keychain: keychain)

        XCTAssertEqual(sut.facebookToken, "current-token")
        XCTAssertNil(defaults.string(forKey: "fbToken"))
    }

    private func makeEphemeralDefaults() -> UserDefaults {
        let suiteName = "KeychainSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - Helpers

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

private final class FakeConnectedInsightsSettings: ConnectedInsightsSettingsProtocol, @unchecked Sendable {
    var isCorrectSetup: Bool
    var facebookToken: String?
    var instagramBusinessAccountId: String?

    init(
        isCorrectSetup: Bool = false,
        facebookToken: String? = nil,
        instagramBusinessAccountId: String? = nil
    ) {
        self.isCorrectSetup = isCorrectSetup
        self.facebookToken = facebookToken
        self.instagramBusinessAccountId = instagramBusinessAccountId
    }
}

private struct FakeInstagramGraphCredentialsProvider: InstagramGraphCredentialsProviding {
    let facebookToken: String?
    let instagramBusinessAccountId: String?
}

private struct FakeAccessTokenProvider: InstagramGraphAccessTokenProviding {
    let facebookToken: String?
}

private final class FakeKeychainStore: KeychainStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String] = [:]
    private let failWrites: Bool

    init(failWrites: Bool = false) {
        self.failWrites = failWrites
    }

    func string(forKey key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }

    @discardableResult
    func set(_ value: String?, forKey key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if failWrites { return false }
        storage[key] = value
        return true
    }
}

private final class FakeInstagramGraphClient: InstagramGraphClientProtocol, @unchecked Sendable {
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
    func searchHashtag(searchedHashtag: String) async throws -> [InstagramPost] {
        return []
    }
}

private struct FakeProfileProvider: ProfileDataProviding {
    func loadProfileForAnalytics(mediaLimit: Int?) async throws -> Profile {
        throw InstagramGraphServiceError.emptyResponse
    }
}
