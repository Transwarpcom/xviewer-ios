import SwiftUI

struct UserProfileView: View {
    let name: String
    @EnvironmentObject var router: ServerRouter
    @State private var profile: UserProfile?
    @State private var items: [Tweet] = []
    @State private var cursor: String?
    @State private var loading = false
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                banner
                header
                Rectangle().fill(Theme.border).frame(height: 0.5)

                if items.isEmpty && loading {
                    ProgressView().padding(40)
                }
                ForEach(items) { t in
                    TweetRow(tweet: t)
                        .onAppear {
                            if t.id == items.last?.id { Task { await loadMore() } }
                        }
                    Rectangle().fill(Theme.border).frame(height: 0.5)
                }
                if loading && !items.isEmpty { ProgressView().padding(24) }
                if let error {
                    Text(error).font(.footnote).foregroundColor(.red).padding(16)
                }
                if !items.isEmpty && cursor == nil && !loading {
                    Text("已经到底了").font(.footnote).foregroundColor(Theme.dim).padding(.vertical, 22)
                }
            }
        }
        .background(Theme.bg)
        .navigationTitle("@\(name)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !loaded {
                loaded = true
                await load()
            }
        }
    }

    private var banner: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.22, blue: 0.34),
                         Color(red: 0.22, green: 0.15, blue: 0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let b = profile?.banner, !b.isEmpty, let url = URL(string: b) {
                RemoteImage(url: url, contentMode: .fill).clipped()
            }
        }
        .frame(height: 132)
        .clipped()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                avatarBig.offset(y: -40).padding(.bottom, -40)
                Spacer()
            }
            Text(profile?.nick ?? name)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(Theme.text)
                .padding(.top, 6)
            Text("@\(name)")
                .font(.system(size: 14))
                .foregroundColor(Theme.dim)
            if let bio = profile?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 15))
                    .lineSpacing(2)
                    .foregroundColor(Theme.text)
                    .padding(.top, 2)
            }
            HStack(spacing: 14) {
                if let loc = profile?.location, !loc.isEmpty {
                    Label(loc, systemImage: "mappin.and.ellipse")
                }
                if let joined = profile?.joined, !joined.isEmpty {
                    Label(String(joined.prefix(7)), systemImage: "calendar")
                }
            }
            .font(.system(size: 13))
            .foregroundColor(Theme.dim)

            HStack(spacing: 16) {
                stat(profile?.tweets, "帖子")
                stat(profile?.media, "媒体")
                stat(profile?.followers, "关注者")
                stat(profile?.friends, "正在关注")
            }
            .font(.system(size: 14))
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private var avatarBig: some View {
        Group {
            if let a = profile?.avatar, !a.isEmpty, let url = router.api?.absolute(a) {
                RemoteImage(url: url).frame(width: 86, height: 86).clipShape(Circle())
            } else {
                Circle()
                    .fill(Theme.blue.opacity(0.35))
                    .frame(width: 86, height: 86)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
        .overlay(Circle().stroke(Theme.bg, lineWidth: 4))
    }

    private func stat(_ n: Int?, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(Format.count(n ?? 0)).fontWeight(.bold).foregroundColor(Theme.text)
            Text(label).foregroundColor(Theme.dim)
        }
    }

    private func load() async {
        guard let api = router.api else { return }
        loading = true
        defer { loading = false }
        do {
            profile = try await api.user(name)
        } catch {
            self.error = error.localizedDescription
        }
        do {
            let page = try await api.userTimeline(name)
            items = page.items
            cursor = page.next
        } catch {
            if self.error == nil { self.error = error.localizedDescription }
        }
    }

    private func loadMore() async {
        guard let api = router.api, let c = cursor, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let page = try await api.userTimeline(name, cursor: c)
            items.append(contentsOf: page.items)
            cursor = page.next
        } catch {
            self.error = error.localizedDescription
        }
    }
}
