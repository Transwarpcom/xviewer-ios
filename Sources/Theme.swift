import SwiftUI

enum Theme {
    static let bg = Color.black
    static let card = Color(red: 0.09, green: 0.10, blue: 0.11)
    static let text = Color(red: 0.906, green: 0.914, blue: 0.918)     // #e7e9ea
    static let dim = Color(red: 0.443, green: 0.463, blue: 0.482)      // #71767b
    static let blue = Color(red: 0.114, green: 0.608, blue: 0.941)     // #1d9bf0
    static let pink = Color(red: 0.976, green: 0.094, blue: 0.502)     // #f91880
    static let green = Color(red: 0.0, green: 0.729, blue: 0.486)      // #00ba7c
    static let border = Color(red: 0.184, green: 0.200, blue: 0.212)   // #2f3336
}

enum Format {
    static func count(_ n: Int) -> String {
        if n >= 100_000_000 { return String(format: "%.1f亿", Double(n) / 1e8) }
        if n >= 10_000 { return String(format: "%.1f万", Double(n) / 1e4) }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    static func date(_ s: String) -> String {
        // "2026-10-29 21:08:39" → 同年 "10月29日"，跨年 "2026年10月29日"
        let parts = s.split(separator: " ")
        guard let d = parts.first else { return "时间未知" }
        let comps = d.split(separator: "-")
        guard comps.count == 3, let y = Int(comps[0]), let mo = Int(comps[1]), let dd = Int(comps[2]) else {
            return String(d)
        }
        let now = Calendar.current.component(.year, from: Date())
        return y == now ? "\(mo)月\(dd)日" : "\(y)年\(mo)月\(dd)日"
    }

    static func fullDate(_ s: String) -> String {
        let parts = s.split(separator: " ")
        guard let d = parts.first else { return "时间未知" }
        let comps = d.split(separator: "-")
        guard comps.count == 3, let y = Int(comps[0]), let mo = Int(comps[1]), let dd = Int(comps[2]) else {
            return String(d)
        }
        if parts.count >= 2 {
            return "\(y)年\(mo)月\(dd)日 \(parts[1].prefix(5))"
        }
        return "\(y)年\(mo)月\(dd)日"
    }

    static func duration(_ d: Double) -> String {
        let s = Int(d.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.15))) { phase in
            switch phase {
            case .success(let img):
                img.resizable().aspectRatio(contentMode: contentMode)
            case .failure:
                ZStack {
                    Color(white: 0.07)
                    Image(systemName: "photo").foregroundColor(Theme.dim)
                }
            case .empty:
                ZStack {
                    Color(white: 0.07)
                    ProgressView().scaleEffect(0.7)
                }
            @unknown default:
                Color(white: 0.07)
            }
        }
    }
}
