import Cocoa

// text-utils 工具共享 UI: 标题 + 方向切换按钮 + (可选)工具级附加控件 + 可拖拽 split (输入/结果) + 错误提示.
// 无 Input/Result 标签, 无 Copy/Paste 按钮 (面向键盘用户: 结果可选中直接 ⌘C); 出现时自动探查剪贴板填入输入.
class TextUtilsViewController: NSViewController, NSTextViewDelegate, NSSplitViewDelegate, ToolbarAccessoryProviding {

  private let tool: Tool
  private let placeholder: String
  private let resultDefaultText: String

  private var inputTextView: NSTextView!
  private var resultTextView: NSTextView!

  private var ioSplit: IOSplitView!
  private var orientationButton: NSButton!
  private var historyButton: NSButton!
  private var didLayoutOnce = false

  // 操作控件上交顶部 tab 栏右侧: history + (可选)方向切换 + 布局切换
  weak var accessoryHost: ToolbarAccessoryHost?
  private var accessoryView: NSView?
  var toolbarAccessories: [NSView] {
    var views: [NSView] = [historyButton]
    if let accessoryView { views.append(accessoryView) }
    views.append(orientationButton)
    return views
  }

  private static let historyLimit = 15

  static let resultFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
  private static let orientationKey = "JJDEVMTL.IOSplit.vertical"  // true = 左右, false = 上下
  private static let minPaneSize: CGFloat = 120

  init(tool: Tool, placeholder: String, resultDefaultText: String) {
    self.tool = tool
    self.placeholder = placeholder
    self.resultDefaultText = resultDefaultText
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError() }

  // 子类实现: 输入 -> (结果, 错误)
  func transform(_ input: String) -> (result: String, error: String?) {
    return ("", nil)
  }

  // 子类覆盖: 结果染色; 默认纯文本
  func highlightResult(_ result: String, font: NSFont) -> NSAttributedString {
    SyntaxHighlighter.plain(result, font: font)
  }

  // 子类覆盖: 标题栏下方的工具级附加控件 (如方向切换); 默认无
  func makeAccessory() -> NSView? { nil }

  // 子类覆盖: 与结果文本区平级的覆盖视图 (铺满 result pane, 遮住 textView); 默认无.
  // 用途: 提供替代视图 (如 JSON 树形展示), 通过 setResultOverlayHidden 切换显隐
  func makeResultOverlay() -> NSView? { nil }

  // 子类覆盖: refresh 完成 (含成功/错误) 后回调, 用于同步替代视图
  func didRefreshResult(text: String, error: String?) {}

  // 供子类在附加控件变化后刷新结果
  func reloadResult() { refresh() }

  // 供子类切换 result overlay 显隐 (显 = 遮住 textView; 隐 = 恢复文本视图)
  func setResultOverlayHidden(_ hidden: Bool) {
    resultOverlay?.isHidden = hidden
  }

  // 子类可读: 当前 overlay (供切按钮读取当前状态)
  var isResultOverlayVisible: Bool {
    guard let v = resultOverlay else { return false }
    return !v.isHidden
  }

  private var resultOverlay: NSView?

  // tab 激活时调用: 输入为空则主动探查剪贴板填入 (打开即用; 复用 VC 下 loadView 只跑一次, 靠此每次切入探查)
  func activateInput() {
    guard let tv = inputTextView,
      tv.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let clip = NSPasteboard.general.string(forType: .string),
      !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return }
    tv.string = clip
    UserDefaults.standard.set(clip, forKey: inputStorageKey)
    refresh()
  }

  override func loadView() {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    orientationButton = NSButton(title: "", target: self, action: #selector(toggleOrientation))
    orientationButton.bezelStyle = .texturedRounded
    orientationButton.imagePosition = .imageOnly
    orientationButton.translatesAutoresizingMaskIntoConstraints = false
    orientationButton.setContentHuggingPriority(.required, for: .horizontal)

    historyButton = NSButton(title: "", target: self, action: #selector(showHistory))
    historyButton.bezelStyle = .texturedRounded
    historyButton.imagePosition = .imageOnly
    historyButton.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "History")
    historyButton.toolTip = "Input history"
    historyButton.translatesAutoresizingMaskIntoConstraints = false
    historyButton.setContentHuggingPriority(.required, for: .horizontal)

    // 输入 / 结果: 无标签, 滚动文本区直接入 split
    let inputScroll = Self.makeScrollableTextView(editable: true, placeholder: placeholder)
    inputTextView = inputScroll.documentView as? NSTextView
    inputTextView.delegate = self
    // 恢复上次内容; 无则主动填入剪贴板 (在 loadView 中执行, 不依赖 appearance 时序)
    if let saved = UserDefaults.standard.string(forKey: inputStorageKey), !saved.isEmpty {
      inputTextView.string = saved
    } else if let clip = NSPasteboard.general.string(forType: .string),
      !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      inputTextView.string = clip
    }

    let resultScroll = Self.makeScrollableTextView(editable: false, placeholder: nil)
    resultTextView = resultScroll.documentView as? NSTextView
    resultTextView.isRichText = true       // 承载语法染色
    resultTextView.isSelectable = true     // 键盘用户直接 ⌘C 复制

    ioSplit = IOSplitView()
    ioSplit.translatesAutoresizingMaskIntoConstraints = false
    ioSplit.isVertical = UserDefaults.standard.bool(forKey: Self.orientationKey)
    ioSplit.delegate = self
    ioSplit.onDividerDoubleClick = { [weak self] in self?.centerDivider() }
    ioSplit.addArrangedSubview(Self.makePane(inputScroll))

    // Result pane: textView 底, overlay (若子类提供) 覆盖其上, 初始 hidden
    let resultPane = NSView()
    resultScroll.translatesAutoresizingMaskIntoConstraints = false
    resultPane.addSubview(resultScroll)
    NSLayoutConstraint.activate([
      resultScroll.leadingAnchor.constraint(equalTo: resultPane.leadingAnchor),
      resultScroll.trailingAnchor.constraint(equalTo: resultPane.trailingAnchor),
      resultScroll.topAnchor.constraint(equalTo: resultPane.topAnchor),
      resultScroll.bottomAnchor.constraint(equalTo: resultPane.bottomAnchor),
    ])
    if let overlay = makeResultOverlay() {
      overlay.translatesAutoresizingMaskIntoConstraints = false
      overlay.isHidden = true
      resultPane.addSubview(overlay)
      NSLayoutConstraint.activate([
        overlay.leadingAnchor.constraint(equalTo: resultPane.leadingAnchor),
        overlay.trailingAnchor.constraint(equalTo: resultPane.trailingAnchor),
        overlay.topAnchor.constraint(equalTo: resultPane.topAnchor),
        overlay.bottomAnchor.constraint(equalTo: resultPane.bottomAnchor),
      ])
      resultOverlay = overlay
    }
    ioSplit.addArrangedSubview(resultPane)
    updateOrientationButton()

    accessoryView = makeAccessory()

    // 控件已上交顶部 tab 栏 (toolbarAccessories); 内容区只放可拖拽 split, 铺满窗口
    container.addSubview(ioSplit)
    NSLayoutConstraint.activate([
      ioSplit.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
      ioSplit.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
      ioSplit.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 6),
      ioSplit.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
    ])

    self.view = container
    refresh()
  }

  override func viewDidLayout() {
    super.viewDidLayout()
    if !didLayoutOnce, ioSplit.bounds.width > 0, ioSplit.bounds.height > 0 {
      didLayoutOnce = true
      centerDivider()
    }
  }

  override func viewWillDisappear() {
    super.viewWillDisappear()
    snapshotHistory()  // 关闭窗口时也快照 (切换工具的快照由 DetailContainer 触发)
  }

  // MARK: - 输入历史 (UserDefaults 字符串数组, 去重置顶, 上限 N)

  private var historyKey: String { "JJDEVMTL.history.\(tool.id)" }

  private func history() -> [String] { UserDefaults.standard.stringArray(forKey: historyKey) ?? [] }

  // 把当前输入快照进历史 (供 DetailContainer 在切换前调用)
  func snapshotHistory() {
    let cur = inputTextView?.string ?? ""
    guard !cur.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    var h = history()
    h.removeAll { $0 == cur }        // 已存在则移动到最前
    h.insert(cur, at: 0)
    if h.count > Self.historyLimit { h = Array(h.prefix(Self.historyLimit)) }
    UserDefaults.standard.set(h, forKey: historyKey)
  }

  @objc private func showHistory() {
    snapshotHistory()  // 先把当前输入并入, 便于在列表中回看
    let h = history()
    let menu = NSMenu()
    if h.isEmpty {
      let empty = NSMenuItem(title: "No history", action: nil, keyEquivalent: "")
      empty.isEnabled = false
      menu.addItem(empty)
    } else {
      for (i, entry) in h.enumerated() {
        let oneLine = entry.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\t", with: " ")
        let preview = oneLine.count > 60 ? String(oneLine.prefix(60)) + "…" : oneLine
        let item = NSMenuItem(title: preview, action: #selector(pickHistory(_:)), keyEquivalent: "")
        item.tag = i
        item.target = self
        menu.addItem(item)
      }
    }
    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: historyButton.bounds.height + 4), in: historyButton)
  }

  // 选中历史项: 载入 input 并刷新 -> output 同步更新
  @objc private func pickHistory(_ sender: NSMenuItem) {
    let h = history()
    guard h.indices.contains(sender.tag) else { return }
    let entry = h[sender.tag]
    inputTextView.string = entry
    UserDefaults.standard.set(entry, forKey: inputStorageKey)
    refresh()
  }

  // MARK: - 方向切换

  @objc private func toggleOrientation() {
    ioSplit.isVertical.toggle()
    UserDefaults.standard.set(ioSplit.isVertical, forKey: Self.orientationKey)
    updateOrientationButton()
    ioSplit.adjustSubviews()
    ioSplit.layoutSubtreeIfNeeded()
    centerDivider()
  }

  private func updateOrientationButton() {
    let symbol = ioSplit.isVertical ? "rectangle.split.1x2" : "rectangle.split.2x1"
    orientationButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Toggle layout")
    orientationButton.toolTip = ioSplit.isVertical ? "Switch to stacked layout" : "Switch to side-by-side layout"
  }

  private func centerDivider() {
    let total = ioSplit.isVertical ? ioSplit.bounds.width : ioSplit.bounds.height
    guard total > 0 else { return }
    ioSplit.setPosition((total - ioSplit.dividerThickness) / 2, ofDividerAt: 0)
  }

  // MARK: - NSSplitViewDelegate (限制两侧 pane 最小尺寸)

  func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMin: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
    proposedMin + Self.minPaneSize
  }

  func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMax: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
    proposedMax - Self.minPaneSize
  }

  // MARK: - 数据流

  private var inputStorageKey: String { "JJDEVMTL.input.\(tool.id)" }
  private var historyWork: DispatchWorkItem?

  func textDidChange(_ notification: Notification) {
    UserDefaults.standard.set(inputTextView.string, forKey: inputStorageKey)  // 持久化最新内容
    refresh()
    scheduleHistorySnapshot()  // 输入停顿后自动入历史
  }

  // 输入停顿 1.5s 后快照当前输入进历史 (去抖: 连续粘贴/编辑只在稳定后记一次)
  private func scheduleHistorySnapshot() {
    historyWork?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.snapshotHistory() }
    historyWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
  }

  private func refresh() {
    let input = inputTextView?.string ?? ""
    if input.isEmpty {
      setResult(NSAttributedString(string: resultDefaultText, attributes: [
        .font: Self.resultFont, .foregroundColor: NSColor.secondaryLabelColor,
      ]))
      didRefreshResult(text: "", error: nil)
      return
    }
    let (result, error) = transform(input)
    if let error {
      // 错误直接显示在结果区 (不占常驻行)
      setResult(NSAttributedString(string: error, attributes: [
        .font: Self.resultFont, .foregroundColor: NSColor.systemRed,
      ]))
    } else {
      setResult(highlightResult(result, font: Self.resultFont))
    }
    didRefreshResult(text: result, error: error)
  }

  private func setResult(_ attr: NSAttributedString) {
    resultTextView.textStorage?.setAttributedString(attr)
  }

  // MARK: - 构件

  // 一个 pane: 滚动文本区填满 (无标签)
  private static func makePane(_ scroll: NSView) -> NSView {
    let pane = NSView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    pane.addSubview(scroll)
    NSLayoutConstraint.activate([
      scroll.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
      scroll.topAnchor.constraint(equalTo: pane.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: pane.bottomAnchor),
    ])
    return pane
  }

  private static func makeScrollableTextView(editable: Bool, placeholder: String?) -> NSScrollView {
    let scroll = NSScrollView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    scroll.hasVerticalScroller = true
    scroll.hasHorizontalScroller = false
    scroll.autohidesScrollers = true
    scroll.borderType = .lineBorder
    scroll.drawsBackground = true

    let tv = NSTextView()
    // 强制 TextKit 1 + 非连续布局: TextKit 2 绘制单条超长行 (如 minified JSON 的 3MB 单行) 时,
    // 逐字符解析 rendering attributes 走 NSConcreteHashTable O(n²) rehash, 主线程冻结数秒 (sample 实测).
    // 访问 layoutManager 触发 TextKit 2 -> 1 兼容回退; 非连续布局只排 / 绘可见区, 长行也流畅.
    tv.layoutManager?.allowsNonContiguousLayout = true
    tv.isEditable = editable
    tv.isRichText = false
    tv.allowsUndo = editable
    tv.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
    tv.autoresizingMask = [.width]
    tv.isVerticallyResizable = true
    tv.isHorizontallyResizable = false
    tv.textContainerInset = NSSize(width: 6, height: 6)
    tv.textContainer?.widthTracksTextView = true
    tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
    tv.minSize = NSSize(width: 0, height: 0)
    tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    if let placeholder {
      tv.setValue(NSAttributedString(string: placeholder, attributes: [
        .foregroundColor: NSColor.tertiaryLabelColor,
        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
      ]), forKey: "placeholderAttributedString")
    }
    scroll.documentView = tv
    return scroll
  }
}

// 互反工具合一: 单个小图标按钮翻转 多行→单行 / 单行→多行 (方向持久化)
final class EscapeUnescapeViewController: TextUtilsViewController {

  private var isUnescape = UserDefaults.standard.bool(forKey: "JJDEVMTL.escape.unescape")
  private var dirButton: NSButton!

  init(tool: Tool) {
    super.init(
      tool: tool,
      placeholder: "Paste or type text here...",
      resultDefaultText: "Enter text above to see the result"
    )
  }
  required init?(coder: NSCoder) { fatalError() }

  override func makeAccessory() -> NSView? {
    let b = NSButton(title: "", target: self, action: #selector(toggleDirection))
    b.bezelStyle = .texturedRounded
    b.imagePosition = .imageOnly
    b.translatesAutoresizingMaskIntoConstraints = false
    b.setContentHuggingPriority(.required, for: .horizontal)
    dirButton = b
    updateDirButton()
    return b
  }

  @objc private func toggleDirection() {
    isUnescape.toggle()
    UserDefaults.standard.set(isUnescape, forKey: "JJDEVMTL.escape.unescape")
    updateDirButton()
    reloadResult()
  }

  private func updateDirButton() {
    let symbol = isUnescape ? "arrow.left.to.line" : "arrow.right.to.line"
    dirButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Toggle direction")
    dirButton.toolTip = isUnescape
      ? "Singleline → Multiline (click to switch)"
      : "Multiline → Singleline (click to switch)"
  }

  override func transform(_ input: String) -> (result: String, error: String?) {
    isUnescape
      ? (TextUtilsCore.unescapeToMultiline(input), nil)
      : (TextUtilsCore.escapeToSingleline(input), nil)
  }

  override func highlightResult(_ result: String, font: NSFont) -> NSAttributedString {
    isUnescape
      ? SyntaxHighlighter.plain(result, font: font)
      : SyntaxHighlighter.escaped(result, font: font)
  }
}

// JSON 格式化: 文本模式 + 树形模式 (视图切换按钮上交 tab 栏 accessory).
// 折叠状态: NSOutlineView 内建, 不持久化, 输入变即 reload.
// 性能: text 模式下**不构建 tree** (懒构建, treeDirty 标记); 切到 tree 时才 rebuild.
final class FormatJsonViewController: TextUtilsViewController {

  private var treeView: JsonTreeView?
  private var viewToggleButton: NSButton!
  private var lastParsed: Any?  // transform 阶段缓存, 供 tree 构建时免二次解析
  private var isTreeMode = false
  private var treeDirty = true  // 表示 tree 内容与 lastParsed 是否一致 (输入变 -> true)
  private var remoteJSONTask: Task<Void, Never>?
  private var remoteJSONKey: String?
  private var remoteJSONText: String?
  private var remoteJSONError: String?

  // text 模式渲染上限 (UTF-16 单位): 超出只染色渲染前缀预览, 全量走虚拟化树形视图.
  // NSTextView 同步布局 rich text 的开销随字符数线性增长, 6MB 达数秒会冻结主线程;
  // 512KB 前缀布局 < ~200ms (Release), 兼顾快照预览与响应性.
  private static let textRenderLimit = 512 * 1024

  init(tool: Tool) {
    super.init(
      tool: tool,
      placeholder: "Paste JSON, escaped JSON string, or JSON URL (e.g. https://example.com/data.json)...",
      resultDefaultText: "Enter JSON above to see the formatted result"
    )
  }
  required init?(coder: NSCoder) { fatalError() }

  override func transform(_ input: String) -> (result: String, error: String?) {
    if let url = TextUtilsCore.remoteJsonURL(from: input) {
      return transformRemoteJSON(from: url)
    }
    clearRemoteJSONState()
    let r = TextUtilsCore.formatJson(input)
    lastParsed = r.parsed
    return (r.result, r.error)
  }

  override func highlightResult(_ result: String, font: NSFont) -> NSAttributedString {
    if result.hasPrefix("Fetching JSON from ") {
      return SyntaxHighlighter.plain(result, font: font)
    }
    let count = result.utf16.count
    if count <= Self.textRenderLimit {
      return SyntaxHighlighter.json(result, font: font)
    }
    // 超大输出: 截断前缀预览 + 顶部提示切树形 (避免 NSTextView 同步布局多 MB rich text 冻结)
    let head = String(decoding: Array(result.utf16.prefix(Self.textRenderLimit)), as: UTF16.self)
    let sizeMB = Double(result.utf8.count) / 1_048_576
    let notice = String(
      format: "// Output is large (%.1f MB). Text view shows the first %d KB only.\n// Click the tree-view button (top-right) to browse / expand the full data — the tree renders virtualized with no lag.\n\n",
      sizeMB, Self.textRenderLimit / 1024)
    let out = NSMutableAttributedString(string: notice, attributes: [
      .font: font, .foregroundColor: NSColor.secondaryLabelColor,
    ])
    out.append(SyntaxHighlighter.json(head, font: font))
    return out
  }

  override func makeResultOverlay() -> NSView? {
    let v = JsonTreeView()
    treeView = v
    return v
  }

  override func makeAccessory() -> NSView? {
    let b = NSButton(title: "", target: self, action: #selector(toggleViewMode))
    b.bezelStyle = .texturedRounded
    b.imagePosition = .imageOnly
    b.translatesAutoresizingMaskIntoConstraints = false
    b.setContentHuggingPriority(.required, for: .horizontal)
    viewToggleButton = b
    updateViewToggleButton()
    return b
  }

  // 输入 / 结果变了 -> tree 数据过期; 若当前显示的是 tree 模式立刻 rebuild, 否则打标记等切模式再 rebuild
  override func didRefreshResult(text: String, error: String?) {
    if text.isEmpty && error == nil {
      lastParsed = nil
      clearRemoteJSONState()
    }
    treeDirty = true
    if isTreeMode { rebuildTreeIfNeeded() }
  }

  private func transformRemoteJSON(from url: URL) -> (result: String, error: String?) {
    let key = url.absoluteString
    if remoteJSONKey == key, let text = remoteJSONText {
      let r = TextUtilsCore.formatJson(text)
      lastParsed = r.parsed
      if let error = r.error {
        return ("", "Fetched response is not valid JSON: \(error)")
      }
      return (r.result, nil)
    }
    if remoteJSONKey == key, let error = remoteJSONError {
      lastParsed = nil
      return ("", error)
    }
    startRemoteJSONFetch(url: url, key: key)
    lastParsed = nil
    return ("Fetching JSON from \(key)...", nil)
  }

  private func startRemoteJSONFetch(url: URL, key: String) {
    if remoteJSONKey == key, remoteJSONTask != nil, remoteJSONText == nil, remoteJSONError == nil { return }
    remoteJSONTask?.cancel()
    remoteJSONKey = key
    remoteJSONText = nil
    remoteJSONError = nil
    remoteJSONTask = Task { [weak self] in
      do {
        let text = try await RemoteJSONFetcher.fetchText(from: url)
        guard !Task.isCancelled else { return }
        await MainActor.run {
          guard self?.remoteJSONKey == key else { return }
          self?.remoteJSONText = text
          self?.remoteJSONError = nil
          self?.remoteJSONTask = nil
          self?.reloadResult()
        }
      } catch is CancellationError {
      } catch {
        guard !Task.isCancelled else { return }
        await MainActor.run {
          guard self?.remoteJSONKey == key else { return }
          self?.remoteJSONText = nil
          self?.remoteJSONError = "Fetch failed: \(error.localizedDescription)"
          self?.remoteJSONTask = nil
          self?.reloadResult()
        }
      }
    }
  }

  private func clearRemoteJSONState() {
    remoteJSONTask?.cancel()
    remoteJSONTask = nil
    remoteJSONKey = nil
    remoteJSONText = nil
    remoteJSONError = nil
  }

  private func rebuildTreeIfNeeded() {
    guard treeDirty, let treeView else { return }
    if let parsed = lastParsed {
      treeView.setRoot(JsonNodeBuilder.build(from: parsed))
    } else {
      treeView.clear()
    }
    treeDirty = false
  }

  @objc private func toggleViewMode() {
    isTreeMode.toggle()
    if isTreeMode { rebuildTreeIfNeeded() }  // 懒构建: 切到 tree 时才构建过期数据
    setResultOverlayHidden(!isTreeMode)
    updateViewToggleButton()
    if isTreeMode { treeView?.focusOutline() }
  }

  private func updateViewToggleButton() {
    // 当前是文本 -> 显 tree 图标 (点击切到 tree); 当前是 tree -> 显 text 图标
    let symbol = isTreeMode ? "text.alignleft" : "list.triangle"
    viewToggleButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Toggle view mode")
    viewToggleButton.toolTip = isTreeMode
      ? "Switch to text view"
      : "Switch to tree view (expand / collapse)"
  }
}

enum RemoteJSONFetcher {
  private static let maxBytes = 50 * 1024 * 1024
  private static let timeout: TimeInterval = 30

  nonisolated static func fetchText(from url: URL, session: URLSession = .shared) async throws -> String {
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
    request.setValue("application/json, text/json, */*;q=0.1", forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw FetchError.httpStatus(http.statusCode)
    }
    guard data.count <= maxBytes else { throw FetchError.tooLarge(maxBytes) }
    guard let text = String(data: data, encoding: .utf8) else { throw FetchError.nonUTF8 }
    return text
  }

  private enum FetchError: LocalizedError {
    case httpStatus(Int)
    case tooLarge(Int)
    case nonUTF8

    var errorDescription: String? {
      switch self {
      case .httpStatus(let code): return "HTTP \(code)"
      case .tooLarge(let maxBytes): return "response is larger than \(maxBytes / 1024 / 1024) MB"
      case .nonUTF8: return "response is not UTF-8 text"
      }
    }
  }
}
