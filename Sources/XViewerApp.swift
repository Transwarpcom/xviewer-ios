import SwiftUI

@main
struct XViewerApp: App {
    @StateObject private var router = ServerRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var router: ServerRouter
    @State private var booted = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            Group {
                switch router.mode {
                case .unconfigured:
                    SetupView()
                case .probing:
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.2)
                        Text("正在寻找服务器…").foregroundColor(Theme.dim)
                        if !router.probeLog.isEmpty {
                            VStack(spacing: 4) {
                                ForEach(router.probeLog, id: \.self) { line in
                                    Text(line).font(.caption2).foregroundColor(Theme.dim)
                                }
                            }.padding(.top, 8)
                        }
                    }
                case .offline:
                    OfflineView()
                case .lan, .wan:
                    // 不管局域网还是公网，只要服务端要密码就得先登录
                    if router.authed {
                        MainTabs()
                    } else {
                        LoginView()
                    }
                }
            }
        }
        .task {
            guard !booted else { return }
            booted = true
            if router.hasConfig { await router.resolve() } else { router.mode = .unconfigured }
        }
    }
}

struct MainTabs: View {
    @EnvironmentObject var router: ServerRouter

    var body: some View {
        TabView {
            TimelineView()
                .tabItem { Label("时间线", systemImage: "house.fill") }
            SearchView()
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(Theme.blue)
        .overlay(alignment: .top) {
            if router.isLAN {
                EmptyView()
            }
        }
    }
}
