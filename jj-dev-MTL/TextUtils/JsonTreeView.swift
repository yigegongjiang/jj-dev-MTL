import Cocoa

// JSON 树视图: NSOutlineView 单列, 按对象/数组结构展开折叠. 用于 Format JSON 的可视化视图模式.
// 高性能要点:
//   - 节点是 class -> NSOutlineView item 引用相等, 无需自制 identifier map
//   - displayLine 懒生成 + 缓存: 构树阶段不产生任何 NSAttributedString, 只有 cell 可见才 build (大 JSON 关键)
//   - 完全不监听 itemDidExpand/Collapse 通知 -> 递归展开时 0 额外开销 (避免 O(N²) 卡死)
//   - 固定行高 + Cell 复用池 + 无 alternating background
//   - 大 JSON (节点数 > threshold) 只展根一层, 深层由用户按需展开, 避免主线程冻结
//   - 折叠状态由 outline 内建维护, 输入变即 reloadData 重置, 不持久化

// MARK: - Node

// 引用相等 -> NSOutlineView 天然按 pointer identity 跟踪展开状态
final class JsonNode {
  enum Kind { case object, array, string, number, bool, null }

  let kind: Kind
  let key: String?           // nil = 数组元素 / 根 / close marker
  let children: [JsonNode]   // 非空容器末尾追加 closeMarker 用于展示闭合括号
  let raw: Any               // 原始值 (JSONSerialization 结果), ⌘C 复制时按 pretty JSON 序列化
  let containerCount: Int    // 容器长度 (leaf 无意义, close marker = 0)
  let isCloseMarker: Bool    // 虚拟节点: 展开态末尾的闭合 "}" / "]" 一行, 不计入 copy

  private var cachedLine: NSAttributedString?

  // 懒生成 + 缓存 -> 首次 cell 显示时才 build; 16 万节点的大 JSON 构树阶段 0 attr string 开销
  var displayLine: NSAttributedString {
    if let c = cachedLine { return c }
    let s = JsonNodeBuilder.makeLine(for: self)
    cachedLine = s
    return s
  }

  var isContainer: Bool { kind == .object || kind == .array }
  var canExpand: Bool { isContainer && !isCloseMarker && !children.isEmpty }

  init(kind: Kind, key: String?, children: [JsonNode], raw: Any,
       containerCount: Int = 0, isCloseMarker: Bool = false) {
    self.kind = kind
    self.key = key
    self.children = children
    self.raw = raw
    self.containerCount = containerCount
    self.isCloseMarker = isCloseMarker
  }
}

// 递归构建 node 树; 对象 keys 用字典序排, 与文本模式 (JSONSerialization .sortedKeys) 完全一致.
// 构树阶段只做结构, 不生成任何 NSAttributedString (由 JsonNode.displayLine 懒生成).
enum JsonNodeBuilder {
  static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

  static func build(from raw: Any) -> JsonNode {
    node(from: raw, key: nil)
  }

  // 遍历统计节点总数 (含 closeMarker), 供上层决策是否递归全展开
  static func totalNodes(_ node: JsonNode) -> Int {
    1 + node.children.reduce(0) { $0 + totalNodes($1) }
  }

  private static func node(from raw: Any, key: String?) -> JsonNode {
    if raw is NSNull { return JsonNode(kind: .null, key: key, children: [], raw: raw) }
    if let n = raw as? NSNumber {
      // NSNumber 里 Bool 需 CFBoolean 判别, 否则 true/false 会被当作 1/0 数字
      let k: JsonNode.Kind = (CFGetTypeID(n) == CFBooleanGetTypeID()) ? .bool : .number
      return JsonNode(kind: k, key: key, children: [], raw: raw)
    }
    if raw is String { return JsonNode(kind: .string, key: key, children: [], raw: raw) }
    if let arr = raw as? [Any] {
      var children = arr.map { node(from: $0, key: nil) }
      if !children.isEmpty { children.append(closeMarker(kind: .array)) }
      return JsonNode(kind: .array, key: key, children: children, raw: raw,
                      containerCount: arr.count)
    }
    if let dict = raw as? [String: Any] {
      let keys = dict.keys.sorted()
      var children = keys.map { k in node(from: dict[k] as Any, key: k) }
      if !children.isEmpty { children.append(closeMarker(kind: .object)) }
      return JsonNode(kind: .object, key: key, children: children, raw: raw,
                      containerCount: keys.count)
    }
    // 兜底
    return JsonNode(kind: .string, key: key, children: [], raw: raw)
  }

  // 闭合括号虚拟节点: raw 存 NSNull(), 显示由 makeLine 生成 "}" / "]"
  private static func closeMarker(kind: JsonNode.Kind) -> JsonNode {
    JsonNode(kind: kind, key: nil, children: [], raw: NSNull(), isCloseMarker: true)
  }

  // 懒生成: cell 首次显示时按 node kind 生成完整 attributed 行
  static func makeLine(for node: JsonNode) -> NSAttributedString {
    if node.isCloseMarker {
      let ch = node.kind == .array ? "]" : "}"
      return styled(ch, .punct)
    }
    let line = NSMutableAttributedString()
    appendKey(line, node.key)
    switch node.kind {
    case .null: line.append(styled("null", .keyword))
    case .bool:
      let b = (node.raw as? NSNumber)?.boolValue ?? false
      line.append(styled(b ? "true" : "false", .keyword))
    case .number:
      let s = (node.raw as? NSNumber)?.stringValue ?? "0"
      line.append(styled(s, .number))
    case .string:
      let s = (node.raw as? String) ?? ""
      line.append(styled(TextUtilsCore.escapeToSingleline(s), .string))
    case .object:
      line.append(styled(node.containerCount == 0 ? "{}" : "{", .punct))
    case .array:
      line.append(styled(node.containerCount == 0 ? "[]" : "[", .punct))
    }
    return line
  }

  private static func appendKey(_ line: NSMutableAttributedString, _ key: String?) {
    guard let key else { return }
    line.append(styled(TextUtilsCore.escapeToSingleline(key), .key))
    line.append(styled(": ", .punct))
  }

  // MARK: - 样式辅助

  private enum Style { case key, string, number, keyword, punct }

  private static func styled(_ s: String, _ style: Style) -> NSAttributedString {
    let color: NSColor
    switch style {
    case .key: color = SyntaxHighlighter.keyColor
    case .string: color = SyntaxHighlighter.stringColor
    case .number: color = SyntaxHighlighter.numberColor
    case .keyword: color = SyntaxHighlighter.keywordColor
    case .punct: color = SyntaxHighlighter.punctuationColor
    }
    return NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
  }
}

// MARK: - Outline View (支持 ⌘C)

final class JsonOutlineView: NSOutlineView {
  var copyHandler: (() -> Void)?

  override func keyDown(with event: NSEvent) {
    // ⌘C -> 委外处理; 其他键 (含 ← / → 展开折叠, 上下移动) 走 NSOutlineView 默认
    if event.modifierFlags.contains(.command),
       event.charactersIgnoringModifiers?.lowercased() == "c" {
      copyHandler?()
      return
    }
    super.keyDown(with: event)
  }
}

// MARK: - JsonTreeView

final class JsonTreeView: NSView {

  private let outlineView = JsonOutlineView()
  private let scrollView = NSScrollView()
  private var root: JsonNode?
  private let cellID = NSUserInterfaceItemIdentifier("JsonTreeCell")

  // 大 JSON 保护: 节点数超阈值时只展根一层, 避免 expandItem(nil, expandChildren: true) 卡主线程
  private static let autoExpandNodeLimit = 3000

  override init(frame: NSRect) {
    super.init(frame: frame)
    translatesAutoresizingMaskIntoConstraints = false
    setup()
  }
  required init?(coder: NSCoder) { fatalError() }

  private func setup() {
    outlineView.headerView = nil
    outlineView.usesAutomaticRowHeights = false
    outlineView.rowHeight = 20
    outlineView.intercellSpacing = NSSize(width: 0, height: 0)
    outlineView.indentationPerLevel = 14
    outlineView.autoresizesOutlineColumn = false
    outlineView.selectionHighlightStyle = .regular
    outlineView.allowsMultipleSelection = true
    outlineView.usesAlternatingRowBackgroundColors = false
    outlineView.backgroundColor = .textBackgroundColor
    outlineView.gridStyleMask = []
    outlineView.style = .plain
    outlineView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
    outlineView.target = self
    outlineView.doubleAction = #selector(toggleDoubleClicked)

    let col = NSTableColumn(identifier: cellID)
    col.resizingMask = .autoresizingMask
    col.minWidth = 80
    col.width = 800
    outlineView.addTableColumn(col)
    outlineView.outlineTableColumn = col

    outlineView.dataSource = self
    outlineView.delegate = self
    outlineView.copyHandler = { [weak self] in self?.copySelectionToPasteboard() }

    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.borderType = .lineBorder
    scrollView.drawsBackground = true
    scrollView.backgroundColor = .textBackgroundColor
    scrollView.documentView = outlineView

    addSubview(scrollView)
    NSLayoutConstraint.activate([
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  // 输入变化 -> 重设根 -> reloadData -> 全展开 (小 JSON) 或 只展根一层 (大 JSON, 手动逐层展开)
  func setRoot(_ node: JsonNode?) {
    self.root = node
    outlineView.reloadData()
    guard let node = node else { return }
    let total = JsonNodeBuilder.totalNodes(node)
    if total <= Self.autoExpandNodeLimit {
      outlineView.expandItem(nil, expandChildren: true)  // 全展开与文本视图一致
    } else if node.canExpand {
      outlineView.expandItem(node)                        // 大 JSON 仅展根, 深层由用户按需
    }
  }

  func clear() { setRoot(nil) }

  // 让 firstResponder 落在 outlineView 上 (由外部在切到 tree 模式后调用)
  func focusOutline() {
    window?.makeFirstResponder(outlineView)
  }

  @objc private func toggleDoubleClicked() {
    let row = outlineView.clickedRow
    guard row >= 0, let item = outlineView.item(atRow: row) as? JsonNode, item.canExpand else { return }
    if outlineView.isItemExpanded(item) {
      outlineView.collapseItem(item)
    } else {
      outlineView.expandItem(item)
    }
  }

  // MARK: - 复制

  // 单选 -> 该节点序列化; 多选 -> 数组包装. 均 pretty print, 与文本模式一致
  private func copySelectionToPasteboard() {
    let rows = outlineView.selectedRowIndexes
    guard !rows.isEmpty else { return }
    let nodes = rows.compactMap { outlineView.item(atRow: $0) as? JsonNode }
      .filter { !$0.isCloseMarker }
    guard !nodes.isEmpty else { return }

    let opts: JSONSerialization.WritingOptions = [
      .prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed,
    ]
    let payload: Any = nodes.count == 1 ? nodes[0].raw : nodes.map { $0.raw }
    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: opts),
          let text = String(data: data, encoding: .utf8) else { return }

    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(text, forType: .string)
  }
}

// MARK: - Data Source

extension JsonTreeView: NSOutlineViewDataSource {
  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    if item == nil { return root == nil ? 0 : 1 }  // 顶层唯一根
    return (item as? JsonNode)?.children.count ?? 0
  }

  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    if item == nil { return root! }
    return (item as! JsonNode).children[index]
  }

  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    (item as? JsonNode)?.canExpand ?? false
  }
}

// MARK: - Delegate

extension JsonTreeView: NSOutlineViewDelegate {
  func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?,
                   item: Any) -> NSView? {
    guard let node = item as? JsonNode else { return nil }
    let cell = outlineView.makeView(withIdentifier: cellID, owner: self) as? JsonTreeCellView
      ?? makeCell()
    cell.textField?.attributedStringValue = node.displayLine
    // 闭合括号行 负向偏移一级缩进 -> 视觉与父行开括号同列
    cell.leadingConst.constant = node.isCloseMarker
      ? 2 - outlineView.indentationPerLevel
      : 2
    return cell
  }

  private func makeCell() -> JsonTreeCellView {
    let cell = JsonTreeCellView()
    cell.identifier = cellID
    let tf = NSTextField(labelWithString: "")
    tf.translatesAutoresizingMaskIntoConstraints = false
    tf.font = JsonNodeBuilder.font
    tf.lineBreakMode = .byTruncatingTail
    tf.isBezeled = false
    tf.drawsBackground = false
    tf.isEditable = false
    tf.isSelectable = false
    tf.usesSingleLineMode = true
    cell.addSubview(tf)
    cell.textField = tf
    let lead = tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2)
    lead.isActive = true
    cell.leadingConst = lead
    NSLayoutConstraint.activate([
      tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
      tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
    ])
    return cell
  }
}

// 保存 textField 的 leading constraint 供闭合括号行负偏移
final class JsonTreeCellView: NSTableCellView {
  var leadingConst: NSLayoutConstraint!
}
