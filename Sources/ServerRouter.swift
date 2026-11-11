import Foundation
import Network
import Security

// MARK: - 局域网信息
enum NetworkInfo {
    /// 当前 Wi-Fi（en0）的 IPv4
    static func wifiIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = first
        while true {
            let ifa = ptr.pointee
            if let sa = ifa.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: ifa.ifa_name)
                if name == "en0" {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(sa, socklen_t(sa.pointee.sa_len),
                                   &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                        address = String(cString: host)
                    }
                }
            }
            guard let next = ifa.ifa_next else { break }
            ptr = next
        }
        return address
    }

    static func isPrivate(_ host: String) -> Bool {
        if host.hasPrefix("192.168.") || host.hasPrefix("10.") { return true }
        if host.hasSuffix(".local") { return true }
        let parts = host.split(separator: ".")
        if parts.count >= 2, parts[0] == "172", let n = Int(parts[1]), (16...31).contains(n) { return true }
        return false
    }

    /// /24 同网段（够用，家用路由基本都是 /24）
    static func sameSubnet(_ a: String, _ b: String) -> Bool {
        let pa = a.split(separator: "."), pb = b.split(separator: ".")
        guard pa.count == 4, pb.count == 4 else { return false }
        return pa[0] == pb[0] && pa[1] == pb[1] && pa[2] == pb[2]
    }
}

// MARK: - 密码存 Keychain
enum Keychain {
    static func set(_ value: String, key: String) {
        let data = Data(value.utf8)
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func remove(_ key: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(q as CFDictionary)
    }
}

// MARK: - 服务器选择
@MainActor
final class ServerRouter: ObservableObject {
    enum Mode: String { case unconfigured, probing, lan, wan, offline }

    @Published var mode: Mode = .unconfigured
    @Published var base: URL?
    @Published var authed = false
    @Published var statusText = ""
    @Published var probeLog: [String] = []
    @Published var wanText: String
    @Published var lanText: String
    @Published var busy = false

    private let defaults = UserDefaults.standard
    private var pathMonitor: NWPathMonitor?

    init() {
        wanText = UserDefaults.standard.string(forKey: "server.wan") ?? ""
        lanText = UserDefaults.standard.string(forKey: "server.lan") ?? ""
    }

    var hasConfig: Bool {
        !wanText.trimmingCharacters(in: .whitespaces).isEmpty ||
        !lanText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var api: API? { base.map { API(base: $0) } }
    var isLAN: Bool { mode == .lan }

    func saveConfig() {
        defaults.set(wanText.trimmingCharacters(in: .whitespaces), forKey: "server.wan")
        defaults.set(lanText.trimmingCharacters(in: .whitespaces), forKey: "server.lan")
    }

    func normalize(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let lower = s.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            s = "http://" + s
        }
        while s.hasSuffix("/") { s.removeLast() }
        guard let u = URL(string: s), u.host != nil else { return nil }
        return u
    }

    /// 局域网优先；不在同一网段就直接跳过，省掉 1.5 秒白等
    func resolve() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }

        mode = .probing
        probeLog = []
        statusText = "正在寻找服务器…"
        guard hasConfig else { mode = .unconfigured; return }

        let lan = normalize(lanText)
        let wan = normalize(wanText)
        let myIP = NetworkInfo.wifiIP()
        probeLog.append("本机 Wi-Fi：\(myIP ?? "未连接")")

        if let lan, let host = lan.host {
            let priv = NetworkInfo.isPrivate(host)
            let near = myIP != nil && NetworkInfo.sameSubnet(myIP!, host)
            if !priv || near {
                if await API(base: lan).ping(timeout: 1.6) {
                    base = lan
                    mode = .lan
                    authed = true
                    statusText = "局域网直连 · \(host)"
                    probeLog.append("✓ 局域网可达，已切到局域网")
                    startMonitor()
                    return
                }
                probeLog.append("✗ 局域网不可达（\(host)）")
            } else {
                probeLog.append("· 不在同一网段（本机 \(myIP ?? "?") / 目标 \(host)），跳过")
            }
        }

        if let wan {
            if await API(base: wan).ping(timeout: 4.5) {
                base = wan
                mode = .wan
                authed = await API(base: wan).isAuthed()
                statusText = authed ? "公网 · \(wan.host ?? "")" : "公网可达，需要密码"
                probeLog.append("✓ 公网可达\(authed ? "，登录态有效" : "，需登录")")
                startMonitor()
                return
            }
            probeLog.append("✗ 公网不可达（\(wan.host ?? "")）")
        }

        mode = .offline
        statusText = "两个地址都连不上"
        startMonitor()
    }

    private func startMonitor() {
        guard pathMonitor == nil else { return }
        let m = NWPathMonitor()
        m.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                if self.mode == .offline { await self.resolve() }
            }
        }
        m.start(queue: DispatchQueue(label: "xviewer.net"))
        pathMonitor = m
    }

    func login(_ password: String) async -> Bool {
        guard let base else { return false }
        busy = true
        defer { busy = false }
        let ok = await API(base: base).login(password: password)
        authed = ok
        if ok {
            Keychain.set(password, key: "server.password")
            probeLog.append("✓ 登录成功")
        } else {
            probeLog.append("✗ 密码不对")
        }
        return ok
    }

    var storedPassword: String? { Keychain.get("server.password") }
}
