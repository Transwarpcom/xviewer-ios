import SwiftUI

struct SetupView: View {
    @EnvironmentObject var router: ServerRouter
    @State private var testing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("把你自己存档服务器的地址填进来。两个都填的话，App 会先试局域网，连不上再走公网。")
                        .font(.footnote)
                        .foregroundColor(Theme.dim)
                }

                Section("局域网地址（可选，优先）") {
                    TextField("192.168.1.10:8910", text: $router.lanText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("公网地址（可选）") {
                    TextField("https://xv.example.com", text: $router.wanText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        router.saveConfig()
                        Task { await router.resolve() }
                    } label: {
                        HStack {
                            Spacer()
                            Text("保存并连接").bold()
                            Spacer()
                        }
                    }
                    .disabled(!router.hasConfig)
                } footer: {
                    Text("局域网地址只在同一个 Wi-Fi 下才会尝试；不在同一网段时会直接跳过，不会多等。")
                }
            }
            .navigationTitle("连接服务器")
        }
    }
}

struct LoginView: View {
    @EnvironmentObject var router: ServerRouter
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 46))
                .foregroundColor(Theme.blue)
            Text("这台服务器需要密码")
                .font(.title3.bold())
                .foregroundColor(Theme.text)
            Text(router.base?.host ?? "")
                .font(.footnote)
                .foregroundColor(Theme.dim)

            SecureField("访问密码", text: $password)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Theme.card)
                .cornerRadius(10)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if let error {
                Text(error).font(.footnote).foregroundColor(.red)
            }

            Button {
                busy = true
                error = nil
                Task {
                    let ok = await router.login(password)
                    if !ok { error = "密码不对，或者服务器拒绝了这个请求" }
                    busy = false
                }
            } label: {
                HStack {
                    if busy { ProgressView().tint(.black) }
                    Text(busy ? "验证中…" : "进入").bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.blue)
            .disabled(password.isEmpty || busy)

            Button("换一个服务器地址") {
                router.mode = .unconfigured
            }
            .font(.footnote)
            .foregroundColor(Theme.dim)
        }
        .padding(28)
    }
}

struct OfflineView: View {
    @EnvironmentObject var router: ServerRouter
    @State private var retrying = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundColor(Theme.dim)
            Text("连不上服务器").font(.title3.bold())
            if !router.probeLog.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(router.probeLog, id: \.self) { line in
                        Text(line).font(.caption).foregroundColor(Theme.dim)
                    }
                }
                .padding(14)
                .background(Theme.card)
                .cornerRadius(12)
            }
            Button {
                retrying = true
                Task {
                    await router.resolve()
                    retrying = false
                }
            } label: {
                HStack {
                    if retrying { ProgressView().tint(.black) }
                    Text(retrying ? "重试中…" : "重试").bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.blue)
            .disabled(retrying)

            Button("修改服务器地址") { router.mode = .unconfigured }
                .font(.footnote)
                .foregroundColor(Theme.dim)
        }
        .padding(28)
    }
}
