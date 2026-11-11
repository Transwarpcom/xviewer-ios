import SwiftUI

struct TweetRow: View {
    let tweet: Tweet
    @EnvironmentObject var router: ServerRouter
    @State private var liked = false
    @State private var viewer: ViewerPayload?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if tweet.isRetweetOfOther {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.2.squarepath").font(.system(size: 11, weight: .bold))
                    Text("\(tweet.owner) 转推了").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Theme.dim)
                .padding(.leading, 68)
                .padding(.top, 8)
            }

            HStack(alignment: .top, spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 3) {
                    header
                    if !tweet.content.isEmpty {
                        Text(tweet.content)
                            .font(.system(size: 15))
                            .foregroundColor(Theme.text)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1)
                    }
                    if !tweet.media.isEmpty {
                        MediaGrid(media: tweet.media) { idx in
                            viewer = ViewerPayload(media: tweet.media, start: idx)
                        }
                        .padding(.top, 7)
                    } else if tweet.content.isEmpty {
                        Text("（这条没有正文，也没有媒体）")
                            .font(.system(size: 14))
                            .italic()
                            .foregroundColor(Theme.dim)
                    }
                    actions.padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Theme.bg)
        .fullScreenCover(item: $viewer) { MediaViewer(payload: $0) }
    }

    @ViewBuilder
    private var avatar: some View {
        if !tweet.avatar.isEmpty, let url = router.api?.absolute(tweet.avatar) {
            RemoteImage(url: url)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Theme.blue.opacity(0.35))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(tweet.author.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(tweet.nick.isEmpty ? tweet.author : tweet.nick)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.text)
                .lineLimit(1)
            Text("@\(tweet.author)")
                .font(.system(size: 15))
                .foregroundColor(Theme.dim)
                .lineLimit(1)
            Text("·").foregroundColor(Theme.dim)
            Text(Format.date(tweet.date))
                .font(.system(size: 15))
                .foregroundColor(Theme.dim)
            Spacer(minLength: 0)
        }
    }

    private var actions: some View {
        HStack(spacing: 0) {
            stat(icon: "bubble.left", value: tweet.stats.rep)
            Spacer(minLength: 0)
            stat(icon: "arrow.2.squarepath", value: tweet.stats.rts)
            Spacer(minLength: 0)
            Button {
                liked.toggle()
            } label: {
                stat(icon: liked ? "heart.fill" : "heart",
                     value: tweet.stats.fav + (liked ? 1 : 0),
                     tint: liked ? Theme.pink : Theme.dim)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            stat(icon: "chart.bar", value: tweet.stats.views)
            Spacer(minLength: 0)
            Image(systemName: "bookmark").font(.system(size: 13)).foregroundColor(Theme.dim)
            Spacer(minLength: 0)
            Image(systemName: "square.and.arrow.up").font(.system(size: 13)).foregroundColor(Theme.dim)
        }
        .frame(maxWidth: 420, alignment: .leading)
    }

    private func stat(icon: String, value: Int, tint: Color = Theme.dim) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 13))
            if value > 0 {
                Text(Format.count(value)).font(.system(size: 12))
            }
        }
        .foregroundColor(tint)
    }
}
