import Foundation

public struct Profile: Hashable, Decodable {
    public let biography: String?
    public let name: String?
    public let followers_count: Int?
    public let follows_count: Int?
    public let id: String?
    public let media_count: Int?
    public let profile_picture_url: String?
    public let username: String?
    public let insights: InsightsIG?
    public let media: Media?
}

public struct InsightsIG: Hashable, Decodable {
    public let data: [DataIG?]
}

public struct DataIG: Hashable, Decodable {
    public let name: String?
    public let period: String?
    public let values: [Values?]
}

public struct Values: Hashable, Decodable {
    public let value: Int?
    public let end_time: String?
}

public struct Media: Hashable, Decodable {
    public let data: [DataMedia?]
}

public struct DataMedia: Hashable, Decodable {
    public let media_type: String?
    public let caption: String?
    public let timestamp: String?
    public let media_url: String?
    public let comments_count: Int?
    public let is_comment_enabled: Bool?
    public let username: String?
    public let like_count: Int?
    public let insights: InsightsMedia?
}

public struct InsightsMedia: Hashable, Decodable {
    public let data: [DataIG?]
}

public struct Discovery: Hashable, Decodable {
    public let business_discovery: Profile?
}
