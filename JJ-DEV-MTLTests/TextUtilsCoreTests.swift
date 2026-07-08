import XCTest

@testable import JJ_DEV_MTL

final class TextUtilsCoreTests: XCTestCase {

  // MARK: - escapeToSingleline

  func testEscape_emptyString_wrappedInQuotes() {
    XCTAssertEqual(TextUtilsCore.escapeToSingleline(""), "\"\"")
  }

  func testEscape_plainText_wrappedOnly() {
    XCTAssertEqual(TextUtilsCore.escapeToSingleline("hello"), "\"hello\"")
  }

  func testEscape_lf_becomesBackslashN() {
    XCTAssertEqual(TextUtilsCore.escapeToSingleline("a\nb"), "\"a\\nb\"")
  }

  func testEscape_crlf_becomesSingleBackslashN() {
    XCTAssertEqual(TextUtilsCore.escapeToSingleline("a\r\nb"), "\"a\\nb\"")
  }

  func testEscape_cr_becomesBackslashR() {
    XCTAssertEqual(TextUtilsCore.escapeToSingleline("a\rb"), "\"a\\rb\"")
  }

  func testEscape_tab_becomesBackslashT() {
    XCTAssertEqual(TextUtilsCore.escapeToSingleline("a\tb"), "\"a\\tb\"")
  }

  func testEscape_backslash_doubled() {
    XCTAssertEqual(TextUtilsCore.escapeToSingleline("a\\b"), "\"a\\\\b\"")
  }

  func testEscape_doubleQuote_escaped() {
    XCTAssertEqual(TextUtilsCore.escapeToSingleline("a\"b"), "\"a\\\"b\"")
  }

  func testEscape_mixedControlChars() {
    let input = "line1\n\tline2\r\nline3\""
    let expected = "\"line1\\n\\tline2\\nline3\\\"\""
    XCTAssertEqual(TextUtilsCore.escapeToSingleline(input), expected)
  }

  // MARK: - unescapeToMultiline

  func testUnescape_emptyString() {
    XCTAssertEqual(TextUtilsCore.unescapeToMultiline(""), "")
  }

  func testUnescape_plainText_unchanged() {
    XCTAssertEqual(TextUtilsCore.unescapeToMultiline("hello"), "hello")
  }

  func testUnescape_backslashN_becomesLf() {
    XCTAssertEqual(TextUtilsCore.unescapeToMultiline("a\\nb"), "a\nb")
  }

  func testUnescape_backslashT_becomesTab() {
    XCTAssertEqual(TextUtilsCore.unescapeToMultiline("a\\tb"), "a\tb")
  }

  func testUnescape_backslashR_becomesCr() {
    XCTAssertEqual(TextUtilsCore.unescapeToMultiline("a\\rb"), "a\rb")
  }

  func testUnescape_doubleBackslash_becomesSingle() {
    XCTAssertEqual(TextUtilsCore.unescapeToMultiline("a\\\\b"), "a\\b")
  }

  // 与源实现一致: \" 不被反转义, 保留原样
  func testUnescape_unknownEscapeSequence_backslashQuote_preserved() {
    XCTAssertEqual(TextUtilsCore.unescapeToMultiline("a\\\"b"), "a\\\"b")
  }

  func testUnescape_trailingLoneBackslash_preserved() {
    XCTAssertEqual(TextUtilsCore.unescapeToMultiline("a\\"), "a\\")
  }

  func testUnescape_mixedEscapes() {
    XCTAssertEqual(TextUtilsCore.unescapeToMultiline("line1\\nline2\\tend"), "line1\nline2\tend")
  }

  // MARK: - escape / unescape 往返 (仅覆盖被反转义支持的字符集)

  func testRoundTrip_supportedEscapes_stripsOuterQuotes() {
    let original = "hello\nworld\tend\\path"
    let escaped = TextUtilsCore.escapeToSingleline(original)
    let inner = String(escaped.dropFirst().dropLast())
    XCTAssertEqual(TextUtilsCore.unescapeToMultiline(inner), original)
  }

  // MARK: - formatJson

  func testFormat_emptyString_returnsError() {
    let r = TextUtilsCore.formatJson("")
    XCTAssertTrue(r.result.isEmpty)
    XCTAssertNotNil(r.error)
  }

  func testFormat_whitespaceOnly_returnsError() {
    let r = TextUtilsCore.formatJson("   \n\t  ")
    XCTAssertTrue(r.result.isEmpty)
    XCTAssertNotNil(r.error)
  }

  func testFormat_simpleObject_prettyPrinted() {
    let r = TextUtilsCore.formatJson("{\"a\":1}")
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, "{\n  \"a\" : 1\n}")
  }

  func testFormat_sortedKeys() {
    let r = TextUtilsCore.formatJson("{\"b\":2,\"a\":1}")
    XCTAssertNil(r.error)
    // .sortedKeys 保证键按字典序输出
    XCTAssertEqual(r.result, "{\n  \"a\" : 1,\n  \"b\" : 2\n}")
  }

  func testFormat_array_prettyPrinted() {
    let r = TextUtilsCore.formatJson("[1,2,3]")
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, "[\n  1,\n  2,\n  3\n]")
  }

  func testFormat_topLevelStringFragment_supported() {
    let r = TextUtilsCore.formatJson("\"plain\"")
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, "\"plain\"")
  }

  func testFormat_topLevelNumberFragment_supported() {
    let r = TextUtilsCore.formatJson("42")
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, "42")
  }

  func testFormat_invalidJson_returnsError() {
    let r = TextUtilsCore.formatJson("{not json")
    XCTAssertTrue(r.result.isEmpty)
    XCTAssertNotNil(r.error)
  }

  // 嵌套解包: 字符串值恰好是合法 JSON -> 递归解析
  func testFormat_nestedJsonStringValue_unwrapped() {
    let r = TextUtilsCore.formatJson("{\"data\":\"{\\\"x\\\":1}\"}")
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, "{\n  \"data\" : {\n    \"x\" : 1\n  }\n}")
  }

  // 嵌套解包: 数组元素是嵌套 JSON 字符串
  func testFormat_nestedJsonInArray_unwrapped() {
    let r = TextUtilsCore.formatJson("[\"[1,2]\",\"plain\"]")
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, "[\n  [\n    1,\n    2\n  ],\n  \"plain\"\n]")
  }

  // 双引号转义兜底: 顶层是被转义的 JSON 字符串 (\"a\":1 而非 "a":1) 时, 用引号包裹再解析
  func testFormat_escapedJsonStringFallback_unwrapped() {
    let r = TextUtilsCore.formatJson("{\\\"k\\\":\\\"v\\\"}")
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, "{\n  \"k\" : \"v\"\n}")
  }

  // 无引号数字字符串不应被"解包"成数字, 保留字符串
  func testFormat_numericStringValue_notUnwrapped() {
    let r = TextUtilsCore.formatJson("{\"a\":\"123\"}")
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, "{\n  \"a\" : \"123\"\n}")
  }

  // 斜杠不被转义为 \/
  func testFormat_slashNotEscaped() {
    let r = TextUtilsCore.formatJson("{\"url\":\"https://x.com/a\"}")
    XCTAssertNil(r.error)
    XCTAssertTrue(r.result.contains("https://x.com/a"))
    XCTAssertFalse(r.result.contains("\\/"))
  }

  func testFormat_nested_deeperStructure() {
    let r = TextUtilsCore.formatJson("{\"a\":{\"b\":[1,{\"c\":\"d\"}]}}")
    XCTAssertNil(r.error)
    let expected = """
    {
      "a" : {
        "b" : [
          1,
          {
            "c" : "d"
          }
        ]
      }
    }
    """
    XCTAssertEqual(r.result, expected)
  }
}
