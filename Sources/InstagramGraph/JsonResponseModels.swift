import Foundation

public struct Profile: Hashable, Decodable {
    public let biography: String?
    public let name: String?
    public let followersCount: Int?
    public let followsCount: Int?
    public let id: String
    public let mediaCount: Int?
    public let profilePictureUrl: String?
    public let username: String?
    public let insights: InsightsIG?
    public let media: Media?

    private enum CodingKeys: String, CodingKey {
        case biography
        case name
        case followersCount = "followers_count"
        case followsCount = "follows_count"
        case id
        case mediaCount = "media_count"
        case profilePictureUrl = "profile_picture_url"
        case username
        case insights
        case media
    }
}

public struct InsightsIG: Hashable, Decodable {
    public let data: [DataIG]
}

public struct DataIG: Hashable, Decodable {
    public let name: String?
    public let period: String?
    public let values: [Values]
}

public struct Values: Hashable, Decodable {
    public let value: Int?
    public let endTime: String?

    private enum CodingKeys: String, CodingKey {
        case value
        case endTime = "end_time"
    }
}

public struct Media: Hashable, Decodable {
    public let data: [DataMedia]
}

public struct DataMedia: Hashable, Decodable {
    public let mediaType: String?
    public let caption: String?
    public let timestamp: String?
    public let mediaUrl: String?
    public let commentsCount: Int?
    public let isCommentEnabled: Bool?
    public let username: String?
    public let likeCount: Int?
    public let insights: InsightsMedia?

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

public struct InsightsMedia: Hashable, Decodable {
    public let data: [DataIG?]
}

public struct Discovery: Hashable, Decodable {
    public let businessDiscovery: Profile?

    private enum CodingKeys: String, CodingKey {
        case businessDiscovery = "business_discovery"
    }
}
