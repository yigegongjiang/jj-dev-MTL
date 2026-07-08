import Cocoa

// 子 VC 把自己的操作控件交给顶部 tab 栏右侧展示; 内容变化时经 host 通知刷新.
protocol ToolbarAccessoryHost: AnyObject {
  func reloadToolbarAccessories()
}

protocol ToolbarAccessoryProviding: AnyObject {
  var toolbarAccessories: [NSView] { get }
  var accessoryHost: ToolbarAccessoryHost? { get set }
}

// 顶部单行导航 (无 sidebar): 左侧 tab (文本工具 + Codecs 各模块平铺 + Settings), 右侧当前工具操作控件.
// 数字键 1-N (非编辑态) 切 tab; 内容区铺满窗口, 尽量留空间给用户.
final class RootTabViewController: NSViewController, ToolbarAccessoryHost {

  private enum Target {
    case json
    case escape
    case codec(Int)   // CodecToolkitViewController 内部模块索引 (0..4)
    case settings
  }

  private let tabs: [(title: String, target: Target)] = [
    ("Format JSON", .json),
    ("Multiline ⇄ Singleline", .escape),
    ("Timestamp", .codec(0)),
    ("URL", .codec(1)),
    ("Base64", .codec(2)),
    ("JWT", .codec(3)),
    ("QR Code", .codec(4)),
    ("Settings", .settings),
  ]

  private var tabControl: NSSegmentedControl!
  private let accessoryStack = NSStackView()
  private let contentView = NSView()
  private var current: NSViewController?
  private var keyMonitor: Any?

  // 懒加载复用子 VC (切 tab 不重建, 保留各自输入/状态)
  private lazy var jsonVC = FormatJsonViewController(tool: Tool(id: "json-formatter", title: "Format JSON"))
  private lazy var escapeVC = EscapeUnescapeViewController(tool: Tool(id: "text-escape-unescape", title: "Multiline ⇄ Singleline"))
  private lazy var codecVC = CodecToolkitViewController(tool: Tool(id: "codec-toolkit", title: "Codecs / Tokens"))
  private lazy var settingsVC = SettingsViewController()

  override func loadView() {
    let root = NSView()
    root.translatesAutoresizingMaskIntoConstraints = false

    // tab 标签前缀数字, 提示对应快捷键 (数字键 1-N 直切)
    let labels = tabs.enumerated().map { "\($0.offset + 1)  \($0.element.title)" }
    tabControl = NSSegmentedControl(
      labels: labels,
      trackingMode: .selectOne,
      target: self,
      action: #selector(changeTab))
    tabControl.translatesAutoresizingMaskIntoConstraints = false
    tabControl.segmentStyle = .rounded
    tabControl.selectedSegment = 0
    tabControl.setContentHuggingPriority(.defaultHigh, for: .horizontal)

    accessoryStack.translatesAutoresizingMaskIntoConstraints = false
    accessoryStack.orientation = .horizontal
    accessoryStack.alignment = .centerY
    accessoryStack.spacing = 8
    accessoryStack.setContentHuggingPriority(.required, for: .horizontal)
    accessoryStack.setContentCompressionResistancePriority(.required, for: .horizontal)

    contentView.translatesAutoresizingMaskIntoConstraints = false

    root.addSubview(tabControl)
    root.addSubview(accessoryStack)
    root.addSubview(contentView)

    NSLayoutConstraint.activate([
      tabControl.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor, constant: 8),
      tabControl.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),

      accessoryStack.centerYAnchor.constraint(equalTo: tabControl.centerYAnchor),
      accessoryStack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
      accessoryStack.leadingAnchor.constraint(greaterThanOrEqualTo: tabControl.trailingAnchor, constant: 12),

      contentView.topAnchor.constraint(equalTo: tabControl.bottomAnchor, constant: 8),
      contentView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
    ])

    self.view = root
    select(0)
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    // 启动后焦点不落输入框, 否则数字键被输入框吞掉, tab 快捷键失效
    view.window?.makeFirstResponder(nil)
    if keyMonitor == nil {
      keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        self?.handleDigitKey(event) ?? event
      }
    }
  }

  deinit {
    if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
  }

  @objc private func changeTab() {
    select(tabControl.selectedSegment)
  }

  private func select(_ index: Int) {
    guard tabs.indices.contains(index) else { return }
    tabControl.selectedSegment = index
    switch tabs[index].target {
    case .json:
      swap(to: jsonVC)
      reloadToolbarAccessories()
    case .escape:
      swap(to: escapeVC)
      reloadToolbarAccessories()
    case .codec(let module):
      swap(to: codecVC)
      codecVC.selectModule(module)   // 内部 showModule 后经 host 回调刷新 accessory
    case .settings:
      swap(to: settingsVC)
      reloadToolbarAccessories()
    }
    // 输入为空则探查剪贴板填入 (打开即用); 随后清焦, 保数字键切 tab 生效
    (current as? TextUtilsViewController)?.activateInput()
    view.window?.makeFirstResponder(nil)
  }

  // MARK: - ToolbarAccessoryHost

  func reloadToolbarAccessories() {
    for v in accessoryStack.arrangedSubviews {
      accessoryStack.removeArrangedSubview(v)
      v.removeFromSuperview()
    }
    guard let provider = current as? ToolbarAccessoryProviding else { return }
    for v in provider.toolbarAccessories {
      accessoryStack.addArrangedSubview(v)
    }
  }

  // 非输入框聚焦时, 数字键 1-N 切对应 tab
  private func handleDigitKey(_ event: NSEvent) -> NSEvent? {
    guard event.window === view.window,
      event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
      let chars = event.charactersIgnoringModifiers, chars.count == 1,
      let n = Int(chars), n >= 1, n <= tabs.count
    else { return event }
    // 正在编辑文本 -> 放行, 让数字进入输入框
    if let tv = view.window?.firstResponder as? NSTextView, tv.isEditable {
      return event
    }
    select(n - 1)
    return nil
  }

  private func swap(to next: NSViewController) {
    guard next !== current else { return }
    if let current {
      (current as? TextUtilsViewController)?.snapshotHistory()  // 切走前把当前输入并入历史
      current.view.removeFromSuperview()
      current.removeFromParent()
    }
    addChild(next)
    (next as? ToolbarAccessoryProviding)?.accessoryHost = self
    next.view.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(next.view)
    NSLayoutConstraint.activate([
      next.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      next.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      next.view.topAnchor.constraint(equalTo: contentView.topAnchor),
      next.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    ])
    current = next
  }
}
