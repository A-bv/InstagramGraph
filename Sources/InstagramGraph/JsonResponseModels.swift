import Foundation

public enum InstagramMediaType: Hashable {
    case image
    case video
    case carouselAlbum
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

public struct Profile: Hashable, Decodable {
    public let biography: String?
    public let name: String?
    public let followersCount: Int?
    public let followsCount: Int?
    public let id: String
    public let igId: Int?
    public let mediaCount: Int?
    public let profilePictureUrl: URL?
    public let username: String?
    public let website: String?
    public let insights: ProfileInsights?
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

public struct ProfileInsights: Hashable, Decodable {
    public let data: [InsightMetric]
}

public struct InsightMetric: Hashable, Decodable {
    public let name: String?
    public let period: String?
    public let values: [InsightValue]
}

public struct InsightValue: Hashable, Decodable {
    public let value: Int?
    public let endTime: Date?

    private enum CodingKeys: String, CodingKey {
        case value
        case endTime = "end_time"
    }
}

public struct Media: Hashable, Decodable {
    public let data: [InstagramPost]
}

public struct InstagramPost: Hashable, Decodable {
    public let mediaType: InstagramMediaType?
    public let caption: String?
    public let timestamp: Date?
    public let mediaUrl: URL?
    public let commentsCount: Int?
    public let isCommentEnabled: Bool?
    public let username: String?
    public let likeCount: Int?
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

public struct PostInsights: Hashable, Decodable {
    public let data: [InsightMetric]
}

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
