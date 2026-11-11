import Foundation

struct TweetStats: Decodable {
    let fav: Int
    let rts: Int
    let rep: Int
    let quo: Int
    let bmk: Int
    let views: Int
}

struct MediaItem: Decodable, Identifiable {
    let num: Int
    let kind: String          // photo / video / gif
    let w: Int
    let h: Int
    let dur: Double?
    let bytes: Int
    let ext: String
    let src: String           // 相对路径 /m?p=...
    let thumb: String         // 相对路径 /t?p=...
    let orig: String

    var id: String { "\(num)|\(src)" }
    var isVideo: Bool { kind == "video" || kind == "gif" }
}

struct Tweet: Decodable, Identifiable {
    let id: String
    let owner: String
    let author: String
    let nick: String
    let avatar: String
    let content: String
    let date: String
    let ts: Int
    let sensitive: Bool
    let flags: [String]
    let stats: TweetStats
    let media: [MediaItem]
    let mediaCount: Int
    let nPhoto: Int
    let nVideo: Int
    let isRetweetOfOther: Bool
    let hashtags: [String]?
    let source: String?
    let contentSrc: String?
    let dateSrc: String?

    enum CodingKeys: String, CodingKey {
        case id, owner, author, nick, avatar, content, date, ts, sensitive, flags, stats, media, hashtags, source
        case contentSrc = "content_src"
        case dateSrc = "date_src"
        case mediaCount = "media_count"
        case nPhoto = "n_photo"
        case nVideo = "n_video"
        case isRetweetOfOther = "is_retweet_of_other"
    }
}

struct Page: Decodable {
    let items: [Tweet]
    let next: String?
}

struct StatusDetail: Decodable {
    let tweet: Tweet
    let related: [Tweet]
}

struct UserProfile: Decodable {
    let name: String
    let nick: String?
    let avatar: String?
    let banner: String?
    let bio: String?
    let location: String?
    let joined: String?
    let followers: Int?
    let friends: Int?
    let statuses: Int?
    let tweets: Int?
    let media: Int?
}

struct PingInfo: Decodable {
    let ok: Bool
    let service: String?
    let protected: Bool?
    let tweets: Int?
}
