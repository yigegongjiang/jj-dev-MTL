import Cocoa
import UniformTypeIdentifiers

// Codecs / Tokens: 各模块 (Timestamp/URL/Base64/JWT/QR) 平铺为顶部 tab, 由 RootTabViewController 通过 selectModule 驱动.
// 各模块的操作控件 (icon button / 分段控件) 上交顶部 tab 栏右侧 (toolbarAccessories); 内容区只放输入/输出/图片.
final class CodecToolkitViewController: NSViewController, NSTextViewDelegate, ToolbarAccessoryProviding {

  private enum Module: Int {
    case timestamp, url, base64, jwt, qr
  }

  private enum Base64Mode: Int {
    case text, image
  }

  weak var accessoryHost: ToolbarAccessoryHost?
  private var currentModule: Module = .timestamp
  private var currentBase64Mode: Base64Mode = .text

  private var contentView: NSView!
  private var moduleViews: [Int: NSView] = [:]

  private var nowButton: NSButton!
  private var timestampInput: NSTextView!
  private var timestampOutput: NSTextView!

  private var urlMode: NSSegmentedControl!
  private var urlInput: NSTextView!
  private var urlOutput: NSTextView!

  private var base64Mode: NSSegmentedControl!
  private var base64Content: NSView!
  private var base64Views: [Int: NSView] = [:]
  private var base64TextMode: NSSegmentedControl!
  private var base64TextInput: NSTextView!
  private var base64TextOutput: NSTextView!
  private var base64ImageButtons: [NSView] = []
  private var base64ImageText: NSTextView!
  private var base64ImageView: NSImageView!
  private var base64ImageStatus: NSTextField!

  private var jwtInput: NSTextView!
  private var jwtOutput: NSTextView!

  private var qrButtons: [NSView] = []
  private var qrInput: NSTextView!
  private var qrImageView: NSImageView!
  private var qrStatus: NSTextField!
  private var currentQRImage: NSImage?

  init(tool: Tool) {
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError() }

  override func loadView() {
    let root = NSView()
    root.translatesAutoresizingMaskIntoConstraints = false

    contentView = NSView()
    contentView.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(contentView)

    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor, constant: 6),
      contentView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
      contentView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
      contentView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
    ])

    view = root
    showModule(.timestamp)
  }

  // MARK: - 顶部 tab 驱动

  // 供 RootTabViewController 从顶部 tab 切模块
  func selectModule(_ index: Int) {
    guard let module = Module(rawValue: index) else { return }
    currentModule = module
    showModule(module)
    accessoryHost?.reloadToolbarAccessories()
  }

  // 当前模块交给顶部栏右侧的操作控件
  var toolbarAccessories: [NSView] {
    switch currentModule {
    case .timestamp: return [nowButton]
    case .url: return [urlMode]
    case .base64:
      return [base64Mode] + (currentBase64Mode == .text ? [base64TextMode] : base64ImageButtons)
    case .jwt: return []
    case .qr: return qrButtons
    }
  }

  func textDidChange(_ notification: Notification) {
    guard let tv = notification.object as? NSTextView else { return }
    switch tv {
    case timestampInput: refreshTimestamp()
    case urlInput: refreshURL()
    case base64TextInput: refreshBase64Text()
    case base64ImageText: refreshBase64Image()
    case jwtInput: refreshJWT()
    case qrInput: refreshQRCode()
    default: break
    }
  }

  private func showModule(_ module: Module) {
    let key = module.rawValue
    if moduleViews[key] == nil {
      let next = makeModule(module)
      next.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(next)
      NSLayoutConstraint.activate([
        next.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        next.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        next.topAnchor.constraint(equalTo: contentView.topAnchor),
        next.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      ])
      moduleViews[key] = next
    }
    moduleViews.forEach { $0.value.isHidden = $0.key != key }
  }

  private func makeModule(_ module: Module) -> NSView {
    switch module {
    case .timestamp: return makeTimestampModule()
    case .url: return makeURLModule()
    case .base64: return makeBase64Module()
    case .jwt: return makeJWTModule()
    case .qr: return makeQRModule()
    }
  }

  private func makeTimestampModule() -> NSView {
    nowButton = iconButton(symbol: "clock.arrow.circlepath", toolTip: "Use current time", action: #selector(fillCurrentTimestamp))
    let split = textSplit(
      inputPlaceholder: "Unix seconds / milliseconds / microseconds / ISO datetime",
      outputPlaceholder: nil,
      input: &timestampInput,
      output: &timestampOutput)
    timestampInput.delegate = self
    timestampInput.string = "\(Int(Date().timeIntervalSince1970))"

    let panel = fixedHeightPanel(body: split, bodyHeight: 190)
    refreshTimestamp()
    return panel
  }

  private func makeURLModule() -> NSView {
    urlMode = segment(labels: ["Encode", "Decode"], action: #selector(refreshURLAction))
    let split = textSplit(
      inputPlaceholder: "URL text",
      outputPlaceholder: nil,
      input: &urlInput,
      output: &urlOutput)
    urlInput.delegate = self
    return fixedHeightPanel(body: split, bodyHeight: 240)
  }

  private func makeBase64Module() -> NSView {
    base64Mode = segment(labels: ["Text", "Image"], action: #selector(changeBase64Mode))
    base64Content = NSView()
    base64Content.translatesAutoresizingMaskIntoConstraints = false
    let panel = fixedHeightPanel(body: base64Content, bodyHeight: 380)
    showBase64Mode(.text)
    return panel
  }

  private func makeJWTModule() -> NSView {
    let split = textSplit(
      inputPlaceholder: "JWT",
      outputPlaceholder: nil,
      input: &jwtInput,
      output: &jwtOutput)
    jwtInput.delegate = self
    return fixedHeightPanel(body: split, bodyHeight: 420)
  }

  private func makeQRModule() -> NSView {
    let openButton = iconButton(symbol: "folder", toolTip: "Open QR image", action: #selector(openQRImage))
    let pasteButton = iconButton(symbol: "clipboard", toolTip: "Paste QR image", action: #selector(pasteQRImage))
    let copyButton = iconButton(symbol: "qrcode", toolTip: "Copy generated QR PNG", action: #selector(copyQRCodePNG))
    qrButtons = [openButton, pasteButton, copyButton]

    qrStatus = statusLabel()
    let input = textArea(editable: true, placeholder: "Text to generate QR")
    qrInput = input.textView
    qrInput.delegate = self

    qrImageView = imageView(side: 260)
    let body = twoColumn(left: input.scrollView, right: imageColumn(qrImageView, status: qrStatus), rightWidth: 260)
    return fixedHeightPanel(body: body, bodyHeight: 300)
  }

  @objc private func fillCurrentTimestamp() {
    timestampInput.string = "\(Int(Date().timeIntervalSince1970))"
    refreshTimestamp()
  }

  private func refreshTimestamp() {
    set(timestampOutput, CodecToolkitCore.convertTimestampOrDate(timestampInput.string))
  }

  @objc private func refreshURLAction() { refreshURL() }

  private func refreshURL() {
    guard !urlInput.string.isEmpty else { set(urlOutput, text: ""); return }
    let result = urlMode.selectedSegment == 0
      ? CodecToolkitCore.encodeURLComponent(urlInput.string)
      : CodecToolkitCore.decodeURLComponent(urlInput.string)
    set(urlOutput, result)
  }

  @objc private func changeBase64Mode() {
    guard let mode = Base64Mode(rawValue: base64Mode.selectedSegment) else { return }
    currentBase64Mode = mode
    showBase64Mode(mode)
    accessoryHost?.reloadToolbarAccessories()
  }

  private func showBase64Mode(_ mode: Base64Mode) {
    let key = mode.rawValue
    if base64Views[key] == nil {
      let next = mode == .text ? makeBase64TextView() : makeBase64ImageView()
      next.translatesAutoresizingMaskIntoConstraints = false
      base64Content.addSubview(next)
      NSLayoutConstraint.activate([
        next.leadingAnchor.constraint(equalTo: base64Content.leadingAnchor),
        next.trailingAnchor.constraint(equalTo: base64Content.trailingAnchor),
        next.topAnchor.constraint(equalTo: base64Content.topAnchor),
        next.bottomAnchor.constraint(equalTo: base64Content.bottomAnchor),
      ])
      base64Views[key] = next
    }
    base64Views.forEach { $0.value.isHidden = $0.key != key }
  }

  private func makeBase64TextView() -> NSView {
    base64TextMode = segment(labels: ["Encode", "Decode"], action: #selector(refreshBase64TextAction))
    let split = textSplit(
      inputPlaceholder: "Text or Base64",
      outputPlaceholder: nil,
      input: &base64TextInput,
      output: &base64TextOutput)
    base64TextInput.delegate = self
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false
    split.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(split)
    NSLayoutConstraint.activate([
      split.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      split.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      split.topAnchor.constraint(equalTo: container.topAnchor),
      split.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    return container
  }

  private func makeBase64ImageView() -> NSView {
    let openButton = iconButton(symbol: "folder", toolTip: "Open image", action: #selector(openBase64Image))
    let pasteButton = iconButton(symbol: "clipboard", toolTip: "Paste image or Base64", action: #selector(pasteBase64Image))
    let copyButton = iconButton(symbol: "doc.on.doc", toolTip: "Copy Base64", action: #selector(copyBase64Image))
    base64ImageButtons = [openButton, pasteButton, copyButton]

    base64ImageStatus = statusLabel()
    let text = textArea(editable: true, placeholder: "Image Base64 or data URI")
    base64ImageText = text.textView
    base64ImageText.delegate = self
    base64ImageView = imageView(side: 260)

    return twoColumn(left: text.scrollView, right: imageColumn(base64ImageView, status: base64ImageStatus), rightWidth: 260)
  }

  @objc private func refreshBase64TextAction() { refreshBase64Text() }

  private func refreshBase64Text() {
    guard !base64TextInput.string.isEmpty else { set(base64TextOutput, text: ""); return }
    if base64TextMode.selectedSegment == 0 {
      set(base64TextOutput, text: CodecToolkitCore.encodeBase64Text(base64TextInput.string))
    } else {
      set(base64TextOutput, CodecToolkitCore.decodeBase64Text(base64TextInput.string))
    }
  }

  private func refreshBase64Image() {
    let raw = base64ImageText.string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else {
      base64ImageView.image = nil
      base64ImageStatus.stringValue = ""
      return
    }
    guard let data = CodecToolkitCore.decodeBase64Data(raw), let image = NSImage(data: data) else {
      base64ImageView.image = nil
      base64ImageStatus.textColor = .systemRed
      base64ImageStatus.stringValue = "Invalid image Base64"
      return
    }
    base64ImageView.image = image
    base64ImageStatus.textColor = .secondaryLabelColor
    base64ImageStatus.stringValue = "\(Int(image.size.width))x\(Int(image.size.height)) pt, \(data.count) bytes"
  }

  @objc private func openBase64Image() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
    base64ImageText.string = CodecToolkitCore.dataURI(mime: mimeType(for: url), data: data)
    refreshBase64Image()
  }

  @objc private func pasteBase64Image() {
    let pb = NSPasteboard.general
    if let image = NSImage(pasteboard: pb), let data = QRCodeEngine.pngData(from: image) {
      base64ImageText.string = CodecToolkitCore.dataURI(mime: "image/png", data: data)
    } else if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
      let url = urls.first,
      let data = try? Data(contentsOf: url) {
      base64ImageText.string = CodecToolkitCore.dataURI(mime: mimeType(for: url), data: data)
    } else if let text = pb.string(forType: .string) {
      base64ImageText.string = text
    }
    refreshBase64Image()
  }

  @objc private func copyBase64Image() {
    guard !base64ImageText.string.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(base64ImageText.string, forType: .string)
  }

  private func refreshJWT() {
    guard !jwtInput.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      set(jwtOutput, text: "")
      return
    }
    set(jwtOutput, CodecToolkitCore.decodeJWT(jwtInput.string))
  }

  private func refreshQRCode() {
    let text = qrInput.string
    guard !text.isEmpty else {
      currentQRImage = nil
      qrImageView.image = nil
      qrStatus.stringValue = ""
      return
    }
    guard let image = QRCodeEngine.makeQRCodeImage(text: text, side: 260) else {
      currentQRImage = nil
      qrImageView.image = nil
      qrStatus.textColor = .systemRed
      qrStatus.stringValue = "QR generation failed"
      return
    }
    currentQRImage = image
    qrImageView.image = image
    qrStatus.textColor = .secondaryLabelColor
    qrStatus.stringValue = "Generated"
  }

  @objc private func openQRImage() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
    decodeQRImage(image)
  }

  @objc private func pasteQRImage() {
    guard let image = NSImage(pasteboard: NSPasteboard.general) else { return }
    decodeQRImage(image)
  }

  @objc private func copyQRCodePNG() {
    guard let image = currentQRImage, let data = QRCodeEngine.pngData(from: image) else { return }
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setData(data, forType: .png)
    pb.writeObjects([image])
  }

  private func decodeQRImage(_ image: NSImage) {
    currentQRImage = image
    qrImageView.image = image
    let messages = QRCodeEngine.decodeQRCode(from: image)
    if messages.isEmpty {
      qrStatus.textColor = .systemRed
      qrStatus.stringValue = "No QR code found"
    } else {
      qrInput.string = messages.joined(separator: "\n")
      qrStatus.textColor = .secondaryLabelColor
      qrStatus.stringValue = "Decoded QR image"
    }
  }

  // MARK: - 构件

  // 固定高度面板: body 顶对齐, 其余留白 (无顶部控件, 控件已上交顶部栏)
  private func fixedHeightPanel(body: NSView, bodyHeight: CGFloat) -> NSView {
    let panel = NSView()
    panel.translatesAutoresizingMaskIntoConstraints = false
    body.translatesAutoresizingMaskIntoConstraints = false
    panel.addSubview(body)
    NSLayoutConstraint.activate([
      body.topAnchor.constraint(equalTo: panel.topAnchor),
      body.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
      body.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
      body.heightAnchor.constraint(equalToConstant: bodyHeight),
      body.bottomAnchor.constraint(lessThanOrEqualTo: panel.bottomAnchor),
    ])
    return panel
  }

  private func textSplit(
    inputPlaceholder: String,
    outputPlaceholder: String?,
    input: inout NSTextView!,
    output: inout NSTextView!
  ) -> NSView {
    let left = textArea(editable: true, placeholder: inputPlaceholder)
    let right = textArea(editable: false, placeholder: outputPlaceholder)
    input = left.textView
    output = right.textView
    return twoColumn(left: left.scrollView, right: right.scrollView, rightWidth: nil)
  }

  private func twoColumn(left: NSView, right: NSView, rightWidth: CGFloat?) -> NSView {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false
    left.translatesAutoresizingMaskIntoConstraints = false
    right.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(left)
    container.addSubview(right)

    var constraints = [
      left.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      left.topAnchor.constraint(equalTo: container.topAnchor),
      left.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      right.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: 12),
      right.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      right.topAnchor.constraint(equalTo: container.topAnchor),
      left.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),
    ]
    if let rightWidth {
      constraints.append(right.widthAnchor.constraint(equalToConstant: rightWidth))
      constraints.append(right.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor))
    } else {
      constraints.append(left.widthAnchor.constraint(equalTo: right.widthAnchor))
      constraints.append(right.bottomAnchor.constraint(equalTo: container.bottomAnchor))
    }
    NSLayoutConstraint.activate(constraints)
    return container
  }

  // 图片列: 图片 + 其下状态标签 (状态不占顶部栏, 放在图片下方)
  private func imageColumn(_ image: NSImageView, status: NSTextField) -> NSView {
    let column = NSView()
    column.translatesAutoresizingMaskIntoConstraints = false
    image.translatesAutoresizingMaskIntoConstraints = false
    status.translatesAutoresizingMaskIntoConstraints = false
    column.addSubview(image)
    column.addSubview(status)
    NSLayoutConstraint.activate([
      image.topAnchor.constraint(equalTo: column.topAnchor),
      image.leadingAnchor.constraint(equalTo: column.leadingAnchor),
      image.trailingAnchor.constraint(equalTo: column.trailingAnchor),
      status.topAnchor.constraint(equalTo: image.bottomAnchor, constant: 6),
      status.leadingAnchor.constraint(equalTo: column.leadingAnchor),
      status.trailingAnchor.constraint(equalTo: column.trailingAnchor),
      status.bottomAnchor.constraint(lessThanOrEqualTo: column.bottomAnchor),
    ])
    return column
  }

  private func textArea(editable: Bool, placeholder: String?) -> (scrollView: NSScrollView, textView: NSTextView) {
    let scroll = NSScrollView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    scroll.hasVerticalScroller = true
    scroll.hasHorizontalScroller = false
    scroll.autohidesScrollers = true
    scroll.borderType = .lineBorder
    scroll.drawsBackground = true

    let tv = NSTextView()
    tv.isEditable = editable
    tv.isSelectable = true
    tv.isRichText = false
    tv.allowsUndo = editable
    tv.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
    tv.autoresizingMask = [.width]
    tv.isVerticallyResizable = true
    tv.isHorizontallyResizable = false
    tv.textContainerInset = NSSize(width: 8, height: 8)
    tv.textContainer?.widthTracksTextView = true
    tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
    if let placeholder {
      tv.setValue(NSAttributedString(string: placeholder, attributes: [
        .foregroundColor: NSColor.tertiaryLabelColor,
        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
      ]), forKey: "placeholderAttributedString")
    }
    scroll.documentView = tv
    return (scroll, tv)
  }

  private func imageView(side: CGFloat) -> NSImageView {
    let view = NSImageView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.imageScaling = .scaleProportionallyUpOrDown
    view.wantsLayer = true
    view.layer?.borderWidth = 1
    view.layer?.borderColor = NSColor.separatorColor.cgColor
    NSLayoutConstraint.activate([
      view.widthAnchor.constraint(equalToConstant: side),
      view.heightAnchor.constraint(equalToConstant: side),
    ])
    return view
  }

  private func statusLabel() -> NSTextField {
    let label = NSTextField(labelWithString: "")
    label.translatesAutoresizingMaskIntoConstraints = false
    label.textColor = .secondaryLabelColor
    label.lineBreakMode = .byTruncatingTail
    label.font = .systemFont(ofSize: 11)
    return label
  }

  private func segment(labels: [String], action: Selector) -> NSSegmentedControl {
    let control = NSSegmentedControl(labels: labels, trackingMode: .selectOne, target: self, action: action)
    control.translatesAutoresizingMaskIntoConstraints = false
    control.selectedSegment = 0
    control.segmentStyle = .rounded
    control.setContentHuggingPriority(.required, for: .horizontal)
    return control
  }

  private func iconButton(symbol: String, toolTip: String, action: Selector) -> NSButton {
    let button = NSButton(title: "", target: self, action: action)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.bezelStyle = .texturedRounded
    button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: toolTip)
    button.imagePosition = .imageOnly
    button.toolTip = toolTip
    button.setContentHuggingPriority(.required, for: .horizontal)
    return button
  }

  private func set(_ tv: NSTextView, _ result: CodecResult) {
    if let error = result.error {
      set(tv, text: error, isError: true)
    } else {
      set(tv, text: result.result)
    }
  }

  private func set(_ tv: NSTextView, text: String, isError: Bool = false) {
    tv.textColor = isError ? .systemRed : .labelColor
    tv.string = text
  }

  private func mimeType(for url: URL) -> String {
    switch url.pathExtension.lowercased() {
    case "jpg", "jpeg": return "image/jpeg"
    case "gif": return "image/gif"
    case "heic": return "image/heic"
    case "webp": return "image/webp"
    case "svg": return "image/svg+xml"
    default: return "image/png"
    }
  }
}
