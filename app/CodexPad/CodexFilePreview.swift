import Foundation

/// File previews retain the existing byte cap. A cut through the final UTF-8
/// scalar must not make an otherwise readable prefix look like a binary file.
struct CodexFilePreview: Sendable {
    let text: String
    let isTruncated: Bool
    let isBinary: Bool

    static func decode(_ data: Data, limit: Int = 200_000) -> Self {
        let byteLimit = max(0, limit)
        let truncated = data.count > byteLimit
        let prefix = Data(data.prefix(byteLimit))
        if !prefix.contains(0) {
            if let text = String(data: prefix, encoding: .utf8) {
                return Self(text: text, isTruncated: truncated, isBinary: false)
            }
            if truncated && !prefix.isEmpty {
                // UTF-8 scalars have at most four bytes; only the last three
                // bytes can be an incomplete tail. Invalid earlier bytes stay
                // unavailable rather than being silently replaced.
                for tail in 1...min(3, prefix.count) {
                    let scalarStart = prefix.count - tail
                    let lead = data[data.startIndex + scalarStart]
                    let width: Int
                    switch lead {
                    case 0xC2...0xDF: width = 2
                    case 0xE0...0xEF: width = 3
                    case 0xF0...0xF4: width = 4
                    default: continue
                    }
                    guard tail < width, scalarStart + width <= data.count else { continue }
                    let scalarRange = (data.startIndex + scalarStart)..<(data.startIndex + scalarStart + width)
                    guard String(data: data[scalarRange], encoding: .utf8) != nil else { continue }
                    if let text = String(data: prefix.dropLast(tail), encoding: .utf8) {
                        return Self(text: text, isTruncated: true, isBinary: false)
                    }
                }
            }
        }
        return Self(text: "Non-UTF-8 or binary file — preview unavailable",
                    isTruncated: truncated, isBinary: true)
    }
}
