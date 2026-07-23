import Cocoa

// 输入/结果分隔视图: 加粗可视分隔线 + 中央握把 (明确可拖拽位置) + 双击复位为均分
final class IOSplitView: NSSplitView {

  var onDividerDoubleClick: (() -> Void)?

  override var dividerThickness: CGFloat { 11 }

  override func drawDivider(in rect: NSRect) {
    NSColor.separatorColor.setFill()
    rect.fill()

    // 中央握把: 竖分隔画竖条, 横分隔画横条
    let grip: NSRect
    if isVertical {
      grip = NSRect(x: rect.midX - 2, y: rect.midY - 22, width: 4, height: 44)
    } else {
      grip = NSRect(x: rect.midX - 22, y: rect.midY - 2, width: 44, height: 4)
    }
    NSColor.tertiaryLabelColor.setFill()
    NSBezierPath(roundedRect: grip.intersection(rect), xRadius: 2, yRadius: 2).fill()
  }

  override func mouseDown(with event: NSEvent) {
    if event.clickCount == 2 {
      let p = convert(event.locationInWindow, from: nil)
      if dividerRect().contains(p) {
        onDividerDoubleClick?()
        return
      }
    }
    super.mouseDown(with: event)
  }

  // 两 pane 之间的分隔矩形 (含轴向坐标翻转的通用处理)
  private func dividerRect() -> NSRect {
    guard arrangedSubviews.count >= 2 else { return .zero }
    let f0 = arrangedSubviews[0].frame
    let f1 = arrangedSubviews[1].frame
    if isVertical {
      let lo = f0.minX < f1.minX ? f0 : f1
      let hi = f0.minX < f1.minX ? f1 : f0
      return NSRect(x: lo.maxX, y: 0, width: max(hi.minX - lo.maxX, dividerThickness), height: bounds.height)
    } else {
      let lo = f0.minY < f1.minY ? f0 : f1
      let hi = f0.minY < f1.minY ? f1 : f0
      return NSRect(x: 0, y: lo.maxY, width: bounds.width, height: max(hi.minY - lo.maxY, dividerThickness))
    }
  }
}
