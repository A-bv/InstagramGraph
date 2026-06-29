import Foundation

/// The type of media attached to an Instagram post.
public enum InstagramMediaType: Hashable {
    /// A single photo.
    case image
    /// A single video or reel.
    case video
    /// An album containing multiple photos or videos.
    case carouselAlbum
    /// A media type returned by the API that is not yet modelled.
    case unknown(String)
}

extension InstagramMediaType: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "IMAGE": self = .image
        case "VIDEO": self = .video
        case "CAROUSEL_ALBUM": self = .carouselAlbum
        default: self = .unknown(raw)
        }
    }
}

/// An Instagram Business or Creator account profile returned by the Graph API.
public struct Profile: Hashable, Decodable {
    /// The bio text shown on the profile.
    public let biography: String?
    /// The display name on the profile.
    public let name: String?
    /// Total number of accounts that follow this profile.
    public let followersCount: Int?
    /// Total number of accounts this profile follows.
    public let followsCount: Int?
    /// The Graph API object ID for this Instagram account.
    public let id: String
    /// The numeric Instagram user ID.
    public let igId: Int?
    /// Total number of media objects published by this account.
    public let mediaCount: Int?
    /// URL of the profile picture.
    public let profilePictureUrl: URL?
    /// The Instagram handle, without the `@` prefix.
    public let username: String?
    /// The website URL listed on the profile.
    public let website: String?
    /// Aggregated account-level engagement metrics.
    public let insights: ProfileInsights?
    /// The account's recent media.
    public let media: Media?

    private enum CodingKeys: String, CodingKey {
        case biography
        case name
        case followersCount = "followers_count"
        case followsCount = "follows_count"
        case id
        case igId = "ig_id"
        case mediaCount = "media_count"
        case profilePictureUrl = "profile_picture_url"
        case username
        case website
        case insights
        case media
    }
}

/// A collection of account-level insight metrics.
public struct ProfileInsights: Hashable, Decodable {
    public let data: [InsightMetric]
}

/// A single named metric with time-series values (e.g. impressions, reach).
public struct InsightMetric: Hashable, Decodable {
    /// The metric name as returned by the API (e.g. `"impressions"`, `"reach"`).
    public let name: String?
    /// The reporting period (e.g. `"day"`, `"week"`, `"month"`).
    public let period: String?
    /// Individual data points within this reporting period.
    public let values: [InsightValue]
}

/// A single data point within an insight metric.
public struct InsightValue: Hashable, Decodable {
    /// The numeric value for this data point.
    public let value: Int?
    /// The end of the measurement window for this data point.
    public let endTime: Date?

    private enum CodingKeys: String, CodingKey {
        case value
        case endTime = "end_time"
    }
}

/// A paginated collection of Instagram posts.
public struct Media: Hashable, Decodable {
    public let data: [InstagramPost]
}

/// A single Instagram post or reel returned by the Graph API.
public struct InstagramPost: Hashable, Decodable {
    /// The media type of this post.
    public let mediaType: InstagramMediaType?
    /// The caption text.
    public let caption: String?
    /// When the post was published.
    public let timestamp: Date?
    /// Direct URL to the media file.
    public let mediaUrl: URL?
    /// Number of comments on this post.
    public let commentsCount: Int?
    /// Whether comments are enabled on this post.
    public let isCommentEnabled: Bool?
    /// The username of the account that owns this post.
    public let username: String?
    /// Number of likes.
    public let likeCount: Int?
    /// Post-level engagement metrics.
    public let insights: PostInsights?

    private enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
        case caption
        case timestamp
        case mediaUrl = "media_url"
        case commentsCount = "comments_count"
        case isCommentEnabled = "is_comment_enabled"
        case username
        case likeCount = "like_count"
        case insights
    }
}

/// A collection of post-level insight metrics.
public struct PostInsights: Hashable, Decodable {
    public let data: [InsightMetric]
}

// Staged for the `businessDiscovery` feature (see ConnectedInsightsGatewayProtocol); the response
// model is ready but not yet decoded by any public call.
struct Discovery: Hashable, Decodable {
    let businessDiscovery: Profile?

    private enum CodingKeys: String, CodingKey {
        case businessDiscovery = "business_discovery"
    }
}

extension JSONDecoder {
    static func instagram() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(instagramDateFormatter)
        return decoder
    }
}

private let instagramDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return f
}()
