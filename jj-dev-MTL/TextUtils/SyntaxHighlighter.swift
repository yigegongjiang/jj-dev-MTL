import Cocoa

// 结果文本染色: 对已合法的输出做纯装饰性 token 扫描, 误判只影响颜色不影响数据
enum SyntaxHighlighter {

  // MARK: - 调色板 (VS Code Dark+ / Light+ 取色, 随外观自适应)

  private static func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }

  private static func adaptive(light: UInt32, dark: UInt32) -> NSColor {
    NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      return rgb(isDark ? dark : light)
    }
  }

  static let keyColor = adaptive(light: 0x0451A5, dark: 0x9CDCFE)      // 对象键
  static let stringColor = adaptive(light: 0xA31515, dark: 0xCE9178)  // 字符串值
  static let numberColor = adaptive(light: 0x098658, dark: 0xB5CEA8)  // 数字
  static let keywordColor = adaptive(light: 0x0000FF, dark: 0x569CD6) // true / false / null
  static let escapeColor = adaptive(light: 0xAF00DB, dark: 0xD7BA7D)  // 转义序列
  static let punctuationColor = NSColor.secondaryLabelColor           // 括号 / 冒号 / 逗号 / 引号

  // MARK: - 扫描辅助 (UTF-16 code unit)

  private static func isWS(_ c: unichar) -> Bool { c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D }
  private static func isDigit(_ c: unichar) -> Bool { c >= 0x30 && c <= 0x39 }
  private static func isLetter(_ c: unichar) -> Bool { (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A) }
  // 数字体: 数字 / - + . e E
  private static func isNumberBody(_ c: unichar) -> Bool {
    isDigit(c) || c == 0x2D || c == 0x2B || c == 0x2E || c == 0x65 || c == 0x45
  }

  private static func base(_ text: String, _ font: NSFont) -> NSMutableAttributedString {
    NSMutableAttributedString(string: text, attributes: [
      .font: font, .foregroundColor: NSColor.labelColor,
    ])
  }

  // MARK: - JSON

  // 逐 code unit 扫描: 字符串按后随冒号判 键/值, 结构符 / 数字 / 关键字 分色
  static func json(_ text: String, font: NSFont) -> NSAttributedString {
    let out = base(text, font)
    let ns = text as NSString
    let n = ns.length
    var i = 0
    while i < n {
      let c = ns.character(at: i)
      switch c {
      case 0x22:  // "
        let start = i
        i += 1
        while i < n {
          let ch = ns.character(at: i)
          if ch == 0x5C { i += 2; continue }  // \ 转义, 跳过下一字符
          i += 1
          if ch == 0x22 { break }
        }
        let end = min(i, n)
        var j = end
        while j < n, isWS(ns.character(at: j)) { j += 1 }
        let isKey = j < n && ns.character(at: j) == 0x3A  // 后随 : 即为键
        out.addAttribute(.foregroundColor, value: isKey ? keyColor : stringColor,
                         range: NSRange(location: start, length: end - start))
      case 0x7B, 0x7D, 0x5B, 0x5D, 0x3A, 0x2C:  // { } [ ] : ,
        out.addAttribute(.foregroundColor, value: punctuationColor, range: NSRange(location: i, length: 1))
        i += 1
      case 0x74, 0x66, 0x6E:  // t f n -> true / false / null
        let start = i
        while i < n, isLetter(ns.character(at: i)) { i += 1 }
        out.addAttribute(.foregroundColor, value: keywordColor, range: NSRange(location: start, length: i - start))
      case 0x2D, 0x30...0x39:  // - 或数字
        let start = i
        while i < n, isNumberBody(ns.character(at: i)) { i += 1 }
        out.addAttribute(.foregroundColor, value: numberColor, range: NSRange(location: start, length: i - start))
      default:
        i += 1
      }
    }
    return out
  }

  // MARK: - 转义单行串

  // 外层引号灰显, \n \t \r \\ \" \uXXXX 等转义序列高亮, 其余文本默认色
  static func escaped(_ text: String, font: NSFont) -> NSAttributedString {
    let out = base(text, font)
    let ns = text as NSString
    let n = ns.length
    if n >= 1, ns.character(at: 0) == 0x22 {
      out.addAttribute(.foregroundColor, value: punctuationColor, range: NSRange(location: 0, length: 1))
    }
    if n >= 2, ns.character(at: n - 1) == 0x22 {
      out.addAttribute(.foregroundColor, value: punctuationColor, range: NSRange(location: n - 1, length: 1))
    }
    var i = 0
    while i < n - 1 {
      if ns.character(at: i) == 0x5C {  // \
        let len = ns.character(at: i + 1) == 0x75 ? min(6, n - i) : 2  // \u 占 6 字符
        out.addAttribute(.foregroundColor, value: escapeColor, range: NSRange(location: i, length: len))
        i += len
      } else {
        i += 1
      }
    }
    return out
  }

  // MARK: - 纯文本 (无语法)

  static func plain(_ text: String, font: NSFont) -> NSAttributedString {
    base(text, font)
  }
}
