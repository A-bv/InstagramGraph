import Foundation

public struct InstagramGraphEndpointBuilder: Sendable {
    private let apiGraphVersion: String
    private let baseURL = "https://graph.facebook.com"

    public init(apiGraphVersion: String = ConnectedInsightsConfiguration.production.graphAPIVersion) {
        self.apiGraphVersion = apiGraphVersion
    }

    public func hashtagSearchURL(
        searchedHashtag: String,
        credentials: InstagramGraphCredentials
    ) -> String? {
        let url = "\(baseURL)/\(apiGraphVersion)/ig_hashtag_search?user_id=\(credentials.instagramBusinessAccountId)&q=\(searchedHashtag)&access_token=\(credentials.facebookToken)"
        return encoded(url)
    }

    public func hashtagMediaSearchURL(
        hashtagID: String,
        credentials: InstagramGraphCredentials
    ) -> String? {
        let limit = "5"
        let mediaType = "top_media"
        let fields = [
            "caption",
            "comments_count",
            "like_count",
            "media_type",
            "media_url",
            "timestamp",
            "id"
        ].joined(separator: ",")

        let options = "\(mediaType)?fields=\(fields)&user_id=\(credentials.instagramBusinessAccountId)&limit=\(limit)"
        let url = "\(baseURL)/\(apiGraphVersion)/\(hashtagID)/\(options)&access_token=\(credentials.facebookToken)"
        return encoded(url)
    }

    public func analyticsProfileURL(
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
            "insights.metric(reach,impressions,total_interactions)"
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
            "recently_searched_hashtags",
            mediaField
        ]

        let url = "\(baseURL)/\(apiGraphVersion)/\(credentials.instagramBusinessAccountId)?fields=\(fields.joined(separator: ","))&access_token=\(credentials.facebookToken)"
        return encoded(url)
    }

    public func businessDiscoveryURL(
        account: String,
        credentials: InstagramGraphCredentials
    ) -> String? {
        let limit = 12
        let url = "\(baseURL)/\(apiGraphVersion)/\(credentials.instagramBusinessAccountId)?fields=business_discovery.username(\(account)){biography,name,followers_count,follows_count,id,ig_id,media_count,profile_picture_url,username,website,media.limit(\(limit)){media_type,caption,timestamp,media_url,comments_count,username,like_count}}&access_token=\(credentials.facebookToken)"
        return encoded(url)
    }

    private func encoded(_ url: String) -> String? {
        guard let encodedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return encodedUrl.replacingOccurrences(of: ",", with: "%2C")
    }
}
