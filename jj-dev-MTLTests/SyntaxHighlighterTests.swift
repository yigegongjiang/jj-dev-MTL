import XCTest
import Cocoa

@testable import jj_dev_MTL

// 染色逻辑的 color-run 断言: 直接验证真实 SyntaxHighlighter 对各 token 赋的颜色
final class SyntaxHighlighterTests: XCTestCase {

  private let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

  private func color(_ attr: NSAttributedString, at loc: Int) -> NSColor? {
    guard loc >= 0, loc < attr.length else { return nil }
    return attr.attribute(.foregroundColor, at: loc, effectiveRange: nil) as? NSColor
  }

  private func color(_ attr: NSAttributedString, ofFirst sub: String, in text: String) -> NSColor? {
    let r = (text as NSString).range(of: sub)
    guard r.location != NSNotFound else { return nil }
    return color(attr, at: r.location)
  }

  // MARK: - JSON

  func testJSON_tokensGetExpectedColors() {
    let formatted = TextUtilsCore.formatJson(#"{"name":"admin","level":9,"active":true,"note":null}"#).result
    XCTAssertFalse(formatted.isEmpty)
    let attr = SyntaxHighlighter.json(formatted, font: font)

    XCTAssertEqual(color(attr, ofFirst: "\"name\"", in: formatted), SyntaxHighlighter.keyColor)     // 键
    XCTAssertEqual(color(attr, ofFirst: "\"admin\"", in: formatted), SyntaxHighlighter.stringColor) // 字符串值
    XCTAssertEqual(color(attr, ofFirst: "9", in: formatted), SyntaxHighlighter.numberColor)         // 数字
    XCTAssertEqual(color(attr, ofFirst: "true", in: formatted), SyntaxHighlighter.keywordColor)     // 关键字
    XCTAssertEqual(color(attr, ofFirst: "null", in: formatted), SyntaxHighlighter.keywordColor)     // 关键字
    XCTAssertEqual(color(attr, at: 0), SyntaxHighlighter.punctuationColor)                          // {
  }

  // 负数 / 小数整体染为数字色 (取二进制可精确表示的值, 避免浮点表示误差)
  func testJSON_numberVariants() {
    let formatted = TextUtilsCore.formatJson(#"{"a":-42.5,"b":3.75,"c":1024}"#).result
    let attr = SyntaxHighlighter.json(formatted, font: font)
    XCTAssertEqual(color(attr, ofFirst: "-42.5", in: formatted), SyntaxHighlighter.numberColor)
    XCTAssertEqual(color(attr, ofFirst: "3.75", in: formatted), SyntaxHighlighter.numberColor)
    XCTAssertEqual(color(attr, ofFirst: "1024", in: formatted), SyntaxHighlighter.numberColor)
  }

  // 非 BMP (emoji) / CJK 不越界不崩溃, 长度守恒
  func testJSON_nonBMPSafe_lengthPreserved() {
    let formatted = TextUtilsCore.formatJson(#"{"emoji":"🚀🔥","lang":"日本語"}"#).result
    let attr = SyntaxHighlighter.json(formatted, font: font)
    XCTAssertEqual(attr.length, (formatted as NSString).length)
    XCTAssertEqual(color(attr, ofFirst: "\"emoji\"", in: formatted), SyntaxHighlighter.keyColor)
  }

  // MARK: - 转义单行串

  func testEscaped_quotesAndSequencesColored() {
    let esc = TextUtilsCore.escapeToSingleline("a\nb\"c\\d")  // -> "a\nb\"c\\d"
    let attr = SyntaxHighlighter.escaped(esc, font: font)

    XCTAssertEqual(color(attr, at: 0), SyntaxHighlighter.punctuationColor)                 // 开引号
    XCTAssertEqual(color(attr, at: (esc as NSString).length - 1), SyntaxHighlighter.punctuationColor)  // 闭引号
    XCTAssertEqual(color(attr, ofFirst: "\\n", in: esc), SyntaxHighlighter.escapeColor)    // 转义序列
    XCTAssertEqual(color(attr, ofFirst: "a", in: esc), NSColor.labelColor)                 // 普通字符
  }

  // MARK: - 纯文本

  func testPlain_allLabelColor() {
    let attr = SyntaxHighlighter.plain("hello\nworld", font: font)
    XCTAssertEqual(color(attr, at: 0), NSColor.labelColor)
    XCTAssertEqual(attr.length, 11)
  }
}
