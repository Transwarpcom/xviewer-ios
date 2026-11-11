import SwiftUI
import AVKit

struct DetailView: View {
    let tweetID: String
    @EnvironmentObject var router: ServerRouter
    @State private var detail: StatusDetail?
    @State private var error: String?
    @State private var viewer: ViewerPayload?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let t = detail?.tweet {
                    main(t)
                    meta(t)
                    if let related = detail?.related, !related.isEmpty {
                        Text("同作者的其他帖子")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.text)
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                            .padding(.bottom, 6)
                        ForEach(related) { r in
                            TweetRow(tweet: r)
                            Rectangle().fill(Theme.border).frame(height: 0.5)
                        }
                    }
                } else if let error {
                    Text(error).foregroundColor(.red).padding(24)
                } else {
                    ProgressView().padding(48)
                }
            }
        }
        .background(Theme.bg)
        .navigationTitle("帖子")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .fullScreenCover(item: $viewer) { MediaViewer(payload: $0) }
    }

    private func main(_ t: Tweet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                avatar(t)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.nick.isEmpty ? t.author : t.nick)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text("@\(t.author)")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.dim)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            if !t.content.isEmpty {
                Text(t.content)
                    .font(.system(size: 19))
                    .lineSpacing(4)
                    .foregroundColor(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }

            if !t.media.isEmpty {
                MediaGrid(media: t.media) { idx in
                    viewer = ViewerPayload(media: t.media, start: idx)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }

            HStack(spacing: 22) {
                stat("bubble.left", t.stats.rep)
                stat("arrow.2.squarepath", t.stats.rts)
                stat("heart", t.stats.fav)
                stat("chart.bar", t.stats.views)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if t.isRetweetOfOther {
                Text("\(t.owner) 转推了这条")
                    .font(.caption)
                    .foregroundColor(Theme.dim)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func meta(_ t: Tweet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle().fill(Theme.border).frame(height: 0.5).padding(.vertical, 6)
            row("时间", Format.fullDate(t.date))
            row("来源", t.source ?? "未知")
            row("正文来源", t.contentSrc == "json" ? "JSON 元数据" : (t.contentSrc == "txt" ? "TXT 文本" : "无"))
            row("时间来源", t.dateSrc == "json" ? "元数据" : (t.dateSrc == "filename" ? "文件名" : "推断"))
            if t.mediaCount > 0 {
                let bytes = t.media.reduce(0) { $0 + $1.bytes }
                row("媒体", "\(t.media.count) 个 · \(byteText(bytes))")
            }
            if !t.flags.isEmpty {
                row("解析标记", t.flags.joined(separator: " · "))
            }
            Rectangle().fill(Theme.border).frame(height: 0.5).padding(.vertical, 6)
        }
        .padding(.horizontal, 16)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(.system(size: 13)).foregroundColor(Theme.dim).frame(width: 64, alignment: .leading)
            Text(v).font(.system(size: 13)).foregroundColor(Theme.text.opacity(0.85))
            Spacer(minLength: 0)
        }
    }

    private func stat(_ icon: String, _ n: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 13))
            if n > 0 { Text(Format.count(n)).font(.system(size: 12)) }
        }
        .foregroundColor(Theme.dim)
    }

    @ViewBuilder
    private func avatar(_ t: Tweet) -> some View {
        if !t.avatar.isEmpty, let url = router.api?.absolute(t.avatar) {
            RemoteImage(url: url).frame(width: 44, height: 44).clipShape(Circle())
        } else {
            Circle().fill(Theme.blue.opacity(0.35)).frame(width: 44, height: 44)
                .overlay(Text(String(t.author.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .bold)).foregroundColor(.white))
        }
    }

    private func byteText(_ b: Int) -> String {
        if b > 1_000_000_000 { return String(format: "%.1f GB", Double(b) / 1e9) }
        if b > 1_000_000 { return String(format: "%.1f MB", Double(b) / 1e6) }
        if b > 1_000 { return String(format: "%.0f KB", Double(b) / 1e3) }
        return "\(b) B"
    }

    private func load() async {
        guard let api = router.api else { return }
        do {
            detail = try await api.status(tweetID)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct MediaViewer: View {
    let payload: ViewerPayload
    @EnvironmentObject var router: ServerRouter
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(payload: ViewerPayload) {
        self.payload = payload
        _index = State(initialValue: payload.start)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(payload.media.enumerated()), id: \.offset) { i, m in
                    content(m).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .padding(14)
        }
        .overlay(alignment: .bottom) {
            Text("\(index + 1) / \(payload.media.count)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 22)
        }
    }

    @ViewBuilder
    private func content(_ m: MediaItem) -> some View {
        if m.isVideo, let url = router.api?.absolute(m.src) {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
        } else if let url = router.api?.absolute(m.orig) {
            RemoteImage(url: url, contentMode: .fit)
                .padding(.horizontal, 2)
        }
    }
}
