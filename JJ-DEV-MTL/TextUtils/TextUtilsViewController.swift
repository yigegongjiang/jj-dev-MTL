import Cocoa

// 三个 text-utils 工具的共享 UI 骨架: 标题 + 输入 + 结果 + 复制 / 粘贴按钮 + 错误提示
class TextUtilsViewController: NSViewController, NSTextViewDelegate {

  private let tool: Tool
  private let placeholder: String
  private let resultDefaultText: String

  private var inputTextView: NSTextView!
  private var resultTextView: NSTextView!
  private var errorLabel: NSTextField!
  private var copyButton: NSButton!
  private var pasteButton: NSButton!
  private var toastLabel: NSTextField!
  private var toastFadeItem: DispatchWorkItem?

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

  override func loadView() {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let icon = NSImageView()
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.image = NSImage(systemSymbolName: tool.symbolName, accessibilityDescription: nil)
    icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
    icon.contentTintColor = .secondaryLabelColor

    let title = NSTextField(labelWithString: tool.title)
    title.font = .systemFont(ofSize: 20, weight: .semibold)

    let header = NSStackView(views: [icon, title])
    header.orientation = .horizontal
    header.spacing = 10
    header.alignment = .centerY
    header.translatesAutoresizingMaskIntoConstraints = false

    let divider = NSBox()
    divider.boxType = .separator
    divider.translatesAutoresizingMaskIntoConstraints = false

    let inputLabel = Self.makeSectionLabel("Input")
    let inputScroll = Self.makeScrollableTextView(editable: true, placeholder: placeholder)
    inputTextView = inputScroll.documentView as? NSTextView
    inputTextView.delegate = self

    errorLabel = NSTextField(labelWithString: "")
    errorLabel.font = .systemFont(ofSize: 12)
    errorLabel.textColor = .systemRed
    errorLabel.isBezeled = false
    errorLabel.drawsBackground = false
    errorLabel.isEditable = false
    errorLabel.isSelectable = false
    errorLabel.lineBreakMode = .byWordWrapping
    errorLabel.translatesAutoresizingMaskIntoConstraints = false
    errorLabel.maximumNumberOfLines = 0

    let resultLabel = Self.makeSectionLabel("Result")
    let resultScroll = Self.makeScrollableTextView(editable: false, placeholder: nil)
    resultTextView = resultScroll.documentView as? NSTextView
    resultTextView.string = resultDefaultText
    resultTextView.textColor = .secondaryLabelColor

    copyButton = NSButton(title: "Copy to Clipboard", target: self, action: #selector(copyResult))
    copyButton.bezelStyle = .rounded
    copyButton.translatesAutoresizingMaskIntoConstraints = false
    copyButton.keyEquivalent = "\r"

    pasteButton = NSButton(title: "Paste to Active App", target: self, action: #selector(pasteResult))
    pasteButton.bezelStyle = .rounded
    pasteButton.translatesAutoresizingMaskIntoConstraints = false

    toastLabel = NSTextField(labelWithString: "")
    toastLabel.font = .systemFont(ofSize: 12)
    toastLabel.textColor = .systemGreen
    toastLabel.isBezeled = false
    toastLabel.drawsBackground = false
    toastLabel.isEditable = false
    toastLabel.isSelectable = false
    toastLabel.translatesAutoresizingMaskIntoConstraints = false

    let buttons = NSStackView()
    buttons.orientation = .horizontal
    buttons.spacing = 10
    buttons.alignment = .centerY
    buttons.translatesAutoresizingMaskIntoConstraints = false
    buttons.addArrangedSubview(copyButton)
    buttons.addArrangedSubview(pasteButton)
    buttons.addArrangedSubview(toastLabel)

    let allSubviews: [NSView] = [header, divider, inputLabel, inputScroll, errorLabel, resultLabel, resultScroll, buttons]
    for v in allSubviews { container.addSubview(v) }

    NSLayoutConstraint.activate([
      header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
      header.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
      header.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),

      divider.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
      divider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
      divider.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
      divider.heightAnchor.constraint(equalToConstant: 1),

      inputLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
      inputLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 16),

      inputScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
      inputScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
      inputScroll.topAnchor.constraint(equalTo: inputLabel.bottomAnchor, constant: 6),
      inputScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),

      errorLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
      errorLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
      errorLabel.topAnchor.constraint(equalTo: inputScroll.bottomAnchor, constant: 6),

      resultLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
      resultLabel.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 12),

      resultScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
      resultScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
      resultScroll.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 6),
      resultScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),

      buttons.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
      buttons.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
      buttons.topAnchor.constraint(equalTo: resultScroll.bottomAnchor, constant: 12),
      buttons.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
    ])

    self.view = container
    refresh()
  }

  func textDidChange(_ notification: Notification) { refresh() }

  private func refresh() {
    let input = inputTextView?.string ?? ""
    if input.isEmpty {
      resultTextView.string = resultDefaultText
      resultTextView.textColor = .secondaryLabelColor
      errorLabel.stringValue = ""
      copyButton.isEnabled = false
      pasteButton.isEnabled = false
      return
    }
    let (result, error) = transform(input)
    if let error {
      errorLabel.stringValue = error
      resultTextView.string = ""
      copyButton.isEnabled = false
      pasteButton.isEnabled = false
    } else {
      errorLabel.stringValue = ""
      resultTextView.string = result
      resultTextView.textColor = .labelColor
      let hasContent = !result.isEmpty
      copyButton.isEnabled = hasContent
      pasteButton.isEnabled = hasContent
    }
  }

  @objc private func copyResult() {
    let text = resultTextView.string
    guard !text.isEmpty else { return }
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(text, forType: .string)
    showToast("Copied")
  }

  @objc private func pasteResult() {
    let text = resultTextView.string
    guard !text.isEmpty else { return }
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(text, forType: .string)
    NSApp.hide(nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      Self.simulateCommandV()
    }
    showToast("Pasted")
  }

  private func showToast(_ text: String) {
    toastFadeItem?.cancel()
    toastLabel.stringValue = text
    toastLabel.alphaValue = 1
    let item = DispatchWorkItem { [weak self] in
      NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.35
        self?.toastLabel.animator().alphaValue = 0
      }
    }
    toastFadeItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)
  }

  private static func simulateCommandV() {
    let src = CGEventSource(stateID: .combinedSessionState)
    let vKey: CGKeyCode = 0x09
    let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
    down?.flags = .maskCommand
    let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
    up?.flags = .maskCommand
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
  }

  private static func makeSectionLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 12, weight: .medium)
    label.textColor = .secondaryLabelColor
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
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

final class MultilineToSinglelineViewController: TextUtilsViewController {
  init(tool: Tool) {
    super.init(
      tool: tool,
      placeholder: "Paste or type multi-line text here...",
      resultDefaultText: "Enter text above to see the result"
    )
  }
  required init?(coder: NSCoder) { fatalError() }
  override func transform(_ input: String) -> (result: String, error: String?) {
    return (TextUtilsCore.escapeToSingleline(input), nil)
  }
}

final class SinglelineToMultilineViewController: TextUtilsViewController {
  init(tool: Tool) {
    super.init(
      tool: tool,
      placeholder: "Paste text with escape sequences (e.g. Hello\\nWorld)...",
      resultDefaultText: "Enter text above to see the result"
    )
  }
  required init?(coder: NSCoder) { fatalError() }
  override func transform(_ input: String) -> (result: String, error: String?) {
    return (TextUtilsCore.unescapeToMultiline(input), nil)
  }
}

final class FormatJsonViewController: TextUtilsViewController {
  init(tool: Tool) {
    super.init(
      tool: tool,
      placeholder: "Paste JSON or escaped JSON string (e.g. {\"k\":\"v\"} or \"{\\\"k\\\":\\\"v\\\"}\")...",
      resultDefaultText: "Enter JSON above to see the formatted result"
    )
  }
  required init?(coder: NSCoder) { fatalError() }
  override func transform(_ input: String) -> (result: String, error: String?) {
    let r = TextUtilsCore.formatJson(input)
    return (r.result, r.error)
  }
}
