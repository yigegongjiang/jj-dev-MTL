import Cocoa
import CoreImage
import Foundation

struct CodecResult {
  let result: String
  let error: String?
}

enum CodecToolkitCore {

  nonisolated static func encodeURLComponent(_ text: String) -> CodecResult {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    guard let encoded = text.addingPercentEncoding(withAllowedCharacters: allowed) else {
      return CodecResult(result: "", error: "URL encode failed")
    }
    return CodecResult(result: encoded, error: nil)
  }

  nonisolated static func decodeURLComponent(_ text: String) -> CodecResult {
    guard let decoded = text.removingPercentEncoding else {
      return CodecResult(result: "", error: "Invalid percent-encoded URL text")
    }
    return CodecResult(result: decoded, error: nil)
  }

  nonisolated static func encodeBase64Text(_ text: String) -> String {
    Data(text.utf8).base64EncodedString()
  }

  nonisolated static func decodeBase64Text(_ text: String) -> CodecResult {
    guard let data = decodeBase64Data(text) else {
      return CodecResult(result: "", error: "Invalid Base64")
    }
    guard let decoded = String(data: data, encoding: .utf8) else {
      return CodecResult(result: "", error: "Base64 decoded bytes are not UTF-8 text")
    }
    return CodecResult(result: decoded, error: nil)
  }

  nonisolated static func decodeBase64Data(_ text: String) -> Data? {
    guard let normalized = normalizedBase64(text) else { return nil }
    return Data(base64Encoded: normalized)
  }

  nonisolated static func dataURI(mime: String, data: Data) -> String {
    "data:\(mime);base64,\(data.base64EncodedString())"
  }

  nonisolated static func convertTimestampOrDate(_ text: String, now: Date = Date()) -> CodecResult {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return CodecResult(result: timestampSummary(now, source: "now"), error: nil)
    }

    let numericText = trimmed.replacingOccurrences(of: ",", with: "")
    if let value = Double(numericText), value.isFinite {
      let absValue = abs(value)
      let seconds: Double
      let source: String
      if absValue >= 1_000_000_000_000_000 {
        seconds = value / 1_000_000
        source = "Unix microseconds"
      } else if absValue >= 100_000_000_000 {
        seconds = value / 1_000
        source = "Unix milliseconds"
      } else {
        seconds = value
        source = "Unix seconds"
      }
      return CodecResult(result: timestampSummary(Date(timeIntervalSince1970: seconds), source: source), error: nil)
    }

    if let date = parseDate(trimmed) {
      return CodecResult(result: timestampSummary(date, source: "datetime"), error: nil)
    }

    return CodecResult(result: "", error: "Use Unix seconds/milliseconds/microseconds or ISO/local datetime")
  }

  nonisolated static func decodeJWT(_ token: String) -> CodecResult {
    let parts = token.trimmingCharacters(in: .whitespacesAndNewlines)
      .split(separator: ".", omittingEmptySubsequences: false)
      .map(String.init)
    guard parts.count == 3 else {
      return CodecResult(result: "", error: "JWT must have header.payload.signature")
    }
    guard let headerData = decodeBase64URLSegment(parts[0]) else {
      return CodecResult(result: "", error: "Invalid JWT header Base64URL")
    }
    guard let payloadData = decodeBase64URLSegment(parts[1]) else {
      return CodecResult(result: "", error: "Invalid JWT payload Base64URL")
    }

    let header = prettyJSON(headerData) ?? (String(data: headerData, encoding: .utf8) ?? "<non-UTF8 header>")
    let payload = prettyJSON(payloadData) ?? (String(data: payloadData, encoding: .utf8) ?? "<non-UTF8 payload>")
    let claimLines = jwtTimeClaims(payloadData)
    let signature = parts[2].isEmpty ? "<empty>" : parts[2]

    var sections = [
      "Header",
      header,
      "",
      "Payload",
      payload,
    ]
    if !claimLines.isEmpty {
      sections += ["", "Registered time claims"] + claimLines
    }
    sections += [
      "",
      "Signature",
      signature,
      "",
      "Signature verification: not performed",
    ]
    return CodecResult(result: sections.joined(separator: "\n"), error: nil)
  }

  nonisolated static func decodeBase64URLSegment(_ segment: String) -> Data? {
    var s = segment.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = s.count % 4
    if remainder == 1 { return nil }
    if remainder > 0 { s += String(repeating: "=", count: 4 - remainder) }
    return Data(base64Encoded: s)
  }

  nonisolated private static func normalizedBase64(_ text: String) -> String? {
    var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if body.lowercased().hasPrefix("data:"), let comma = body.firstIndex(of: ",") {
      body = String(body[body.index(after: comma)...])
    }
    var s = String(body.filter { !$0.isWhitespace })
    s = s.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = s.count % 4
    if remainder == 1 { return nil }
    if remainder > 0 { s += String(repeating: "=", count: 4 - remainder) }
    return s
  }

  nonisolated private static func parseDate(_ text: String) -> Date? {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: text) { return date }
    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: text) { return date }

    let formats = [
      "yyyy-MM-dd HH:mm:ss",
      "yyyy-MM-dd HH:mm",
      "yyyy-MM-dd'T'HH:mm:ss",
      "yyyy-MM-dd'T'HH:mm",
      "yyyy-MM-dd",
    ]
    for format in formats {
      let df = DateFormatter()
      df.locale = Locale(identifier: "en_US_POSIX")
      df.timeZone = .current
      df.dateFormat = format
      if let date = df.date(from: text) { return date }
    }
    return nil
  }

  nonisolated private static func timestampSummary(_ date: Date, source: String) -> String {
    let seconds = Int64(date.timeIntervalSince1970.rounded(.towardZero))
    let milliseconds = Int64((date.timeIntervalSince1970 * 1_000).rounded(.towardZero))
    let microseconds = Int64((date.timeIntervalSince1970 * 1_000_000).rounded(.towardZero))

    let utc = DateFormatter()
    utc.locale = Locale(identifier: "en_US_POSIX")
    utc.timeZone = TimeZone(secondsFromGMT: 0)
    utc.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"

    let local = DateFormatter()
    local.locale = Locale(identifier: "en_US_POSIX")
    local.timeZone = .current
    local.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"

    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    return """
    Source: \(source)
    Unix seconds: \(seconds)
    Unix milliseconds: \(milliseconds)
    Unix microseconds: \(microseconds)
    UTC: \(utc.string(from: date))
    Local: \(local.string(from: date))
    ISO 8601: \(iso.string(from: date))
    """
  }

  nonisolated private static func prettyJSON(_ data: Data) -> String? {
    guard let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
      let pretty = try? JSONSerialization.data(
        withJSONObject: obj,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed])
    else { return nil }
    return String(data: pretty, encoding: .utf8)
  }

  nonisolated private static func jwtTimeClaims(_ payloadData: Data) -> [String] {
    guard let obj = try? JSONSerialization.jsonObject(with: payloadData, options: []),
      let dict = obj as? [String: Any]
    else { return [] }
    return ["iat", "nbf", "exp"].compactMap { key in
      guard let value = doubleValue(dict[key]) else { return nil }
      let date = Date(timeIntervalSince1970: value)
      return "\(key): \(timestampSummary(date, source: "Unix seconds").replacingOccurrences(of: "\n", with: " | "))"
    }
  }

  nonisolated private static func doubleValue(_ value: Any?) -> Double? {
    if let n = value as? NSNumber { return n.doubleValue }
    if let s = value as? String { return Double(s) }
    return nil
  }
}

enum QRCodeEngine {

  static func makeQRCodeImage(text: String, side: CGFloat = 220) -> NSImage? {
    guard !text.isEmpty, let data = text.data(using: .utf8),
      let filter = CIFilter(name: "CIQRCodeGenerator")
    else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    guard let output = filter.outputImage else { return nil }
    let scale = max(1, side / max(output.extent.width, output.extent.height))
    let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let rep = NSCIImageRep(ciImage: scaled)
    let image = NSImage(size: rep.size)
    image.addRepresentation(rep)
    return image
  }

  static func decodeQRCode(from image: NSImage) -> [String] {
    guard let ciImage = ciImage(from: image),
      let detector = CIDetector(
        ofType: CIDetectorTypeQRCode,
        context: nil,
        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    else { return [] }
    let features = detector.features(in: ciImage) as? [CIQRCodeFeature] ?? []
    return features.compactMap(\.messageString)
  }

  static func pngData(from image: NSImage) -> Data? {
    var rect = NSRect(origin: .zero, size: image.size)
    guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
    return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
  }

  private static func ciImage(from image: NSImage) -> CIImage? {
    var rect = NSRect(origin: .zero, size: image.size)
    if let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
      return CIImage(cgImage: cg)
    }
    if let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let cg = rep.cgImage {
      return CIImage(cgImage: cg)
    }
    return nil
  }
}
