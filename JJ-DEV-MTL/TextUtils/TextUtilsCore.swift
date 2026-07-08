import Foundation

// 纯逻辑, module 默认 MainActor 隔离 -> 显式 nonisolated 便于单元测试从任意线程调用
enum TextUtilsCore {

  // 多行 -> 单行: 反斜杠 / 双引号 / CRLF / LF / CR / TAB 转义, 外裹双引号
  nonisolated static func escapeToSingleline(_ text: String) -> String {
    var out = ""
    out.reserveCapacity(text.count + 2)
    for ch in text {
      switch ch {
      case "\\": out += "\\\\"
      case "\"": out += "\\\""
      case "\r\n": out += "\\n"
      case "\n": out += "\\n"
      case "\r": out += "\\r"
      case "\t": out += "\\t"
      default: out.append(ch)
      }
    }
    return "\"\(out)\""
  }

  // 单行 -> 多行: \n \t \r \\ 反转义; 其余 \X 保留原样 (与源 JS 实现一致)
  nonisolated static func unescapeToMultiline(_ text: String) -> String {
    var out = ""
    out.reserveCapacity(text.count)
    let chars = Array(text)
    var i = 0
    while i < chars.count {
      if chars[i] == "\\", i + 1 < chars.count {
        switch chars[i + 1] {
        case "n": out.append("\n"); i += 2
        case "t": out.append("\t"); i += 2
        case "r": out.append("\r"); i += 2
        case "\\": out.append("\\"); i += 2
        default: out.append(chars[i]); i += 1
        }
      } else {
        out.append(chars[i]); i += 1
      }
    }
    return out
  }

  struct FormatResult {
    let result: String
    let error: String?
  }

  // JSON 格式化 + 嵌套解包 (字符串值若为合法 JSON 则递归解析); 失败时若含 \" 兜底再包一层解析
  nonisolated static func formatJson(_ text: String) -> FormatResult {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return FormatResult(result: "", error: "Empty input")
    }
    do {
      let unwrapped = try parseAndUnwrap(trimmed)
      return FormatResult(result: try serialize(unwrapped), error: nil)
    } catch let firstErr {
      if trimmed.contains("\\\"") {
        if let fallback = try? parseAndUnwrap("\"\(trimmed)\""),
          let out = try? serialize(fallback) {
          return FormatResult(result: out, error: nil)
        }
      }
      return FormatResult(result: "", error: (firstErr as NSError).localizedDescription)
    }
  }

  private nonisolated static func parseAndUnwrap(_ s: String) throws -> Any {
    guard let data = s.data(using: .utf8) else {
      throw NSError(domain: "TextUtilsCore", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8"])
    }
    let obj = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    return unwrapNested(obj, depth: 0)
  }

  private nonisolated static func unwrapNested(_ value: Any, depth: Int) -> Any {
    if depth > 20 { return value }
    if let s = value as? String {
      let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
      if t.hasPrefix("{") || t.hasPrefix("[") {
        if let data = t.data(using: .utf8),
          let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
          return unwrapNested(parsed, depth: depth + 1)
        }
      }
      return s
    }
    if let arr = value as? [Any] {
      return arr.map { unwrapNested($0, depth: depth + 1) }
    }
    if let dict = value as? [String: Any] {
      var out: [String: Any] = [:]
      for (k, v) in dict { out[k] = unwrapNested(v, depth: depth + 1) }
      return out
    }
    return value
  }

  private nonisolated static func serialize(_ value: Any) throws -> String {
    let opts: JSONSerialization.WritingOptions = [
      .prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed,
    ]
    let data = try JSONSerialization.data(withJSONObject: value, options: opts)
    guard let s = String(data: data, encoding: .utf8) else {
      throw NSError(domain: "TextUtilsCore", code: -2,
        userInfo: [NSLocalizedDescriptionKey: "UTF-8 decode failed"])
    }
    // JSONSerialization prettyPrinted 默认 2 空格缩进, 无需替换
    return s
  }
}
