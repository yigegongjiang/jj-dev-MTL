```When Editing
本文档作用: 面向开发者的发版记录; CHANGELOG.md 的超集, 1:1 镜像 + 技术变更子项
遵循 AGENTS.md 文档编写规范
- 每条主项 = CHANGELOG.md 对应条目 (原文), 下方缩进子项承载技术变更
- 子项 MAY 写路径 / 函数 / 机制; ≤ 1 行
```

# Changelog (developer, follow [CHANGELOG.md](./CHANGELOG.md))

## [0.1.1] - 2026-07-08

### Added

- 三个文本工具: Format JSON (含嵌套 JSON 字符串自动解包 + 转义兜底) / Multiline → Singleline (转义) / Singleline → Multiline (反转义), 输入即时预览 + 复制 / 粘贴到当前 App.
  - `JJ-DEV-MTL/TextUtils/TextUtilsCore.swift`: 纯逻辑 (`nonisolated`), `escapeToSingleline` / `unescapeToMultiline` / `formatJson`; unescape 仅识别 `\n \t \r \\`, 其余 `\X` 保留原样 (与源 raycast 实现一致).
  - `JJ-DEV-MTL/TextUtils/TextUtilsViewController.swift`: 共享 UI 骨架 (Input NSTextView + Result NSTextView + Copy/Paste 按钮 + 错误提示 + toast) + 3 个子类; Paste 走 `NSApp.hide` + `CGEvent` ⌘V 模拟给前台 App.
  - `Model/Tool.swift`: 追加 `text-multiline-to-singleline` / `text-singleline-to-multiline` 两项; `json-formatter` 标题改为 `Format JSON` 并对接 `FormatJsonViewController`.
  - `Detail/DetailContainerViewController.swift` `show(tool:)` 按 `tool.id` 分发到具体 VC, 未实现的仍走 placeholder.
  - `JJ-DEV-MTLTests` xctest bundle target (test host = app, `@testable import JJ_DEV_MTL`) + shared `.xcscheme` (TestAction 挂上 test target), 33 unit tests 覆盖 escape / unescape / formatJson (含嵌套解包 / 转义兜底 / 键序 / 斜杠 / fragment).

### Changed

- Format JSON 输出键按字典序排序 (更利于 diff 对比); 斜杠不再被转义为 `\/`.
  - `JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]`; JS 源实现保留 insertion order, Foundation 不保序, 选 `.sortedKeys` 换取可预测输出.

[0.1.1]: https://github.com/yigegongjiang/jj-dev-mtl/releases/tag/v0.1.1

## [0.1.0] - 2026-07-08

### Added

- 初始化工程骨架 (macOS AppKit 应用).
  - `main.swift` 顶层 `MainActor.assumeIsolated` 内 `NSApplication.shared` + `AppDelegate` + `app.run()` (显式入口, 避开 `@main` on `NSApplicationDelegate` 未触发 launch 的坑); `App.swift` = `AppDelegate` 类, 代码构建 NSMenu (App / Edit / View / Window) + `NSApp.setActivationPolicy(.regular)`.
  - `Assets.xcassets`; 无 Storyboard / XIB / SwiftUI, `MACOSX_DEPLOYMENT_TARGET=15.6`, 无第三方依赖.
  - `Version.xcconfig` = 版本唯一源 (`MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`), 通过 `baseConfigurationReference` 注入 pbxproj.
  - `ENABLE_APP_SANDBOX=NO` (自更新需要 `Process` 生成 helper 脚本进行 bundle 替换).
- 主窗口 UI 骨架: 左侧工具列表 + 右侧工具内容占位, 参考 DevToys 布局; `⌘S` 折叠 / 展开左侧列表.
  - `Window/MainWindowController.swift` 创建 `NSWindow` (`titled+closable+miniaturizable+resizable`, minSize 720x460, frameAutosaveName), `contentViewController` = `MainSplitViewController`.
  - `Window/MainSplitViewController.swift`: `NSSplitViewController` + `NSSplitViewItem(sidebarWithViewController:)` (min 200 / max 320 / canCollapse) + 详情 item (min 480), 首次 appear 默认选中第 0 项.
  - `Sidebar/SidebarViewController.swift`: `NSTableView` `style = .sourceList`, 单列, `headerView = nil`, 代码构建 `NSTableCellView` (SF Symbol + label) 避免使用 nib.
  - `Detail/DetailContainerViewController.swift`: 子 VC 容器, `swap(to:)` 移除旧子 VC + Auto Layout 填充新子 VC.
  - `Detail/ToolPlaceholderViewController.swift`: 统一占位视图 (标题 + 分隔线 + `TODO: xxx 内容占位`), 用于后续替换成具体工具.
  - `Model/Tool.swift` = `ToolCatalog.all` 平铺列表 (JSON Formatter / Base64 / URL / Hash / UUID / Unix Timestamp / Regex / Text Diff), 后续新增工具在此追加即可.
  - View 菜单 → Toggle Sidebar 通过 `NSSplitViewController.toggleSidebar(_:)` responder chain 派发.
- 提供 `install.sh` 一行命令安装 (下载 → 校验 → 装入 `/Applications`).
  - `.github/workflows/release.yml`: tag `v*` → `macos-latest` → 校验 `tag == Version.xcconfig::MARKETING_VERSION` → `xcodebuild` 出 arm64+x86_64 universal → `codesign -s -` ad-hoc 签名 → `ditto` 打 zip → SHA256 → `softprops/action-gh-release@v2` 发布.
  - `install.sh`: 拉 `releases/latest/download/JJ-DEV-MTL-macos.zip` + `checksums.txt` 校验 → `ditto -x -k` 解压 → `mv` 到 `/Applications` → `xattr -dr com.apple.quarantine` 清检疫属性.
  - 无 Apple Developer 账号 / 证书, ad-hoc 签名产物不可被 Gatekeeper 自动放行, 由 `install.sh` 清 quarantine 兜底.
- Help 菜单 → Check for Updates… : 检测新版, 自动下载 + 替换 + 重启.
  - `Updater.swift`: `GET releases/latest/download/release-metadata.json` → 比较 `GitCommitSHA` (Info.plist 内嵌) vs metadata.sha; 同 tag amend 也能识别; 用户确认 → `URLSession.download` zip → `/usr/bin/ditto -x -k` 解压 → 写 helper shell → `Process.run` detached → `NSApp.terminate`.
  - GHA 构建时 `PlistBuddy Add :GitCommitSHA` 注入 `${GITHUB_SHA}` 到 Info.plist (在 codesign 前); release 附加 `release-metadata.json = {"tag":"...","sha":"..."}`.
  - Helper shell: 轮询等 pid 退出 → `rm -rf` old bundle → `mv` new bundle → 清 quarantine → `open` 重启.
  - App 菜单挂 "Check for Updates…" `@objc` 调用 `Updater.shared.checkForUpdates(userInitiated: true)`.

[0.1.0]: https://github.com/yigegongjiang/jj-dev-mtl/releases/tag/v0.1.0
