import Cocoa

// 设置页: 选择无操作自动退出时长
final class SettingsViewController: NSViewController {

  private let popup = NSPopUpButton()

  private var autoQuit: AutoQuitController? { (NSApp.delegate as? AppDelegate)?.autoQuit }

  private static func label(_ m: Int) -> String { m == 0 ? "Never" : "\(m) min" }

  override func loadView() {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let label = NSTextField(labelWithString: "Auto-quit after inactivity")
    label.font = .systemFont(ofSize: 13)
    label.translatesAutoresizingMaskIntoConstraints = false

    popup.translatesAutoresizingMaskIntoConstraints = false
    popup.target = self
    popup.action = #selector(changed)
    for m in AutoQuitController.options { popup.addItem(withTitle: Self.label(m)) }
    let cur = autoQuit?.minutes ?? AutoQuitController.defaultMinutes
    popup.selectItem(at: AutoQuitController.options.firstIndex(of: cur) ?? 0)

    let hint = NSTextField(
      wrappingLabelWithString: "距上次操作达到设定时长后自动退出。输入内容已本地保存, 退出不会丢失。")
    hint.font = .systemFont(ofSize: 11)
    hint.textColor = .secondaryLabelColor
    hint.translatesAutoresizingMaskIntoConstraints = false

    let row = NSStackView(views: [label, popup])
    row.orientation = .horizontal
    row.spacing = 12
    row.alignment = .centerY
    row.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(row)
    container.addSubview(hint)

    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
      row.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 18),
      row.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),

      hint.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
      hint.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 8),
      hint.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
    ])

    self.view = container
  }

  @objc private func changed() {
    let idx = popup.indexOfSelectedItem
    guard AutoQuitController.options.indices.contains(idx) else { return }
    autoQuit?.minutes = AutoQuitController.options[idx]
  }
}
