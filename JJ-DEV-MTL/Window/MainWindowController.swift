import Cocoa

final class MainWindowController: NSWindowController, NSWindowDelegate {

  // 只记尺寸(手动持久化, 绕开 NSWindowController + 状态恢复下失效的 setFrameAutosaveName);
  // 位置总是居中于鼠标当前所在屏幕 (多显示器: 在哪块屏幕就在哪块打开)
  private static let widthKey = "JJDEVMTL.windowW"
  private static let heightKey = "JJDEVMTL.windowH"
  private static let defaultSize = NSSize(width: 960, height: 620)
  private static let minSize = NSSize(width: 480, height: 340)
  private static var appTitle: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? "JJ-DEV-MTL"
  }

  convenience init() {
    let frame = Self.launchFrame()
    let window = NSWindow(
      contentRect: frame,
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = Self.appTitle
    window.titlebarAppearsTransparent = true
    window.minSize = Self.minSize
    window.isRestorable = false  // 关掉系统自动状态恢复, 避免与手动持久化互相干扰

    window.contentViewController = RootTabViewController()

    window.setFrame(frame, display: false)

    self.init(window: window)
    shouldCascadeWindows = false  // 不级联偏移位置
    window.delegate = self
  }

  // 保存的尺寸(合法才用) 居中于鼠标所在屏幕
  private static func launchFrame() -> NSRect {
    let w = UserDefaults.standard.double(forKey: widthKey)
    let h = UserDefaults.standard.double(forKey: heightKey)
    let size = (w >= minSize.width && h >= minSize.height) ? NSSize(width: w, height: h) : defaultSize

    let vf = mouseScreen().visibleFrame
    let fw = min(size.width, vf.width)
    let fh = min(size.height, vf.height)
    return NSRect(x: vf.midX - fw / 2, y: vf.midY - fh / 2, width: fw, height: fh)
  }

  private static func mouseScreen() -> NSScreen {
    let p = NSEvent.mouseLocation
    return NSScreen.screens.first { $0.frame.contains(p) }
      ?? NSScreen.main
      ?? NSScreen.screens.first
      ?? NSScreen()
  }

  private func saveSize() {
    guard let s = window?.frame.size else { return }
    UserDefaults.standard.set(s.width, forKey: Self.widthKey)
    UserDefaults.standard.set(s.height, forKey: Self.heightKey)
  }

  func windowDidResize(_ notification: Notification) { saveSize() }
  func windowWillClose(_ notification: Notification) { saveSize() }
}
