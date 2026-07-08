import Cocoa

// 无操作自动退出: 距上次用户操作满 N 分钟则退出 (0 = 关闭). 输入内容已本地保存, 退出不丢失.
final class AutoQuitController {
  static let defaultsKey = "JJDEVMTL.autoQuitMinutes"
  static let defaultMinutes = 5
  static let options = [0, 1, 5, 10, 15, 30, 60]  // 0 = Never

  private var timer: Timer?
  private var monitor: Any?

  var minutes: Int {
    get { UserDefaults.standard.object(forKey: Self.defaultsKey) as? Int ?? Self.defaultMinutes }
    set {
      UserDefaults.standard.set(newValue, forKey: Self.defaultsKey)
      reschedule()
    }
  }

  func start() {
    // 任意键盘/鼠标操作视为活动, 重置计时
    monitor = NSEvent.addLocalMonitorForEvents(
      matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .flagsChanged]
    ) { [weak self] event in
      self?.reschedule()
      return event
    }
    reschedule()
  }

  private func reschedule() {
    timer?.invalidate()
    let m = minutes
    guard m > 0 else { timer = nil; return }
    let t = Timer(timeInterval: TimeInterval(m * 60), repeats: false) { _ in
      MainActor.assumeIsolated { NSApp.terminate(nil) }  // Timer 挂在 RunLoop.main, 必在主线程触发
    }
    RunLoop.main.add(t, forMode: .common)  // .common: 菜单/拖拽等追踪模式下仍计时
    timer = t
  }
}
