public struct HashtagIdResponse: Codable {
    public let data: [DataItem]
}

public struct DataItem: Codable {
    public let id: String
}
