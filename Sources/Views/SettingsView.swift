import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var router: ServerRouter
    @State private var reconnecting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("当前连接") {
                    HStack {
                        Text("状态")
                        Spacer()
                        Text(statusLabel)
                            .foregroundColor(statusColor)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    if let base = router.base {
                        HStack {
                            Text("地址")
                            Spacer()
                            Text(base.absoluteString)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Theme.dim)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Button {
                        reconnecting = true
                        Task {
                            await router.resolve()
                            reconnecting = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if reconnecting { ProgressView().scaleEffect(0.8) }
                            Text(reconnecting ? "探测中…" : "重新探测")
                        }
                    }
                    .disabled(reconnecting)
                }

                Section {
                    TextField("192.168.1.10:8910", text: $router.lanText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("局域网地址（优先）")
                } footer: {
                    Text("同一 Wi-Fi 下才会尝试。App 会先比对当前网段，不在同一网段就直接跳过，不会白等超时。")
                }

                Section {
                    TextField("https://xv.example.com", text: $router.wanText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("公网地址")
                } footer: {
                    Text("需要密码的服务器会在连上后弹登录框；密码存在系统钥匙串里，不会写进包。")
                }

                Section {
                    Button {
                        router.saveConfig()
                        Task { await router.resolve() }
                    } label: {
                        Text("保存并重连").bold()
                    }
                }

                if !router.probeLog.isEmpty {
                    Section("探测日志") {
                        ForEach(router.probeLog, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Theme.dim)
                        }
                    }
                }

                Section {
                    if router.authed {
                        Button("重新登录（清除本机会话）") {
                            router.logout()
                        }
                        .foregroundColor(Theme.blue)
                    } else {
                        Text("当前未登录，正在等密码")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                } header: {
                    Text("登录")
                } footer: {
                    Text("清除后会立刻回到密码页。局域网服务器如果本身免密，重新探测会直接进去。")
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0").foregroundColor(Theme.dim)
                    }
                    Text("只读客户端。服务器地址、密码都由你自己填，仓库里没有任何预置地址或密钥。")
                        .font(.footnote)
                        .foregroundColor(Theme.dim)
                }
            }
            .navigationTitle("设置")
        }
        .tint(Theme.blue)
    }

    private var statusLabel: String {
        switch router.mode {
        case .lan: return "局域网"
        case .wan: return router.authed ? "公网" : "公网（未登录）"
        case .probing: return "探测中"
        case .offline: return "离线"
        case .unconfigured: return "未配置"
        }
    }

    private var statusColor: Color {
        switch router.mode {
        case .lan: return Theme.green
        case .wan: return router.authed ? Theme.blue : .orange
        case .offline: return .red
        default: return Theme.dim
        }
    }
}
