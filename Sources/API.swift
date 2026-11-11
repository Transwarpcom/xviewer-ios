import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case badURL
    case http(Int)
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "需要登录（密码不对或会话过期）"
        case .badURL: return "服务器地址无效"
        case .http(let c): return "服务器返回 \(c)"
        case .decode(let m): return "数据解析失败：\(m)"
        }
    }
}

final class API {
    let base: URL
    private let session: URLSession

    init(base: URL) {
        self.base = base
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 25
        cfg.timeoutIntervalForResource = 60
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpShouldSetCookies = true
        cfg.requestCachePolicy = .useProtocolCachePolicy
        self.session = URLSession(configuration: cfg)
    }

    /// 把接口返回的相对路径（/m?p=..）拼成绝对 URL
    func absolute(_ rel: String) -> URL? {
        if rel.hasPrefix("http://") || rel.hasPrefix("https://") { return URL(string: rel) }
        return URL(string: rel, relativeTo: base)?.absoluteURL
    }

    func thumbURL(_ m: MediaItem, width: Int) -> URL? {
        var s = m.thumb
        s += (s.contains("?") ? "&" : "?") + "w=\(width)"
        return absolute(s)
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        guard var comp = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.badURL
        }
        if !query.isEmpty { comp.queryItems = query }
        guard let url = comp.url else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.http(-1) }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decode(String(describing: error))
        }
    }

    func ping(timeout: Double) async -> Bool {
        var req = URLRequest(url: base.appendingPathComponent("api/ping"))
        req.timeoutInterval = timeout
        req.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    func isAuthed(timeout: Double = 6) async -> Bool {
        var comp = URLComponents(url: base.appendingPathComponent("api/timeline"), resolvingAgainstBaseURL: false)
        comp?.queryItems = [URLQueryItem(name: "limit", value: "1")]
        guard let url = comp?.url else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        do {
            let (_, resp) = try await session.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    func login(password: String, timeout: Double = 12) async -> Bool {
        var req = URLRequest(url: base.appendingPathComponent("__auth"))
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let enc = password.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        req.httpBody = Data("p=\(enc)".utf8)
        _ = try? await session.data(for: req)   // 302 会自动跟随并写入 cookie
        return await isAuthed()
    }

    func timeline(cursor: String? = nil, limit: Int = 20, mediaOnly: Bool = false) async throws -> Page {
        var q = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let cursor { q.append(URLQueryItem(name: "cursor", value: cursor)) }
        if mediaOnly { q.append(URLQueryItem(name: "media", value: "1")) }
        return try await get("api/timeline", query: q)
    }

    func search(_ text: String, cursor: String? = nil) async throws -> Page {
        var q = [URLQueryItem(name: "q", value: text), URLQueryItem(name: "limit", value: "20")]
        if let cursor { q.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await get("api/search", query: q)
    }

    func status(_ id: String) async throws -> StatusDetail {
        try await get("api/status", query: [URLQueryItem(name: "id", value: id)])
    }

    func user(_ name: String) async throws -> UserProfile {
        try await get("api/user", query: [URLQueryItem(name: "n", value: name)])
    }

    func userTimeline(_ name: String, cursor: String? = nil) async throws -> Page {
        var q = [URLQueryItem(name: "user", value: name), URLQueryItem(name: "limit", value: "20")]
        if let cursor { q.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await get("api/timeline", query: q)
    }
}
