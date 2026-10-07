import Foundation

/// Conservative unified-diff presentation. Unsupported or incomplete patches
/// keep their original text and never contribute invented line statistics.
struct CodexDiffDocument: Sendable {
    let rawText: String
    let files: [CodexDiffFile]

    var additions: Int { files.compactMap(\.additions).reduce(0, +) }
    var deletions: Int { files.compactMap(\.deletions).reduce(0, +) }
    var hasIncompleteStatistics: Bool { files.contains { $0.additions == nil } }

    static func parse(_ rawText: String) -> Self {
        guard !rawText.isEmpty else { return Self(rawText: rawText, files: []) }
        let source = rawText.components(separatedBy: "\n")
        let lines = source.map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
        let starts = lines.indices.filter {
            lines[$0].hasPrefix("diff --git ") || lines[$0].hasPrefix("diff --cc ")
                || lines[$0].hasPrefix("diff --combined ")
        }
        var result: [CodexDiffFile] = []
        func original(_ range: Range<Int>) -> String {
            source[range].joined(separator: "\n") + (range.upperBound < source.count ? "\n" : "")
        }
        if !starts.isEmpty {
            if let first = starts.first, first > 0 {
                result.append(.raw(original(0..<first), note: "Patch preamble — original text"))
            }
            for (offset, start) in starts.enumerated() {
                let end = offset + 1 < starts.count ? starts[offset + 1] : lines.count
                result.append(parseGitFile(Array(lines[start..<end]), raw: original(start..<end)))
            }
        } else if lines.count >= 2, lines[0].hasPrefix("--- "), lines[1].hasPrefix("+++ ") {
            // Consume counted hunks before recognizing another file header.
            // Deleted/added content can itself begin with --- / +++.
            var cursor = 0
            while cursor < lines.count {
                if cursor == lines.count - 1 && lines[cursor].isEmpty { break }
                let start = cursor
                guard cursor + 1 < lines.count, lines[cursor].hasPrefix("--- "),
                      lines[cursor + 1].hasPrefix("+++ ") else {
                    return Self(rawText: rawText, files: [.raw(rawText, note: "Unrecognized patch — original text")])
                }
                cursor += 2
                var hunks: [CodexDiffHunk] = []
                while cursor < lines.count && lines[cursor].hasPrefix("@@ ") {
                    guard let hunk = readHunk(lines, cursor: &cursor, ordinal: hunks.count) else {
                        return Self(rawText: rawText, files: [.raw(rawText, note: "Incomplete patch — original text")])
                    }
                    guard canAppend(hunk, after: hunks.last) else {
                        return Self(rawText: rawText, files: [.raw(rawText, note: "Overlapping hunks — original text")])
                    }
                    hunks.append(hunk)
                }
                guard !hunks.isEmpty else {
                    return Self(rawText: rawText, files: [.raw(rawText, note: "Unrecognized patch — original text")])
                }
                if cursor == lines.count - 1 && lines[cursor].isEmpty { cursor += 1 }
                let old = headerPath(lines[start], prefix: "--- ", stripGitPrefix: false)
                let new = headerPath(lines[start + 1], prefix: "+++ ", stripGitPrefix: false)
                guard old != nil || new != nil else {
                    return Self(rawText: rawText, files: [.raw(rawText, note: "Missing file path — original text")])
                }
                result.append(makeFile(old: old, new: new, raw: original(start..<cursor), kind: .text, hunks: hunks))
            }
        } else {
            result = [.raw(rawText, note: "Unrecognized patch — original text")]
        }
        var occurrences: [String: Int] = [:]
        result = result.map { file in
            let occurrence = occurrences[file.path, default: 0]
            occurrences[file.path] = occurrence + 1
            return file.withIdentity("\(file.path)#\(occurrence)")
        }
        return Self(rawText: rawText, files: result)
    }

    private static func parseGitFile(_ lines: [String], raw: String) -> CodexDiffFile {
        guard let first = lines.first, first.hasPrefix("diff --git ") else {
            return .raw(raw, note: "Combined patch — original text")
        }
        let paths = gitHeaderPaths(String(first.dropFirst("diff --git ".count)))
        var old = paths.map { stripPrefix($0.0) }
        var new = paths.map { stripPrefix($0.1) }
        let fallbackPath = new ?? old ?? String(first.dropFirst("diff --git ".count))
        var cursor = 1
        var hunks: [CodexDiffHunk] = []
        var hasHeaders = false
        var isNew = false
        var isDeleted = false
        var hasMetadata = false
        var renameFrom = false, renameTo = false, copyFrom = false, copyTo = false
        var oldMode = false, newMode = false, identicalRename = false
        var indexHashes: (String, String)?
        while cursor < lines.count {
            let line = lines[cursor]
            if cursor == lines.count - 1 && line.isEmpty { break }
            if line.hasPrefix("Binary files ") || line == "GIT binary patch" {
                return makeFile(old: old, new: new, raw: raw, kind: .binary, hunks: [],
                                path: new ?? old ?? fallbackPath, note: "Binary change — original patch")
            } else if line.hasPrefix("--- ") {
                guard !hasHeaders, hunks.isEmpty, cursor + 1 < lines.count,
                      lines[cursor + 1].hasPrefix("+++ ") else {
                    return .raw(raw, path: fallbackPath, note: "Invalid file headers — original text")
                }
                old = headerPath(line, prefix: "--- ", stripGitPrefix: true)
                new = headerPath(lines[cursor + 1], prefix: "+++ ", stripGitPrefix: true)
                hasHeaders = true
                cursor += 2
            } else if line.hasPrefix("@@ ") {
                guard hasHeaders, let hunk = readHunk(lines, cursor: &cursor, ordinal: hunks.count) else {
                    return .raw(raw, path: new ?? old ?? fallbackPath, note: "Incomplete hunk — original text")
                }
                guard canAppend(hunk, after: hunks.last) else {
                    return .raw(raw, path: new ?? old ?? fallbackPath, note: "Overlapping hunks — original text")
                }
                hunks.append(hunk)
            } else if hunks.isEmpty && line.hasPrefix("rename from ") {
                old = decodePath(String(line.dropFirst("rename from ".count)))
                renameFrom = !old!.isEmpty
                hasMetadata = true; cursor += 1
            } else if hunks.isEmpty && line.hasPrefix("rename to ") {
                new = decodePath(String(line.dropFirst("rename to ".count)))
                renameTo = !new!.isEmpty
                hasMetadata = true; cursor += 1
            } else if hunks.isEmpty && line.hasPrefix("copy from ") {
                old = decodePath(String(line.dropFirst("copy from ".count)))
                copyFrom = !old!.isEmpty
                hasMetadata = true; cursor += 1
            } else if hunks.isEmpty && line.hasPrefix("copy to ") {
                new = decodePath(String(line.dropFirst("copy to ".count)))
                copyTo = !new!.isEmpty
                hasMetadata = true; cursor += 1
            } else if hunks.isEmpty && isMetadata(line) {
                if line.hasPrefix("new file mode ") { isNew = true; old = nil }
                if line.hasPrefix("deleted file mode ") { isDeleted = true; new = nil }
                if line.hasPrefix("old mode ") { oldMode = true }
                if line.hasPrefix("new mode ") { newMode = true }
                if line == "similarity index 100%" { identicalRename = true }
                if line.hasPrefix("index ") {
                    let hashes = line.dropFirst("index ".count).split(separator: " ").first.map(String.init) ?? ""
                    let pair = hashes.components(separatedBy: "..")
                    if pair.count == 2 { indexHashes = (pair[0], pair[1]) }
                }
                hasMetadata = true; cursor += 1
            } else {
                return .raw(raw, path: new ?? old ?? fallbackPath, note: "Unsupported patch — original text")
            }
        }
        if !hunks.isEmpty {
            guard old != nil || new != nil else { return .raw(raw, note: "Missing file path — original text") }
            return makeFile(old: old, new: new, raw: raw, kind: .text, hunks: hunks)
        }
        let unchangedContent = indexHashes == nil || indexHashes!.0 == indexHashes!.1
        let completeRename = ((renameFrom && renameTo) || (copyFrom && copyTo)) && identicalRename && unchangedContent
        let completeModes = oldMode && newMode && unchangedContent
        let emptyBlob = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
        func isEmptyBlob(_ hash: String) -> Bool { hash.count >= 7 && emptyBlob.hasPrefix(hash) }
        func isZero(_ hash: String) -> Bool { !hash.isEmpty && hash.allSatisfy { $0 == "0" } }
        let emptyFile = indexHashes.map { pair in
            (isNew && isZero(pair.0) && isEmptyBlob(pair.1)) || (isDeleted && isEmptyBlob(pair.0) && isZero(pair.1))
        } ?? false
        guard hasMetadata, !hasHeaders, completeRename || completeModes || emptyFile else {
            return .raw(raw, path: fallbackPath, note: "Incomplete patch — original text")
        }
        return makeFile(old: old, new: new, raw: raw, kind: .metadata, hunks: [],
                        path: new ?? old ?? fallbackPath, isNew: isNew, isDeleted: isDeleted)
    }

    private static func isMetadata(_ value: String) -> Bool {
        ["index ", "new file mode ", "deleted file mode ", "old mode ", "new mode ",
         "similarity index ", "dissimilarity index "].contains { value.hasPrefix($0) }
    }

    private static let hunkHeader = try! NSRegularExpression(
        pattern: #"^@@ -([0-9]+)(?:,([0-9]+))? \+([0-9]+)(?:,([0-9]+))? @@.*$"#
    )

    private static func canAppend(_ hunk: CodexDiffHunk, after previous: CodexDiffHunk?) -> Bool {
        guard let previous else { return true }
        return hunk.oldStart >= previous.oldStart + previous.oldCount
            && hunk.newStart >= previous.newStart + previous.newCount
    }

    private static func readHunk(_ source: [String], cursor: inout Int, ordinal: Int) -> CodexDiffHunk? {
        let header = source[cursor]
        let ns = header as NSString
        guard let match = hunkHeader.firstMatch(in: header, range: NSRange(location: 0, length: ns.length)) else { return nil }
        func number(_ capture: Int, defaultValue: Int? = nil) -> Int? {
            let range = match.range(at: capture)
            return range.location == NSNotFound ? defaultValue : Int(ns.substring(with: range))
        }
        guard let oldStart = number(1), let oldCount = number(2, defaultValue: 1),
              let newStart = number(3), let newCount = number(4, defaultValue: 1),
              oldStart <= Int.max - oldCount, newStart <= Int.max - newCount,
              oldCount == 0 || oldStart > 0, newCount == 0 || newStart > 0 else { return nil }
        var oldRemaining = oldCount, newRemaining = newCount
        var oldNumber = oldStart, newNumber = newStart
        var lines: [CodexDiffLine] = []
        var previousWasMarker = true
        cursor += 1
        while cursor < source.count {
            let value = source[cursor]
            if value == "\\ No newline at end of file" {
                guard !previousWasMarker else { return nil }
                lines.append(CodexDiffLine(id: cursor, text: String(value.dropFirst()), kind: .noNewline,
                                           oldNumber: nil, newNumber: nil))
                previousWasMarker = true; cursor += 1
                continue
            }
            if oldRemaining == 0 && newRemaining == 0 { break }
            guard let prefix = value.first else { return nil }
            let kind: CodexDiffLine.Kind
            let old: Int?, new: Int?
            switch prefix {
            case " ":
                guard oldRemaining > 0, newRemaining > 0 else { return nil }
                kind = .context; old = oldNumber; new = newNumber
                oldRemaining -= 1; newRemaining -= 1; oldNumber += 1; newNumber += 1
            case "-":
                guard oldRemaining > 0 else { return nil }
                kind = .deletion; old = oldNumber; new = nil
                oldRemaining -= 1; oldNumber += 1
            case "+":
                guard newRemaining > 0 else { return nil }
                kind = .addition; old = nil; new = newNumber
                newRemaining -= 1; newNumber += 1
            default: return nil
            }
            lines.append(CodexDiffLine(id: cursor, text: String(value.dropFirst()), kind: kind,
                                       oldNumber: old, newNumber: new))
            previousWasMarker = false; cursor += 1
        }
        guard oldRemaining == 0, newRemaining == 0 else { return nil }
        return CodexDiffHunk(id: "\(oldStart):\(newStart):\(ordinal)", header: header, lines: lines,
                             oldStart: oldStart, oldCount: oldCount, newStart: newStart, newCount: newCount)
    }

    private static func makeFile(old: String?, new: String?, raw: String, kind: CodexDiffFile.Kind,
                                 hunks: [CodexDiffHunk], path: String? = nil, note: String? = nil,
                                 isNew: Bool? = nil, isDeleted: Bool? = nil) -> CodexDiffFile {
        let name = path ?? new ?? old ?? "Unparsed changes"
        return CodexDiffFile(id: name, path: name, previousPath: old != new ? old : nil,
                             rawText: raw, kind: kind, hunks: hunks, note: note,
                             isNewFile: isNew ?? (old == nil && new != nil),
                             isDeletedFile: isDeleted ?? (new == nil && old != nil))
    }

    private static func headerPath(_ value: String, prefix: String, stripGitPrefix: Bool) -> String? {
        let payload = String(value.dropFirst(prefix.count)).components(separatedBy: "\t")[0]
        let path = decodePath(payload)
        guard !path.isEmpty, path != "/dev/null" else { return nil }
        return stripGitPrefix ? stripPrefix(path) : path
    }

    private static func stripPrefix(_ path: String) -> String {
        path.hasPrefix("a/") || path.hasPrefix("b/") ? String(path.dropFirst(2)) : path
    }

    private static func gitHeaderWords(_ source: String) -> [String] {
        let characters = Array(source)
        var result: [String] = [], index = 0
        while index < characters.count {
            while index < characters.count && characters[index] == " " { index += 1 }
            guard index < characters.count else { break }
            let start = index
            if characters[index] == "\"" {
                index += 1
                var escaped = false, closed = false
                while index < characters.count {
                    let character = characters[index]; index += 1
                    if escaped { escaped = false }
                    else if character == "\\" { escaped = true }
                    else if character == "\"" { closed = true; break }
                }
                guard closed else { return [] }
            } else {
                while index < characters.count && characters[index] != " " { index += 1 }
            }
            result.append(decodePath(String(characters[start..<index])))
        }
        return result
    }

    private static func gitHeaderPaths(_ source: String) -> (String, String)? {
        let words = gitHeaderWords(source)
        if words.count == 2 { return (words[0], words[1]) }
        var candidates: [(String, String)] = []
        var cursor = source.startIndex
        while let separator = source.range(of: " b/", range: cursor..<source.endIndex) {
            let old = decodePath(String(source[..<separator.lowerBound]))
            let new = decodePath(String(source[source.index(after: separator.lowerBound)...]))
            if old.hasPrefix("a/") { candidates.append((old, new)) }
            cursor = separator.upperBound
        }
        if let samePath = candidates.first(where: { stripPrefix($0.0) == stripPrefix($0.1) }) { return samePath }
        return candidates.count == 1 ? candidates[0] : nil
    }

    /// Git quotePath encodes non-ASCII path bytes with octal C escapes.
    private static func decodePath(_ source: String) -> String {
        guard source.hasPrefix("\""), source.hasSuffix("\""), source.count >= 2 else { return source }
        let bytes = Array(source.utf8.dropFirst().dropLast())
        var result: [UInt8] = [], index = 0
        let escapes: [UInt8: UInt8] = [110: 10, 114: 13, 116: 9, 98: 8, 102: 12, 118: 11, 97: 7, 34: 34, 92: 92]
        while index < bytes.count {
            let byte = bytes[index]; index += 1
            if byte != 92 { result.append(byte); continue }
            guard index < bytes.count else { return source }
            if (48...55).contains(bytes[index]) {
                var value = 0, count = 0
                while index < bytes.count && count < 3 && (48...55).contains(bytes[index]) {
                    value = value * 8 + Int(bytes[index] - 48); index += 1; count += 1
                }
                guard value <= 255 else { return source }
                result.append(UInt8(value))
            } else {
                guard let decoded = escapes[bytes[index]] else { return source }
                result.append(decoded); index += 1
            }
        }
        return String(bytes: result, encoding: .utf8) ?? source
    }
}

struct CodexDiffFile: Identifiable, Sendable {
    enum Kind: Sendable { case text, metadata, binary, unparsed }
    let id: String
    let path: String
    let previousPath: String?
    let rawText: String
    let kind: Kind
    let hunks: [CodexDiffHunk]
    let note: String?
    let isNewFile: Bool
    let isDeletedFile: Bool

    var additions: Int? {
        guard kind == .text || kind == .metadata else { return nil }
        return hunks.reduce(0) { $0 + $1.lines.filter { $0.kind == .addition }.count }
    }
    var deletions: Int? {
        guard kind == .text || kind == .metadata else { return nil }
        return hunks.reduce(0) { $0 + $1.lines.filter { $0.kind == .deletion }.count }
    }
    fileprivate static func raw(_ text: String, path: String = "Unparsed changes", note: String) -> Self {
        Self(id: path, path: path, previousPath: nil, rawText: text, kind: .unparsed,
             hunks: [], note: note, isNewFile: false, isDeletedFile: false)
    }
    fileprivate func withIdentity(_ id: String) -> Self {
        Self(id: id, path: path, previousPath: previousPath, rawText: rawText, kind: kind,
             hunks: hunks, note: note, isNewFile: isNewFile, isDeletedFile: isDeletedFile)
    }
}

struct CodexDiffHunk: Identifiable, Sendable {
    let id: String
    let header: String
    let lines: [CodexDiffLine]
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
}

struct CodexDiffLine: Identifiable, Sendable {
    enum Kind: Sendable { case context, addition, deletion, noNewline }
    let id: Int
    let text: String
    let kind: Kind
    let oldNumber: Int?
    let newNumber: Int?
    var prefix: String {
        switch kind {
        case .context: " "
        case .addition: "+"
        case .deletion: "-"
        case .noNewline: "\\"
        }
    }
}
