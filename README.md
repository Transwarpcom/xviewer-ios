# X 存档 · iOS 客户端

自己的 gallery-dl 推特存档，用 iPhone 看。原生 SwiftUI，只读，没有预置服务器地址。

## 特性

- **不预设任何地址**：首次启动让你填「局域网」和「公网」两个地址，填一个也行
- **局域网优先**：先比对当前 Wi-Fi 网段，同网段才试局域网；通了就用局域网（免密码、速度拉满），
  不在同一网段直接跳过（不浪费超时），再退到公网
- **密码只存钥匙串**：公网服务器要密码时弹登录，密码进 iOS Keychain，不写进包、不进仓库
- 时间线（无限滚动、下拉刷新）、帖子详情、全文搜索、图片四宫格、视频播放、全屏看图
- 缩略图按屏幕宽度要 `w=640`，服务端已经按 DPR 分档生成

## 自己编译

没有 Mac 也能出包 —— 用 GitHub Actions：

1. Fork 或 clone 这个仓库
2. 打开 **Actions** → `build` → **Run workflow**
3. 跑完在 Artifacts 里下 `XViewer-ipa`，解压得到 `XViewer-unsigned.ipa`
4. 用 AltStore / Sideloadly / TrollStore 之类自签安装

本地有 Mac 的话：

```bash
brew install xcodegen
xcodegen generate
open XViewer.xcodeproj     # 选自己的开发者证书，真机运行
```

出未签名包（和 CI 一样）：

```bash
xcodebuild -project XViewer.xcodeproj -scheme XViewer -sdk iphoneos \
  -configuration Release -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
mkdir -p Payload && cp -R build/Build/Products/Release-iphoneos/XViewer.app Payload/
zip -qry XViewer-unsigned.ipa Payload
```

## 服务端要求

配套的服务端是自己那套（本地 SQLite + 标准库 HTTP 服务），需要这几个接口：

| 接口 | 用途 |
|---|---|
| `GET /api/ping` | 探测可达性，**必须免认证**，否则 App 判断不了「这台机器通不通」 |
| `GET /api/timeline?limit=&cursor=` | 时间线 |
| `GET /api/search?q=` | 全文搜索 |
| `GET /api/status?id=` | 单条 + 同作者相关 |
| `GET /api/user?n=` | 用户资料（可选） |
| `GET /t?p=&w=` | 缩略图 |
| `GET /m?p=` | 原图 / 视频（支持 Range） |
| `POST /__auth` | 密码登录，成功后下发 HttpOnly cookie |

`/api/ping` 返回：

```json
{ "ok": true, "service": "x-clone", "protected": true, "tweets": 225301 }
```

## 局域网优先是怎么判断的

```
启动
 ├─ 读配置（局域网地址 / 公网地址）
 ├─ 取当前 Wi-Fi 的 IPv4（en0）
 ├─ 局域网地址是私有网段 且 与当前 IP 不同网段？ → 跳过（省 1.5s）
 │    否则 → GET {lan}/api/ping（1.6s 超时）
 │        200 → 用局域网，免密码，结束
 └─ GET {wan}/api/ping（4.5s 超时）
      200 → 用公网，检查登录态，需要就弹密码框
```

网络恢复时（`NWPathMonitor` 检测到 satisfied）如果当前是离线状态，会自动重新探测一次。

## 隐私

- 仓库里**没有任何服务器地址、密码、Token**
- 密码只存在 iOS 钥匙串（`kSecClassGenericPassword`）
- 所有请求直接发往你自己填的地址，没有第三方中转

## 已知限制

- iOS 16+（用了 `NavigationStack` / `scrollContentBackground`）
- 局域网走 `http://`，所以 `Info.plist` 里开了 `NSAllowsArbitraryLoads`；公网建议用 https
- 只读：没有点赞/转推的写入，界面上的红心只在本地变个颜色
- 视频用系统 `VideoPlayer`，HEVC/HDR 的片子能不能放取决于系统解码器
