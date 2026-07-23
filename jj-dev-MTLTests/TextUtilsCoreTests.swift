import XCTest

@testable import jj_dev_MTL

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

  // MARK: - 复杂验收样例 (可直接 copy 到 App 对应工具的 Input 框验收)
  //
  // 说明: JSON 结果用 canonical() 独立规范化后逐字符比对 (与 TextUtilsCore.serialize 同款选项,
  //       浮点/键序表示由 JSONSerialization 统一保证一致); 转义类用「往返不变式」与真实多行文本比对,
  //       避免脆弱的手写转义期望值.

  // --- Format JSON ---

  // 富类型: 整数 / 浮点 / 负数 / 布尔 / null / 转义引号 / 内嵌 \n\t / URL / emoji(非 BMP) / 中日文
  static let jsonRich = #"{"id":1024,"active":true,"deleted":false,"score":98.6,"balance":-42.5,"nickname":"José \"Pepe\" García","tags":["dev","ops","qa"],"profile":{"url":"https://example.com/u/1024?ref=home&x=1","avatar":null,"bio":"line1\nline2\tindented"},"roles":[{"name":"admin","level":9},{"name":"user","level":1}],"emoji":"🚀🔥中文日本語","empty":{}}"#

  func testFormat_richPayload_matchesCanonical() {
    let r = TextUtilsCore.formatJson(Self.jsonRich)
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, canonical(Self.jsonRich))
    XCTAssertFalse(r.result.contains("\\/"))  // 斜杠不转义
    XCTAssertTrue(r.result.contains("🚀🔥"))   // emoji 原样保留
  }

  // 嵌套解包: webhook 的 payload 字段是一整段 JSON 字符串, 应被递归展开成对象
  static let jsonWebhook = #"{"event":"order.created","ts":1699999999,"payload":"{\"orderId\":\"A-1001\",\"items\":[{\"sku\":\"X-9\",\"qty\":2},{\"sku\":\"Y-3\",\"qty\":1}],\"total\":59.9,\"paid\":true}"}"#

  func testFormat_webhookNestedJsonString_unwrapped() {
    let equivalent = #"{"event":"order.created","ts":1699999999,"payload":{"orderId":"A-1001","items":[{"sku":"X-9","qty":2},{"sku":"Y-3","qty":1}],"total":59.9,"paid":true}}"#
    let r = TextUtilsCore.formatJson(Self.jsonWebhook)
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, canonical(equivalent))
  }

  // 兜底路径: 整段是被转义的日志行 (\"level\":... 而非 "level":...)
  static let jsonEscapedLog = #"{\"level\":\"error\",\"service\":\"api-gateway\",\"code\":503,\"retry\":false,\"tags\":[\"net\",\"timeout\"],\"latency_ms\":1234.56}"#

  func testFormat_escapedLogLine_fallbackUnwrapped() {
    let equivalent = #"{"level":"error","service":"api-gateway","code":503,"retry":false,"tags":["net","timeout"],"latency_ms":1234.56}"#
    let r = TextUtilsCore.formatJson(Self.jsonEscapedLog)
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, canonical(equivalent))
  }

  // --- Multiline -> Singleline ---

  // 含换行 / tab / 双引号 / 反斜杠路径的真实代码片段
  static let multilineText = """
  SELECT id, name
  \tFROM "users"
  WHERE path = 'C:\\logs\\app.txt'
  \tAND active = true
  """

  func testEscape_complexMultiline_isValidJsonStringAndRoundTrips() {
    let out = TextUtilsCore.escapeToSingleline(Self.multilineText)
    XCTAssertTrue(out.hasPrefix("\"") && out.hasSuffix("\""))
    XCTAssertTrue(out.contains("\\n"))    // 换行已转义
    XCTAssertTrue(out.contains("\\t"))    // tab 已转义
    XCTAssertTrue(out.contains("\\\""))   // 双引号已转义
    XCTAssertTrue(out.contains("\\\\"))   // 反斜杠已转义
    XCTAssertFalse(out.contains("\n"))    // 结果为单行, 无真实换行
    // 转义结果是合法 JSON 字符串字面量, 解析后应还原原文 (输入仅含 LF/TAB, 往返无损)
    let parsed = try! JSONSerialization.jsonObject(
      with: out.data(using: .utf8)!, options: [.fragmentsAllowed]) as? String
    XCTAssertEqual(parsed, Self.multilineText)
  }

  // --- Singleline -> Multiline ---

  // 单行转义日志 -> 还原多行 + tab + 反斜杠路径
  static let escapedLogLine = #"[2026-07-08 10:30:00]\tERROR\tpath=C:\\Users\\app\\log.txt\nStack trace:\n\tat main()\n\tat run()"#

  func testUnescape_complexLogLine_restoresMultiline() {
    let expected = """
    [2026-07-08 10:30:00]\tERROR\tpath=C:\\Users\\app\\log.txt
    Stack trace:
    \tat main()
    \tat run()
    """
    XCTAssertEqual(TextUtilsCore.unescapeToMultiline(Self.escapedLogLine), expected)
  }

  // MARK: - 主动探查含噪输入 (可直接 copy 到 Format JSON 验收)

  // 日志前后缀包裹
  func testProbe_logPrefixAndSuffix_extracted() {
    let equivalent = #"{"status":"ok","count":3,"cached":false}"#
    let noisy = #"[2026-07-08] Response: {"status":"ok","count":3,"cached":false} <- 200 OK"#
    let r = TextUtilsCore.formatJson(noisy)
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, canonical(equivalent))
  }

  // markdown 代码围栏包裹
  func testProbe_markdownCodeFence_extracted() {
    let equivalent = #"{"a":[1,2,3],"nested":{"x":true,"y":null}}"#
    let noisy = """
    这是返回结果:
    ```json
    {"a":[1,2,3],"nested":{"x":true,"y":null}}
    ```
    以上.
    """
    let r = TextUtilsCore.formatJson(noisy)
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, canonical(equivalent))
  }

  // JSONP / 函数调用包裹
  func testProbe_jsonpWrapper_extracted() {
    let equivalent = #"{"id":7,"active":true,"tags":["a","b"]}"#
    let noisy = #"callback({"id":7,"active":true,"tags":["a","b"]});"#
    let r = TextUtilsCore.formatJson(noisy)
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, canonical(equivalent))
  }

  // 多段 JSON: 取最长 (最可能是预期载荷), 字符串内的花括号不误判
  func testProbe_multipleBlobs_longestWins_ignoresBracesInStrings() {
    let equivalent = #"{"b":2,"c":3,"note":"has } and { inside"}"#
    let noisy = #"first {"a":1} then {"b":2,"c":3,"note":"has } and { inside"} end"#
    let r = TextUtilsCore.formatJson(noisy)
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, canonical(equivalent))
  }

  // 探查失败 (确无 JSON) 仍报错, 不误报
  func testProbe_noJsonPresent_returnsError() {
    let r = TextUtilsCore.formatJson("just some plain prose without any json payload")
    XCTAssertTrue(r.result.isEmpty)
    XCTAssertNotNil(r.error)
  }

  // 转义 JSON + 前后噪声叠加 (反转义后再抽取)
  func testProbe_escapedJsonWithNoise_extracted() {
    let equivalent = #"{"user":"bob","id":42,"roles":["a","b"]}"#
    let noisy = #"log level=info payload={\"user\":\"bob\",\"id\":42,\"roles\":[\"a\",\"b\"]} status=ok"#
    let r = TextUtilsCore.formatJson(noisy)
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, canonical(equivalent))
  }

  // 用户原始场景: 转义 JSON 被 Swift 源码 #"..."# 包裹一起粘贴
  func testProbe_escapedJsonInSwiftWrapper_extracted() {
    let equivalent = #"{"level":"error","code":503,"ok":false}"#
    let wrapped = ##"static let jsonEscapedLog = #"{\"level\":\"error\",\"code\":503,\"ok\":false}"#"##
    let r = TextUtilsCore.formatJson(wrapped)
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, canonical(equivalent))
  }

  // 多重转义 (\\\" -> \" -> ") 逐层还原
  func testProbe_doublyEscapedJson_extracted() {
    let equivalent = #"{"k":"v","n":5}"#
    let doubly = #"{\\\"k\\\":\\\"v\\\",\\\"n\\\":5}"#
    let r = TextUtilsCore.formatJson(doubly)
    XCTAssertNil(r.error)
    XCTAssertEqual(r.result, canonical(equivalent))
  }

  func testRemoteJsonURL_singleHTTPURLDetected() {
    let url = TextUtilsCore.remoteJsonURL(from: "  https://models.dev/catalog.json  ")
    XCTAssertEqual(url?.absoluteString, "https://models.dev/catalog.json")
  }

  func testRemoteJsonURL_curlCommandDetected() {
    let url = TextUtilsCore.remoteJsonURL(from: "curl https://models.dev/catalog.json")
    XCTAssertEqual(url?.absoluteString, "https://models.dev/catalog.json")
  }

  func testRemoteJsonURL_curlCommandWithFlagsAndRefererPicksTargetURL() {
    let input = #"curl -L -H "Accept: application/json" -e https://referer.example https://models.dev/catalog.json"#
    let url = TextUtilsCore.remoteJsonURL(from: input)
    XCTAssertEqual(url?.absoluteString, "https://models.dev/catalog.json")
  }

  func testRemoteJsonURL_curlCommandWithUrlFlagDetected() {
    let url = TextUtilsCore.remoteJsonURL(from: "curl --url 'https://models.dev/catalog.json'")
    XCTAssertEqual(url?.absoluteString, "https://models.dev/catalog.json")
  }

  func testRemoteJsonURL_proseWithOneURLDetected() {
    let url = TextUtilsCore.remoteJsonURL(from: "fetch this please: https://models.dev/catalog.json")
    XCTAssertEqual(url?.absoluteString, "https://models.dev/catalog.json")
  }

  func testRemoteJsonURL_jsonStringContainingURLNotDetected() {
    XCTAssertNil(TextUtilsCore.remoteJsonURL(from: #"{"url":"https://models.dev/catalog.json"}"#))
    XCTAssertNil(TextUtilsCore.remoteJsonURL(from: #""https://models.dev/catalog.json""#))
  }

  func testRemoteJsonURL_rejectsNonHTTPAndMultiTokenInput() {
    XCTAssertNil(TextUtilsCore.remoteJsonURL(from: "file:///tmp/data.json"))
    XCTAssertNil(TextUtilsCore.remoteJsonURL(from: "https://models.dev/a.json https://models.dev/b.json"))
  }

  func testRemoteJsonURL_urlWithExtraBodyDetectedWhenUnique() {
    let url = TextUtilsCore.remoteJsonURL(from: "https://models.dev/catalog.json\n{\"a\":1}")
    XCTAssertEqual(url?.absoluteString, "https://models.dev/catalog.json")
  }

  func testRemoteJSONFetcher_fetches2xxUTF8Text() async throws {
    let session = Self.stubSession(status: 200, data: Data(#"{"ok":true}"#.utf8))
    let text = try await RemoteJSONFetcher.fetchText(
      from: URL(string: "https://example.test/catalog.json")!, session: session)
    XCTAssertEqual(text, #"{"ok":true}"#)
  }

  func testRemoteJSONFetcher_rejectsHTTPError() async {
    let session = Self.stubSession(status: 503, data: Data("Service Unavailable".utf8))
    do {
      _ = try await RemoteJSONFetcher.fetchText(
        from: URL(string: "https://example.test/catalog.json")!, session: session)
      XCTFail("expected HTTP error")
    } catch {
      XCTAssertEqual(error.localizedDescription, "HTTP 503")
    }
  }

  func testRemoteJSONFetcher_rejectsNonUTF8Text() async {
    let session = Self.stubSession(status: 200, data: Data([0xFF, 0xFE, 0x00]))
    do {
      _ = try await RemoteJSONFetcher.fetchText(
        from: URL(string: "https://example.test/catalog.json")!, session: session)
      XCTFail("expected UTF-8 error")
    } catch {
      XCTAssertEqual(error.localizedDescription, "response is not UTF-8 text")
    }
  }

  // MARK: - Codec Toolkit

  func testCodec_urlEncodeDecode_componentRoundTrips() {
    let input = "https://example.com/a b?x=1&y=日本"
    let encoded = CodecToolkitCore.encodeURLComponent(input)
    XCTAssertNil(encoded.error)
    XCTAssertEqual(encoded.result, "https%3A%2F%2Fexample.com%2Fa%20b%3Fx%3D1%26y%3D%E6%97%A5%E6%9C%AC")

    let decoded = CodecToolkitCore.decodeURLComponent(encoded.result)
    XCTAssertNil(decoded.error)
    XCTAssertEqual(decoded.result, input)
  }

  func testCodec_base64Text_roundTripsUTF8() {
    let input = "hello\n世界"
    let encoded = CodecToolkitCore.encodeBase64Text(input)
    let decoded = CodecToolkitCore.decodeBase64Text(encoded)
    XCTAssertNil(decoded.error)
    XCTAssertEqual(decoded.result, input)
  }

  func testCodec_timestampMilliseconds_detected() {
    let r = CodecToolkitCore.convertTimestampOrDate("1700000000000")
    XCTAssertNil(r.error)
    XCTAssertTrue(r.result.contains("Source: Unix milliseconds"))
    XCTAssertTrue(r.result.contains("Unix seconds: 1700000000"))
    XCTAssertTrue(r.result.contains("Unix milliseconds: 1700000000000"))
    XCTAssertTrue(r.result.contains("UTC: 2023-11-14 22:13:20 UTC"))
  }

  func testCodec_datetimeISO_convertsToUnix() {
    let r = CodecToolkitCore.convertTimestampOrDate("2023-11-14T22:13:20Z")
    XCTAssertNil(r.error)
    XCTAssertTrue(r.result.contains("Source: datetime"))
    XCTAssertTrue(r.result.contains("Unix seconds: 1700000000"))
  }

  func testCodec_jwtDecode_outputsHeaderPayloadAndNoVerificationClaim() {
    let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjMiLCJpYXQiOjE3MDAwMDAwMDB9.sig"
    let r = CodecToolkitCore.decodeJWT(token)
    XCTAssertNil(r.error)
    XCTAssertTrue(r.result.contains("\"alg\" : \"HS256\""))
    XCTAssertTrue(r.result.contains("\"sub\" : \"123\""))
    XCTAssertTrue(r.result.contains("iat: Source: Unix seconds | Unix seconds: 1700000000"))
    XCTAssertTrue(r.result.contains("Signature verification: not performed"))
  }

  func testCodec_base64URLSegment_decodesUnpaddedJWTPart() {
    let data = CodecToolkitCore.decodeBase64URLSegment("eyJzdWIiOiIxMjMifQ")
    XCTAssertEqual(String(data: data!, encoding: .utf8), #"{"sub":"123"}"#)
  }

  func testCodec_imageDataURI_decodesPayloadBytes() {
    let payload = Data([0, 1, 2, 3, 255])
    let uri = CodecToolkitCore.dataURI(mime: "image/png", data: payload)
    XCTAssertEqual(CodecToolkitCore.decodeBase64Data(uri), payload)
  }

  func testQRCode_generateAndDecode_roundTrips() {
    let text = "jj-dev-MTL QR"
    guard let image = QRCodeEngine.makeQRCodeImage(text: text) else {
      XCTFail("QR image generation failed")
      return
    }
    XCTAssertEqual(QRCodeEngine.decodeQRCode(from: image), [text])
  }

  @MainActor
  func testCodecToolkit_timestampStartsWithEditableInputAndReadonlyResult() {
    let vc = CodecToolkitViewController(tool: Tool(id: "codec-toolkit", title: "Codecs / Tokens"))
    vc.loadView()
    vc.view.frame = NSRect(x: 0, y: 0, width: 900, height: 560)
    vc.view.layoutSubtreeIfNeeded()

    let textViews = allTextViews(in: vc.view).filter { !hasHiddenAncestor($0) }
    XCTAssertEqual(textViews.count, 2)
    XCTAssertEqual(textViews.filter { $0.isEditable }.count, 1)
    XCTAssertEqual(textViews.filter { !$0.isEditable }.count, 1)
    XCTAssertFalse(textViews.first { $0.isEditable }?.string.isEmpty ?? true)
  }

  @MainActor
  func testCodecToolkit_qrCodeUsesSingleEditableTextInput() {
    let vc = CodecToolkitViewController(tool: Tool(id: "codec-toolkit", title: "Codecs / Tokens"))
    vc.loadView()
    vc.view.frame = NSRect(x: 0, y: 0, width: 900, height: 560)
    vc.view.layoutSubtreeIfNeeded()

    // v0.3.0: 模块选择器已移到顶部 tab 栏, 由 RootTabViewController 通过 selectModule 驱动.
    // QR = 第 5 个模块 (timestamp/url/base64/jwt/qr, index 4).
    vc.selectModule(4)
    vc.view.layoutSubtreeIfNeeded()

    let textViews = allTextViews(in: vc.view).filter { !hasHiddenAncestor($0) }
    XCTAssertEqual(textViews.count, 1)
    XCTAssertEqual(textViews.filter { $0.isEditable }.count, 1)
  }

  // MARK: - 辅助

  private func allTextViews(in view: NSView) -> [NSTextView] {
    var out = view as? NSTextView == nil ? [] : [view as! NSTextView]
    for subview in view.subviews {
      out.append(contentsOf: allTextViews(in: subview))
    }
    if let scroll = view as? NSScrollView, let textView = scroll.documentView as? NSTextView {
      out.append(textView)
    }
    return NSOrderedSet(array: out).array as? [NSTextView] ?? out
  }

  private func hasHiddenAncestor(_ view: NSView) -> Bool {
    var cur: NSView? = view
    while let v = cur {
      if v.isHidden { return true }
      cur = v.superview
    }
    return false
  }

  private static func stubSession(status: Int, data: Data) -> URLSession {
    StubURLProtocol.status = status
    StubURLProtocol.data = data
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
  }

  // 独立规范化: 与 TextUtilsCore.serialize 同款 writing options, 用于比对格式化输出
  private func canonical(_ json: String) -> String {
    let data = json.data(using: .utf8)!
    let obj = try! JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    let out = try! JSONSerialization.data(
      withJSONObject: obj,
      options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed])
    return String(data: out, encoding: .utf8)!
  }
}

final class StubURLProtocol: URLProtocol {
  nonisolated(unsafe) static var status = 200
  nonisolated(unsafe) static var data = Data()

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url,
      let response = HTTPURLResponse(
        url: url, statusCode: Self.status, httpVersion: "HTTP/1.1", headerFields: nil)
    else { return }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
