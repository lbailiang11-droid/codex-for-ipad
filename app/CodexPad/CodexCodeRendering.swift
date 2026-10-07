import Foundation

/// Deliberately lexical: these spans decorate source without claiming to parse it.
enum CodexCodeTokenKind: String, Equatable, Sendable {
    case keyword
    case string
    case comment
    case number
    case literal
    case typeName
}

struct CodexCodeSpan: Equatable, Sendable {
    /// UTF-16 offsets into the unchanged source, usable with NSString/NSRange.
    let range: NSRange
    let kind: CodexCodeTokenKind
}

enum CodexCodeLanguage {
    static func canonical(_ language: String?) -> String? {
        guard let language else { return nil }
        let value = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "swift": return "swift"
        case "python", "py", "python3": return "python"
        case "javascript", "js", "jsx", "node": return "javascript"
        case "typescript", "ts", "tsx": return "typescript"
        case "json": return "json"
        case "jsonc": return "jsonc"
        case "c", "h": return "c"
        case "cpp", "c++", "cc", "cxx", "hpp": return "cpp"
        case "objc", "objective-c", "objectivec", "obj-c": return "objective-c"
        case "java": return "java"
        case "shell", "sh", "bash", "zsh", "console": return "shell"
        default: return nil
        }
    }

    static func language(forFileName fileName: String) -> String? {
        let name = fileName.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/").last.map(String.init)?.lowercased() ?? ""
        if name == ".bashrc" || name == ".zshrc" || name == ".profile" { return "shell" }
        guard let dot = name.lastIndex(of: ".") else { return nil }
        let ext = String(name[name.index(after: dot)...])
        switch ext {
        case "swift": return "swift"
        case "py", "pyi", "pyw": return "python"
        case "js", "jsx", "mjs", "cjs": return "javascript"
        case "ts", "tsx", "mts", "cts": return "typescript"
        case "json": return "json"
        case "jsonc": return "jsonc"
        case "c", "h": return "c"
        case "cpp", "cc", "cxx", "hpp", "hh", "hxx": return "cpp"
        case "m", "mm": return "objective-c"
        case "java": return "java"
        case "sh", "bash", "zsh": return "shell"
        default: return nil
        }
    }

    static func displayName(_ language: String?) -> String {
        switch canonical(language) {
        case "swift": return "Swift"
        case "python": return "Python"
        case "javascript": return "JavaScript"
        case "typescript": return "TypeScript"
        case "json": return "JSON"
        case "jsonc": return "JSONC"
        case "c": return "C"
        case "cpp": return "C++"
        case "objective-c": return "Objective-C"
        case "java": return "Java"
        case "shell": return "Shell"
        default:
            let value = language?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? "Code" : value
        }
    }
}

enum CodexCodeHighlighter {
    // Above either limit the complete source is still shown/copied, uncoloured.
    static let maximumUTF16Count = 80_000
    static let maximumSpanCount = 6_000

    static func spans(in code: String, language: String?) -> [CodexCodeSpan] {
        guard let language = CodexCodeLanguage.canonical(language),
              code.utf16.count <= maximumUTF16Count else { return [] }
        return CodeLexer(code: code, language: language).scan()
    }
}

private struct CodeLexer {
    let language: String
    let scalars: [Unicode.Scalar]
    let utf16Offsets: [Int]

    init(code: String, language: String) {
        self.language = language
        scalars = Array(code.unicodeScalars)
        var offsets = [0]
        offsets.reserveCapacity(scalars.count + 1)
        for scalar in scalars {
            offsets.append(offsets[offsets.count - 1] + (scalar.value > 0xFFFF ? 2 : 1))
        }
        utf16Offsets = offsets
    }

    func scan() -> [CodexCodeSpan] {
        var spans: [CodexCodeSpan] = []
        var index = 0
        let words = keywords
        let types = typeNames
        let values = literals

        func append(_ start: Int, _ end: Int, _ kind: CodexCodeTokenKind) {
            spans.append(CodexCodeSpan(
                range: NSRange(location: utf16Offsets[start], length: utf16Offsets[end] - utf16Offsets[start]),
                kind: kind
            ))
        }

        while index < scalars.count {
            if spans.count >= CodexCodeHighlighter.maximumSpanCount { return [] }
            let start = index

            if supportsSlashComments && matches(index, "//") {
                index = lineEnd(from: index + 2)
                append(start, index, .comment)
            } else if supportsSlashComments && matches(index, "/*") {
                index = blockCommentEnd(from: index)
                append(start, index, .comment)
            } else if scalars[index] == "#" && isHashComment(at: index) {
                index = lineEnd(from: index + 1)
                append(start, index, .comment)
            } else if language == "swift", let raw = swiftRawString(at: index) {
                index = stringEnd(quoteIndex: raw.quoteIndex, hashes: raw.hashes)
                append(start, index, .string)
            } else if isQuote(scalars[index]) {
                index = stringEnd(quoteIndex: index)
                append(start, index, .string)
            } else if isDigit(scalars[index]) || startsFraction(at: index) {
                index = numberEnd(from: index)
                append(start, index, .number)
            } else if isIdentifierStart(scalars[index]) {
                index += 1
                while index < scalars.count && isIdentifierPart(scalars[index]) { index += 1 }
                let word = String(String.UnicodeScalarView(scalars[start..<index]))
                if index < scalars.count && isQuote(scalars[index]) && isStringPrefix(word) {
                    index = stringEnd(quoteIndex: index)
                    append(start, index, .string)
                } else if values.contains(word) {
                    append(start, index, .literal)
                } else if words.contains(word) {
                    append(start, index, .keyword)
                } else if types.contains(word) {
                    append(start, index, .typeName)
                }
            } else {
                index += 1
            }
        }
        return spans
    }

    private var supportsSlashComments: Bool {
        language != "python" && language != "shell" && language != "json"
    }

    private func matches(_ index: Int, _ value: String) -> Bool {
        let pattern = value.unicodeScalars
        guard index + pattern.count <= scalars.count else { return false }
        return zip(scalars[index..<(index + pattern.count)], pattern).allSatisfy { $0.0 == $0.1 }
    }

    private func lineEnd(from start: Int) -> Int {
        var index = start
        while index < scalars.count && !isNewline(scalars[index]) { index += 1 }
        return index
    }

    private func blockCommentEnd(from start: Int) -> Int {
        var index = start + 2
        var depth = 1
        while index < scalars.count {
            if language == "swift" && matches(index, "/*") {
                depth += 1
                index += 2
            } else if matches(index, "*/") {
                depth -= 1
                index += 2
                if depth == 0 { return index }
            } else {
                index += 1
            }
        }
        return index
    }

    private func isHashComment(at index: Int) -> Bool {
        if language == "python" { return true }
        // Shell's parameter expansion ${name#prefix} is not a comment.
        return language == "shell" && (index == 0 || CharacterSet.whitespacesAndNewlines.contains(scalars[index - 1]))
    }

    private func swiftRawString(at index: Int) -> (quoteIndex: Int, hashes: Int)? {
        guard scalars[index] == "#" else { return nil }
        var quoteIndex = index
        while quoteIndex < scalars.count && scalars[quoteIndex] == "#" { quoteIndex += 1 }
        guard quoteIndex < scalars.count && scalars[quoteIndex] == "\"" else { return nil }
        return (quoteIndex, quoteIndex - index)
    }

    private func isQuote(_ scalar: Unicode.Scalar) -> Bool {
        if scalar == "\"" { return true }
        if scalar == "'" { return language != "json" && language != "jsonc" && language != "swift" }
        return scalar == "`" && (language == "javascript" || language == "typescript" || language == "shell")
    }

    private func isStringPrefix(_ word: String) -> Bool {
        if language == "python" {
            return ["r", "b", "u", "f", "br", "rb", "fr", "rf"].contains(word.lowercased())
        }
        if language == "c" || language == "cpp" || language == "objective-c" {
            return ["L", "u", "U", "u8"].contains(word)
        }
        return false
    }

    private func stringEnd(quoteIndex: Int, hashes: Int = 0) -> Int {
        let quote = scalars[quoteIndex]
        let supportsTriple = language == "python" || language == "swift"
        let triple = supportsTriple && quoteIndex + 2 < scalars.count && scalars[quoteIndex + 1] == quote && scalars[quoteIndex + 2] == quote
        let delimiterLength = triple ? 3 : 1
        let multiline = triple || quote == "`" || language == "shell"
        var index = quoteIndex + delimiterLength
        while index < scalars.count {
            if !multiline && isNewline(scalars[index]) { return index }
            if scalars[index] == "\\" && !(language == "shell" && quote == "'") {
                var escapeEnd = index + 1
                var matchedHashes = 0
                while matchedHashes < hashes && escapeEnd < scalars.count && scalars[escapeEnd] == "#" {
                    matchedHashes += 1
                    escapeEnd += 1
                }
                if matchedHashes == hashes {
                    index = min(escapeEnd + 1, scalars.count)
                    continue
                }
            }
            if index + delimiterLength + hashes <= scalars.count {
                let closesQuote = (0..<delimiterLength).allSatisfy { scalars[index + $0] == quote }
                let closesHashes = (0..<hashes).allSatisfy { scalars[index + delimiterLength + $0] == "#" }
                if closesQuote && closesHashes { return index + delimiterLength + hashes }
            }
            index += 1
        }
        return index
    }

    private func startsFraction(at index: Int) -> Bool {
        guard scalars[index] == ".", index + 1 < scalars.count, isDigit(scalars[index + 1]) else { return false }
        return index == 0 || (!isIdentifierPart(scalars[index - 1]) && scalars[index - 1] != ".")
    }

    private func numberEnd(from start: Int) -> Int {
        var index = start
        if matches(index, "0x") || matches(index, "0X") {
            index += 2
            while index < scalars.count && (isHex(scalars[index]) || scalars[index] == "_") { index += 1 }
            return index
        }
        if matches(index, "0b") || matches(index, "0B") {
            index += 2
            while index < scalars.count && (scalars[index] == "0" || scalars[index] == "1" || scalars[index] == "_") { index += 1 }
            return index
        }
        if matches(index, "0o") || matches(index, "0O") {
            index += 2
            while index < scalars.count && ((scalars[index].value >= 48 && scalars[index].value <= 55) || scalars[index] == "_") { index += 1 }
            return index
        }
        var hasDot = false
        var hasExponent = false
        while index < scalars.count {
            if isDigit(scalars[index]) || scalars[index] == "_" {
                index += 1
            } else if scalars[index] == "." && !hasDot && !hasExponent && index + 1 < scalars.count && isDigit(scalars[index + 1]) {
                hasDot = true
                index += 1
            } else if (scalars[index] == "e" || scalars[index] == "E") && !hasExponent {
                var next = index + 1
                if next < scalars.count && (scalars[next] == "+" || scalars[next] == "-") { next += 1 }
                guard next < scalars.count && isDigit(scalars[next]) else { return index }
                hasExponent = true
                index = next + 1
            } else {
                return index
            }
        }
        return index
    }

    private func isDigit(_ scalar: Unicode.Scalar) -> Bool { scalar.value >= 48 && scalar.value <= 57 }
    private func isHex(_ scalar: Unicode.Scalar) -> Bool {
        isDigit(scalar) || (scalar.value >= 65 && scalar.value <= 70) || (scalar.value >= 97 && scalar.value <= 102)
    }
    private func isNewline(_ scalar: Unicode.Scalar) -> Bool { CharacterSet.newlines.contains(scalar) }
    private func isIdentifierStart(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "_" || scalar == "$" || CharacterSet.letters.contains(scalar)
            || (language == "swift" && scalar.properties.generalCategory == .otherSymbol)
    }
    private func isIdentifierPart(_ scalar: Unicode.Scalar) -> Bool {
        isIdentifierStart(scalar) || CharacterSet.decimalDigits.contains(scalar)
            || CharacterSet.nonBaseCharacters.contains(scalar) || scalar == "\u{200D}"
    }

    private var keywords: Set<String> {
        switch language {
        case "swift":
            return Set("associatedtype actor async await borrowing break case catch class consuming continue convenience defer deinit didSet do dynamic else enum extension fallthrough fileprivate final for func get guard if import in indirect infix init inout internal is isolated lazy let macro mutating nonisolated nonmutating open operator optional override package postfix precedencegroup prefix private protocol public repeat required rethrows return set some static struct subscript super switch throws throw try typealias unowned var weak where while willSet".split(separator: " ").map(String.init))
        case "python":
            return Set("and as assert async await break case class continue def del elif else except finally for from global if import in is lambda match nonlocal not or pass raise return try while with yield".split(separator: " ").map(String.init))
        case "javascript", "typescript":
            return Set("abstract as async await break case catch class const continue debugger declare default delete do else enum export extends finally for from function get if implements import in infer instanceof interface keyof let namespace new of private protected public readonly return satisfies set static super switch this throw try type typeof var void while with yield".split(separator: " ").map(String.init))
        case "shell":
            return Set("if then else elif fi for while until do done case esac in function select time coproc export readonly local declare unset return break continue".split(separator: " ").map(String.init))
        case "c", "cpp", "objective-c", "java":
            return Set("alignas alignof asm auto break case catch class const constexpr consteval constinit continue default delete do else enum explicit export extern final for friend goto if inline import namespace new noexcept operator override package private protected public register restrict return sizeof static static_assert struct super switch synchronized template this throw throws transient try typedef typename union using virtual volatile while _Atomic _Bool _Complex _Generic _Imaginary _Noreturn _Static_assert _Thread_local".split(separator: " ").map(String.init))
        default: return []
        }
    }

    private var typeNames: Set<String> {
        switch language {
        case "swift": return ["Any", "AnyObject", "Bool", "Character", "Double", "Float", "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "String", "Array", "Dictionary", "Set", "Optional", "Result", "Void"]
        case "python": return ["bool", "bytes", "dict", "float", "int", "list", "object", "set", "str", "tuple"]
        case "typescript": return ["any", "bigint", "boolean", "never", "number", "object", "string", "symbol", "unknown"]
        case "c", "cpp", "objective-c", "java": return ["bool", "boolean", "byte", "char", "double", "float", "int", "long", "short", "signed", "unsigned", "void", "wchar_t", "size_t", "String", "id", "BOOL"]
        default: return []
        }
    }

    private var literals: Set<String> {
        switch language {
        case "swift": return ["true", "false", "nil", "self", "Self"]
        case "python": return ["True", "False", "None", "Ellipsis", "NotImplemented"]
        case "javascript", "typescript": return ["true", "false", "null", "undefined", "NaN", "Infinity"]
        case "json", "jsonc": return ["true", "false", "null"]
        case "c", "cpp", "objective-c", "java": return ["true", "false", "null", "nullptr", "NULL", "nil", "YES", "NO"]
        default: return []
        }
    }
}

enum CodexMarkdownBlock: Equatable, Sendable {
    case prose(String)
    case code(String, language: String?)
}

/// Removes fence marker lines only; code whitespace and CRLF are retained exactly.
enum CodexCodeFences {
    static func blocks(in text: String) -> [CodexMarkdownBlock] {
        var result: [CodexMarkdownBlock] = []
        var buffer = ""
        var fence: (marker: Character, count: Int, language: String?)?
        var lineStart = text.startIndex

        func consume(_ content: Substring, raw: Substring) {
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            if let active = fence {
                let prefix = trimmed.prefix(while: { $0 == active.marker })
                if prefix.count >= active.count && trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces).isEmpty {
                    result.append(.code(buffer, language: active.language))
                    buffer = ""
                    fence = nil
                } else {
                    buffer.append(contentsOf: raw)
                }
            } else if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = trimmed.first!
                let prefix = trimmed.prefix(while: { $0 == marker })
                let info = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                // A backtick inside a backtick fence's info is not an opening fence.
                if marker == "`" && info.contains("`") {
                    buffer.append(contentsOf: raw)
                    return
                }
                if !buffer.isEmpty { result.append(.prose(buffer)) }
                buffer = ""
                let language = info.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
                fence = (marker, prefix.count, language)
            } else {
                buffer.append(contentsOf: raw)
            }
        }

        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(after: index)
            if text[index].isNewline {
                consume(text[lineStart..<index], raw: text[lineStart..<next])
                lineStart = next
            }
            index = next
        }
        if lineStart < text.endIndex {
            consume(text[lineStart..<text.endIndex], raw: text[lineStart..<text.endIndex])
        }
        if let active = fence {
            result.append(.code(buffer, language: active.language))
        } else if !buffer.isEmpty {
            result.append(.prose(buffer))
        }
        return result
    }
}
