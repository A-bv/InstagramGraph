import Foundation

struct InstagramGraphEndpointBuilder: Sendable {
    private let apiGraphVersion: String
    private let host = "graph.facebook.com"

    init(apiGraphVersion: String = ConnectedInsightsConfiguration.production.graphAPIVersion) {
        self.apiGraphVersion = apiGraphVersion
    }

    func hashtagSearchURL(
        searchedHashtag: String,
        credentials: InstagramGraphCredentials
    ) -> String? {
        url(path: "ig_hashtag_search", queryItems: [
            ("user_id", value(credentials.instagramBusinessAccountId)),
            ("q", value(searchedHashtag)),
            ("access_token", value(credentials.facebookToken)),
        ])
    }

    func hashtagMediaSearchURL(
        hashtagID: String,
        credentials: InstagramGraphCredentials
    ) -> String? {
        let limit = "5"
        let fields = [
            "caption",
            "comments_count",
            "like_count",
            "media_type",
            "media_url",
            "timestamp",
            "id"
        ].joined(separator: ",")

        return url(path: "\(hashtagID)/top_media", queryItems: [
            ("fields", fieldsValue(fields)),
            ("user_id", value(credentials.instagramBusinessAccountId)),
            ("limit", value(limit)),
            ("access_token", value(credentials.facebookToken)),
        ])
    }

    func analyticsProfileURL(
        mediaLimit: Int?,
        credentials: InstagramGraphCredentials
    ) -> String? {
        let mediaMetricsFields = [
            "media_type",
            "caption",
            "timestamp",
            "media_url",
            "comments_count",
            "comments",
            "is_comment_enabled",
            "username",
            "like_count",
            "insights.metric(reach,views,total_interactions)"
        ]
        let mediaField: String
        if let mediaLimit {
            mediaField = "media.limit(\(mediaLimit)){\(mediaMetricsFields.joined(separator: ","))}"
        } else {
            mediaField = "media{\(mediaMetricsFields.joined(separator: ","))}"
        }

        let fields = [
            "biography",
            "name",
            "followers_count",
            "follows_count",
            "id",
            "ig_id",
            "media_count",
            "profile_picture_url",
            "username",
            "website",
            mediaField
        ].joined(separator: ",")

        return url(path: credentials.instagramBusinessAccountId, queryItems: [
            ("fields", fieldsValue(fields)),
            ("access_token", value(credentials.facebookToken)),
        ])
    }

    // Staged for the `businessDiscovery` feature on `ConnectedInsightsGatewayProtocol`; not yet
    // wired into a public call. `account` is interpolated into the `fields` expression, so it must
    // be validated by the caller before this is exposed.
    func businessDiscoveryURL(
        account: String,
        credentials: InstagramGraphCredentials
    ) -> String? {
        let limit = 12
        let fields = "business_discovery.username(\(account)){biography,name,followers_count,follows_count,id,ig_id,media_count,profile_picture_url,username,website,media.limit(\(limit)){media_type,caption,timestamp,media_url,comments_count,username,like_count}}"
        return url(path: credentials.instagramBusinessAccountId, queryItems: [
            ("fields", fieldsValue(fields)),
            ("access_token", value(credentials.facebookToken)),
        ])
    }

    private func url(path: String, queryItems: [(name: String, value: String)]) -> String? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/\(apiGraphVersion)/\(path)"
        components.percentEncodedQueryItems = queryItems.map {
            URLQueryItem(name: $0.name, value: $0.value)
        }
        return components.url?.absoluteString
    }

    /// Strict percent-encoding for an individual query value. Encoding everything outside the
    /// unreserved set keeps user input (a hashtag, an account name) from breaking out of its
    /// parameter — `URLComponents` alone leaves `+` untouched and would let `&`/`=` injection
    /// slip through structural assembly.
    private func value(_ raw: String) -> String {
        raw.addingPercentEncoding(withAllowedCharacters: Self.valueAllowed) ?? raw
    }

    /// Encoding for Graph field expressions, whose parentheses and dots must reach the server
    /// intact while braces, spaces and commas are percent-encoded.
    private func fieldsValue(_ raw: String) -> String {
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
        return encoded.replacingOccurrences(of: ",", with: "%2C")
    }

    private static let valueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
