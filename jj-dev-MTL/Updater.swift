import Cocoa

@MainActor
final class Updater {
  static let shared = Updater()

  private let repo = "yigegongjiang/jj-dev-MTL"
  private let asset = "jj-dev-MTL-macos.zip"
  private let metadataAsset = "release-metadata.json"

  private var localCommitSHA: String {
    Bundle.main.infoDictionary?["GitCommitSHA"] as? String ?? ""
  }

  private var currentVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
  }

  func checkForUpdates(userInitiated: Bool) {
    Task { await self.run(userInitiated: userInitiated) }
  }

  private func run(userInitiated: Bool) async {
    do {
      let latest = try await fetchMetadata()
      // 用 commit SHA 判定, 同 tag amend 也能识别; 本机无 SHA (旧版) → 一律视为需要更新.
      let shouldUpdate = localCommitSHA.isEmpty || latest.sha != localCommitSHA
      if shouldUpdate {
        if confirmUpdate(tag: latest.tag, remoteSHA: latest.sha) {
          try await performUpdate()
        }
      } else if userInitiated {
        info("已是最新版本 (\(latest.tag) @ \(String(latest.sha.prefix(7))))")
      }
    } catch {
      if userInitiated { warn("检查更新失败: \(error.localizedDescription)") }
    }
  }

  private struct Metadata { let tag: String; let sha: String }

  private func fetchMetadata() async throws -> Metadata {
    let url = URL(string: "https://github.com/\(repo)/releases/latest/download/\(metadataAsset)")!
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    req.setValue("jj-dev-MTL/\(currentVersion)", forHTTPHeaderField: "User-Agent")
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
          let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tag = obj["tag"] as? String,
          let sha = obj["sha"] as? String
    else {
      throw NSError(
        domain: "Updater", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "release-metadata.json 响应异常"])
    }
    return Metadata(tag: tag, sha: sha)
  }

  private func confirmUpdate(tag: String, remoteSHA: String) -> Bool {
    let localShort = localCommitSHA.isEmpty ? "unknown" : String(localCommitSHA.prefix(7))
    let remoteShort = String(remoteSHA.prefix(7))
    let alert = NSAlert()
    alert.messageText = "发现新构建 \(tag)"
    alert.informativeText = "本机 \(localShort) → 远端 \(remoteShort). 将下载并替换当前 app, 完成后自动重启."
    alert.addButton(withTitle: "立即更新")
    alert.addButton(withTitle: "稍后")
    return alert.runModal() == .alertFirstButtonReturn
  }

  private func performUpdate() async throws {
    let tmp = try makeTempDir()
    let zipURL = tmp.appendingPathComponent(asset)
    let url = URL(string: "https://github.com/\(repo)/releases/latest/download/\(asset)")!
    let (tempFile, resp) = try await URLSession.shared.download(from: url)
    guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw NSError(
        domain: "Updater", code: 2,
        userInfo: [
          NSLocalizedDescriptionKey: "下载失败 HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1)"
        ])
    }
    try FileManager.default.moveItem(at: tempFile, to: zipURL)

    let unpackDir = tmp.appendingPathComponent("unpacked")
    try FileManager.default.createDirectory(at: unpackDir, withIntermediateDirectories: true)
    try await runBlocking("/usr/bin/ditto", ["-x", "-k", zipURL.path, unpackDir.path])

    let items = try FileManager.default.contentsOfDirectory(
      at: unpackDir, includingPropertiesForKeys: nil)
    guard let newApp = items.first(where: { $0.pathExtension == "app" }) else {
      throw NSError(
        domain: "Updater", code: 3, userInfo: [NSLocalizedDescriptionKey: "更新包内无 .app"])
    }
    let currentApp = Bundle.main.bundleURL

    let script = tmp.appendingPathComponent("swap.sh")
    let body = """
      #!/bin/bash
      set -e
      APP_PID=$1
      OLD_APP=$2
      NEW_APP=$3
      while /bin/kill -0 "$APP_PID" 2>/dev/null; do /bin/sleep 0.3; done
      /bin/sleep 0.5
      /bin/rm -rf "$OLD_APP"
      /bin/mv "$NEW_APP" "$OLD_APP"
      /usr/bin/xattr -dr com.apple.quarantine "$OLD_APP" 2>/dev/null || true
      /usr/bin/open "$OLD_APP"
      """
    try body.write(to: script, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: script.path)

    let task = Process()
    task.executableURL = URL(fileURLWithPath: script.path)
    task.arguments = [String(getpid()), currentApp.path, newApp.path]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    try task.run()
    // 不等待, 让 helper 脱离本进程存活.

    NSApp.terminate(nil)
  }

  private func runBlocking(_ path: String, _ args: [String]) async throws {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
      let task = Process()
      task.executableURL = URL(fileURLWithPath: path)
      task.arguments = args
      task.standardOutput = FileHandle.nullDevice
      task.standardError = FileHandle.nullDevice
      task.terminationHandler = { p in
        if p.terminationStatus == 0 {
          cont.resume()
        } else {
          cont.resume(
            throwing: NSError(
              domain: "Updater", code: 4,
              userInfo: [NSLocalizedDescriptionKey: "\(path) 退出 \(p.terminationStatus)"]))
        }
      }
      do { try task.run() } catch { cont.resume(throwing: error) }
    }
  }

  private func makeTempDir() throws -> URL {
    let d = FileManager.default.temporaryDirectory
      .appendingPathComponent("jj-dev-MTL-update-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
  }

  private func info(_ m: String) { alert(title: "检查更新", message: m, style: .informational) }
  private func warn(_ m: String) { alert(title: "更新错误", message: m, style: .warning) }
  private func alert(title: String, message: String, style: NSAlert.Style) {
    let a = NSAlert()
    a.messageText = title
    a.informativeText = message
    a.alertStyle = style
    a.runModal()
  }
}
