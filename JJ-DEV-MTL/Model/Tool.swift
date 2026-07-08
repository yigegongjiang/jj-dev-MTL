import Cocoa

struct Tool {
  let id: String
  let title: String
  let symbolName: String
}

enum ToolCatalog {
  static let all: [Tool] = [
    Tool(id: "json-formatter", title: "Format JSON", symbolName: "curlybraces"),
    Tool(id: "text-multiline-to-singleline", title: "Multiline → Singleline", symbolName: "arrow.right.to.line"),
    Tool(id: "text-singleline-to-multiline", title: "Singleline → Multiline", symbolName: "arrow.left.to.line"),
    Tool(id: "base64", title: "Base64 Encoder / Decoder", symbolName: "number"),
    Tool(id: "url-codec", title: "URL Encoder / Decoder", symbolName: "link"),
    Tool(id: "hash", title: "Hash Generator", symbolName: "number.square"),
    Tool(id: "uuid", title: "UUID Generator", symbolName: "die.face.5"),
    Tool(id: "timestamp", title: "Unix Timestamp", symbolName: "clock"),
    Tool(id: "regex", title: "Regex Tester", symbolName: "textformat.abc.dottedunderline"),
    Tool(id: "diff", title: "Text Diff", symbolName: "doc.on.doc"),
  ]
}
