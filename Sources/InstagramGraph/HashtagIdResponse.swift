struct HashtagIdResponse: Codable {
    let data: [DataItem]
}

struct DataItem: Codable {
    let id: String
}
