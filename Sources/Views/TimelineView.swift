import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var router: ServerRouter
    @State private var items: [Tweet] = []
    @State private var cursor: String?
    @State private var loading = false
    @State private var error: String?
    @State private var loaded = false
    @State private var selectedID: String?
    @State private var showDetail = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if items.isEmpty && loading {
                        ProgressView().padding(48)
                    }
                    ForEach(items) { t in
                        TweetRow(tweet: t)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedID = t.id
                                showDetail = true
                            }
                            .onAppear {
                                if t.id == items.last?.id {
                                    Task { await loadMore() }
                                }
                            }
                        Rectangle().fill(Theme.border).frame(height: 0.5)
                    }
                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.vertical, 12)
                    }
                    if !items.isEmpty && loading {
                        ProgressView().padding(20)
                    }
                    if !items.isEmpty && cursor == nil && !loading {
                        Text("已经到底了")
                            .font(.footnote)
                            .foregroundColor(Theme.dim)
                            .padding(.vertical, 24)
                    }
                }
            }
            .background(Theme.bg)
            .scrollContentBackground(.hidden)
            .navigationTitle("时间线")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await reload() }
            .task {
                if !loaded {
                    loaded = true
                    await reload()
                }
            }
            .navigationDestination(isPresented: $showDetail) {
                if let id = selectedID {
                    DetailView(tweetID: id)
                }
            }
        }
        .tint(Theme.blue)
    }

    private func reload() async {
        guard let api = router.api else { return }
        loading = true
        error = nil
        defer { loading = false }
        do {
            let page = try await api.timeline(cursor: nil, limit: 20)
            items = page.items
            cursor = page.next
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let api = router.api, let c = cursor, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let page = try await api.timeline(cursor: c, limit: 20)
            items.append(contentsOf: page.items)
            cursor = page.next
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct SearchView: View {
    @EnvironmentObject var router: ServerRouter
    @State private var query = ""
    @State private var items: [Tweet] = []
    @State private var searching = false
    @State private var error: String?
    @State private var current: String = ""
    @State private var cursor: String?
    @State private var selectedID: String?
    @State private var showDetail = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if items.isEmpty && !searching {
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 34))
                                .foregroundColor(Theme.dim)
                            Text("搜正文、昵称、账号")
                                .foregroundColor(Theme.dim)
                                .font(.subheadline)
                            Text("走的是服务器上的全文索引，中文按字切分，「袜子」能搜到「黑袜子」")
                                .foregroundColor(Theme.dim.opacity(0.7))
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 80)
                    }
                    ForEach(items) { t in
                        TweetRow(tweet: t)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedID = t.id
                                showDetail = true
                            }
                            .onAppear {
                                if t.id == items.last?.id { Task { await more() } }
                            }
                        Rectangle().fill(Theme.border).frame(height: 0.5)
                    }
                    if searching { ProgressView().padding(20) }
                    if let error {
                        Text(error).font(.footnote).foregroundColor(.red).padding()
                    }
                }
            }
            .background(Theme.bg)
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "关键词")
            .onSubmit(of: .search) { Task { await run(reset: true) } }
            .navigationDestination(isPresented: $showDetail) {
                if let id = selectedID { DetailView(tweetID: id) }
            }
        }
        .tint(Theme.blue)
    }

    private func run(reset: Bool) async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let api = router.api else { return }
        searching = true
        error = nil
        defer { searching = false }
        do {
            let page = try await api.search(text, cursor: reset ? nil : cursor)
            if reset {
                items = page.items
                current = text
            } else {
                items.append(contentsOf: page.items)
            }
            cursor = page.next
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func more() async {
        guard cursor != nil, !searching else { return }
        await run(reset: false)
    }
}
