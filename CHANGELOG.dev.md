```When Editing
本文档作用: 面向开发者的发版记录; CHANGELOG.md 的超集, 1:1 镜像 + 技术变更子项
遵循 AGENTS.md 文档编写规范
- 每条主项 = CHANGELOG.md 对应条目 (原文), 下方缩进子项承载技术变更
- 子项 MAY 写路径 / 函数 / 机制; ≤ 1 行
```

# Changelog (developer, follow [CHANGELOG.md](./CHANGELOG.md))

## [0.3.3] - 2026-07-23

### Changed

- 应用更名 `JJ-DEV-MTL` → `jj-dev-MTL`: 应用名与窗口标题同步更新; 原有设置与历史记录不受影响.
  - 全量重命名: Xcode 工程 / target / scheme / product / app 名, Swift module `JJ_DEV_MTL` → `jj_dev_MTL`, 源码目录 / 测试目录 / `.xcodeproj`, 文档 / CI (`release.yml`) / `install.sh`, GitHub repo 与本机目录.
  - 刻意不变: bundle ID `com.yigegongjiang.JJ-DEV-MTL` + `UserDefaults` key 前缀 `JJDEVMTL.*` → 用户设置 / 窗口尺寸 / 历史零丢失; Release 资产名随之变为 `jj-dev-MTL-macos.zip` (旧版内建更新器需一次手动 `install.sh` 迁移).

## [0.3.2] - 2026-07-09

### Added

- Format JSON 支持直接输入 JSON URL 或含单一 URL 的 curl / 文本: 自动拉取远端 JSON 并格式化, 原始 JSON / 转义 JSON 输入保持不变.
  - `TextUtils/TextUtilsCore.swift`: `remoteJsonURL(from:)` 支持 direct URL / curl token 解析 / 唯一 URL 提取, 同时避开 JSON 内 URL 字符串.
  - `TextUtils/TextUtilsViewController.swift`: `FormatJsonViewController` 对 URL 输入启动可取消 `Task`, `RemoteJSONFetcher` 校验 HTTP 2xx / UTF-8 / 50 MB 上限后复用 `formatJson` 与树视图缓存.
  - `JJ-DEV-MTLTests/TextUtilsCoreTests.swift`: 覆盖 URL 检测、fetch 2xx/HTTP error/non-UTF8; QR 测试改用当前顶层 tab 路由入口.

## [0.3.1] - 2026-07-09

### Added

- Format JSON 新增树形视图: tab 栏右侧新按钮切换 文本 / 树形, 树中每个对象·数组可展开折叠 (点击三角或键盘 ← / →), 双击行也可切换, ⌘C 复制选中节点为标准 JSON. 树形为虚拟化渲染, 数十万节点的超大 JSON 也流畅.
  - `TextUtils/JsonTreeView.swift`: 新增. `JsonNode` (class, 引用相等) + `JsonNodeBuilder` (NSNumber/CFBoolean 分类, 对象 keys `.sorted()` 与文本 `.sortedKeys` 一致; `displayLine` 懒生成+缓存, 构树阶段零 NSAttributedString) + `JsonOutlineView` (拦 ⌘C → 单选序列化 raw, 多选包装数组 pretty JSON) + `JsonTreeView` (NSOutlineView 单列固定行高 + Cell 复用; 闭合括号虚拟节点负缩进对齐父行; 不监听 expand/collapse 通知避免 O(N²); 节点数 > 3000 只展根一层).
  - `TextUtils/TextUtilsCore.swift` `FormatResult`: 新增 `parsed: Any?` 携带解析对象, 树视图免二次解析.
  - `TextUtils/TextUtilsViewController.swift`: 基类新增 `makeResultOverlay()` / `didRefreshResult()` 可 override hook; loadView 时 overlay 铺满 result pane 覆盖 textView (初始 hidden); `FormatJsonViewController` 懒构树 (`treeDirty` 标记, text 模式不构树, 切 tree 才 rebuild), `makeAccessory` 视图切换按钮 (`list.triangle` ↔ `text.alignleft`).

### Fixed

- 修复粘贴超大 / 单行 (minified) JSON 界面卡死 (sample 实测: 3MB 单行 catalog 开屏主线程 100% CPU 持续冻结).
  - 真凶: TextKit 2 绘制单条超长行时逐字符 `_resolvedRenderingAttributesForCharacterIndex` 走 `NSConcreteHashTable` O(N²) rehash. `TextUtils/TextUtilsViewController.swift` `makeScrollableTextView`: 访问 `layoutManager` 强制 TextKit 2 → 1 回退 + `allowsNonContiguousLayout = true`, 只排/绘可见区.
  - `FormatJsonViewController.highlightResult`: 输出 > 512 KB 时只染色渲染前缀预览 + 顶部提示切树形, 避免 NSTextView 同步布局多 MB rich text (实测 6MB → 4.2s → 降至 ~0.4s).

## [0.3.0] - 2026-07-08

### Added

- 新增 Codecs / Tokens 系列工具: Timestamp / URL / Base64 (文本 + 图片) / JWT / QR Code.
  - `Model/Tool.swift`: 移除 Base64 / URL / Timestamp 独立占位入口, 改为 `codec-toolkit` 单入口.
  - `TextUtils/CodecToolkitCore.swift`: URL component percent encode/decode, Base64 std/url-safe decode, timestamp seconds/ms/us/date 转换, JWT Base64URL decode+JSON pretty+时间 claim 展示, QR Core Image 生成/识别.
  - `JJ-DEV-MTLTests/TextUtilsCoreTests.swift`: 新增 URL/Base64/Timestamp/JWT/Base64URL/Data URI/QR 往返测试.

### Changed

- 全新顶部水平 tab 导航替代 sidebar+split; 操作控件上交 tab 栏右侧, 内容区铺满.
  - `Window/RootTabViewController.swift`: 单栏 NSSegmentedControl (左对齐) + 右侧 accessory stack; `ToolbarAccessoryProviding`/`ToolbarAccessoryHost` 协议让子 VC 交出控件, 切 tab 时 `reloadToolbarAccessories`; 数字键 1-N (非编辑态) 切 tab; 切走前 `snapshotHistory`.
  - `TextUtils/CodecToolkitViewController.swift`: 去内部 moduleSelector, 5 模块由 `selectModule(_:)` 驱动并平铺为顶部 tab; 各模块控件经 `toolbarAccessories` 上交, 状态标签移入图片列下方.
  - `TextUtils/TextUtilsViewController.swift`: history / 方向 / 布局按钮上交顶部栏, 容器只留 `IOSplitView` 铺满; `activateInput()` 空输入探查剪贴板 (复用 VC 下每次切入探查).
  - `Window/RootTabViewController.swift`: 切 tab 后对 TextUtils VC 调 `activateInput()` + `makeFirstResponder(nil)` 清焦 (无 sidebar 后文本框成默认响应者会吞数字键).
  - `Window/MainWindowController.swift`: `contentViewController = RootTabViewController`, 去标题栏侧栏折叠按钮; `App.swift` 去 View→Toggle Sidebar 菜单.
  - `App.swift` / `Settings/AutoQuitController.swift`: 补 `@MainActor` / `MainActor.assumeIsolated` (Xcode 16.4 起 actor 隔离由 warning 转 error, 修 CI 构建, 防编译器升级再度失败).

### Removed

- 移除侧栏 / detail 容器 / 占位 VC / 未实现占位工具入口 (Hash / UUID / Regex / Text Diff).
  - 删 `Sidebar/SidebarViewController.swift` / `Detail/DetailContainerViewController.swift` / `Detail/ToolPlaceholderViewController.swift` / `Window/MainSplitViewController.swift`; `Model/Tool.swift` 去 `ToolCatalog` (仅 sidebar 用).

## [0.2.0] - 2026-07-08

### Added

- 结果语法染色; Format JSON 主动探查: 从含噪 / 被转义 / 多重转义文本中自动提取并解析 JSON.
  - `TextUtils/SyntaxHighlighter.swift`: UTF-16 token 扫描, JSON 键 / 值 / 数 / 关键字 / 标点 + 转义序列分色 (dynamic light/dark), 非 BMP 安全.
  - `TextUtils/TextUtilsCore.swift` `formatJson`: 逐层 `jsonUnescape` 候选 + `probeLongestJSON` 平衡括号扫描 (跳过字符串 / 转义), 取最长可解析区段.
- 自动退出 + 窗口 frame 记忆.
  - `Settings/AutoQuitController.swift`: `NSEvent` 活动监听重置 `Timer`(.common mode), 到时 `NSApp.terminate`; 默认 5 min, 0 = Never.
  - `Settings/SettingsViewController.swift`: `NSPopUpButton` 选时长写 UserDefaults; `Model/Tool.swift` 加 `settings` 入口, `Detail/DetailContainerViewController` 路由.
  - `Window/MainWindowController.swift`: 手动持久化尺寸 (`windowDidResize`/`WillClose` → UserDefaults), 启动居中于鼠标所在屏幕; `isRestorable=false` + `shouldCascadeWindows=false` (setFrameAutosaveName 在 NSWindowController+状态恢复组合下不保存 resize).
- 打开自动填入剪贴板; 输入按工具本地保存.
  - `TextUtilsViewController.loadView`: UserDefaults `JJDEVMTL.input.<toolid>` 恢复, 空则读 `NSPasteboard`; `textDidChange` 写回.

### Changed

- 全新可拖拽双栏 + 侧栏折叠 + 数字键选工具; Multiline ⇄ Singleline 合并.
  - `TextUtils/IOSplitView.swift`: 加粗分隔 + 握把 + 双击复位; `TextUtilsViewController` 顶部单行控制条 (方向 / 布局皆小图标按钮), 结果 `isSelectable`.
  - `Window/MainSplitViewController.swift`: 侧栏默认 `isCollapsed`; `NSEvent` 数字键 (非编辑态) 选工具; `MainWindowController` 标题栏 accessory 放折叠按钮 (响应链 `toggleSidebar`).
  - `Sidebar/SidebarViewController.swift`: 序号替代 SF Symbol (`ToolCellView` emphasized 变白); `Model/Tool.swift` 去 `symbolName` + 合并 escape/unescape 入口.

### Removed

- 移除 Copy/Paste 按钮、Input/Result 标签、冗余标题与错误常驻行 (错误改结果区红字).

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
