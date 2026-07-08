import Cocoa

final class DetailContainerViewController: NSViewController {

  private var current: NSViewController?

  override func loadView() {
    let v = NSView()
    v.translatesAutoresizingMaskIntoConstraints = false
    self.view = v
  }

  func show(tool: Tool) {
    let next: NSViewController
    switch tool.id {
    case "json-formatter":
      next = FormatJsonViewController(tool: tool)
    case "text-multiline-to-singleline":
      next = MultilineToSinglelineViewController(tool: tool)
    case "text-singleline-to-multiline":
      next = SinglelineToMultilineViewController(tool: tool)
    default:
      next = ToolPlaceholderViewController(tool: tool)
    }
    swap(to: next)
  }

  private func swap(to next: NSViewController) {
    if let current {
      current.view.removeFromSuperview()
      current.removeFromParent()
    }
    addChild(next)
    next.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(next.view)
    NSLayoutConstraint.activate([
      next.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      next.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      next.view.topAnchor.constraint(equalTo: view.topAnchor),
      next.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    current = next
  }
}
