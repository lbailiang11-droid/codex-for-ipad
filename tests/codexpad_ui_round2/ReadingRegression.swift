import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(ucrt)
import ucrt
#endif

private struct ReadingAssertions {
    private(set) var count = 0
    private(set) var failures = 0

    mutating func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        count += 1
        if !condition() {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    mutating func bytes(_ actual: String, _ expected: String, _ message: String) {
        // String equality accepts canonically equivalent Unicode. Copy promises
        // the original byte sequence, including CRLF and combining characters.
        expect(Array(actual.utf8) == Array(expected.utf8), message)
    }
}

@main
private enum ReadingRegression {
    static func main() {
        var assertions = ReadingAssertions()
        testDiffs(&assertions)
        testMalformedHunks(&assertions)
        testPreviews(&assertions)
        testFences(&assertions)
        testLexer(&assertions)
        print("Reading regressions: \(assertions.count) assertions, \(assertions.failures) failures")
        if assertions.failures > 0 { exit(1) }
    }

    private static func testDiffs(_ a: inout ReadingAssertions) {
        let first = "diff --git a/a.txt b/a.txt\r\nindex 1111111..2222222 100644\r\n--- a/a.txt\r\n+++ b/a.txt\r\n@@ -1,2 +1,3 @@\r\n context\r\n-old\r\n+new\r\n+🙂 cafe\u{301}\r\n"
        let second = "diff --git a/b.txt b/b.txt\n--- a/b.txt\n+++ b/b.txt\n@@ -4 +4 @@\n-before\n+after\n"
        let raw = "Patch preamble\r\n" + first + second
        let document = CodexDiffDocument.parse(raw)
        a.bytes(document.rawText, raw, "whole Diff copy preserves the exact mixed-newline patch")
        a.expect(document.files.count == 3, "preamble and two Git files remain separate")
        a.expect(document.additions == 3 && document.deletions == 2, "aggregate counts use real added/deleted lines only")
        a.expect(document.hasIncompleteStatistics, "unparsed preamble keeps aggregate statistics explicitly incomplete")
        a.bytes(document.files.map(\.rawText).joined(), raw, "joining original file patches reconstructs the source")
        if let file = document.files.first(where: { $0.path == "a.txt" }) {
            a.bytes(file.rawText, first, "per-file patch copy retains CRLF and Unicode normalization")
            a.expect(file.additions == 2 && file.deletions == 1, "Git header and context lines do not count as changes")
            if let hunk = file.hunks.first {
                a.expect(hunk.lines.count == 4, "Git hunk retains all real content rows")
                let context = hunk.lines.first(where: { $0.kind == .context })
                let deletion = hunk.lines.first(where: { $0.kind == .deletion })
                let additions = hunk.lines.filter { $0.kind == .addition }
                a.expect(context?.oldNumber == 1 && context?.newNumber == 1, "context has both line numbers")
                a.expect(deletion?.oldNumber == 2 && deletion?.newNumber == nil, "deletion has only old line number")
                a.expect(additions.map(\.newNumber) == [2, 3], "added rows advance the new-file number")
                a.expect(additions.allSatisfy { $0.oldNumber == nil }, "added rows do not claim old-file numbers")
            } else { a.expect(false, "Git text hunk exists") }
        } else { a.expect(false, "Git a.txt file exists") }

        // These deleted/added content rows resemble file headers once prefixed.
        let plainFirst = "--- old first.txt\t2026-10-07\r\n+++ new first.txt\t2026-10-07\r\n@@ -1 +1 @@\r\n--- deleted content\r\n+++ added content\r\n"
        let plainSecond = "--- second.txt\n+++ second.txt\n@@ -3 +3 @@\n-old\n+new\n"
        let plain = CodexDiffDocument.parse(plainFirst + plainSecond)
        a.expect(plain.files.count == 2, "counted plain hunks do not split content beginning ---/+++")
        a.expect(!plain.hasIncompleteStatistics && plain.additions == 2 && plain.deletions == 2, "plain unified Diff statistics are complete")
        a.bytes(plain.files.map(\.rawText).joined(), plainFirst + plainSecond, "plain per-file copy preserves all patch bytes")
        if let file = plain.files.first {
            a.expect(file.path == "new first.txt" && file.previousPath == "old first.txt", "plain paths retain spaces and discard only tab-separated timestamps")
            a.bytes(file.rawText, plainFirst, "first plain file copy ends at the next actual file header")
            a.expect(file.hunks.first?.lines.first?.text == "-- deleted content", "leading minus content is not a new file")
        }

        let unicode = "diff --git \"a/\\346\\265\\213\\350\\257\\225.py\" \"b/\\346\\265\\213\\350\\257\\225.py\"\n--- \"a/\\346\\265\\213\\350\\257\\225.py\"\n+++ \"b/\\346\\265\\213\\350\\257\\225.py\"\n@@ -1 +1 @@\n-a\n+b\n"
        let unicodeDocument = CodexDiffDocument.parse(unicode)
        a.expect(unicodeDocument.files.first?.path == "测试.py", "Git octal path bytes decode as UTF-8")
        a.bytes(unicodeDocument.rawText, unicode, "decoded display paths never rewrite original patch copy")
        let spaces = "diff --git a/你🙂 space.txt b/你🙂 space.txt\n--- a/你🙂 space.txt\n+++ b/你🙂 space.txt\n@@ -1 +1 @@\n-a\n+b\n"
        a.expect(CodexDiffDocument.parse(spaces).files.first?.path == "你🙂 space.txt", "unquoted Unicode paths with spaces remain readable")

        let binary = "diff --git a/image.png b/image.png\nindex 1111111..2222222 100644\nBinary files a/image.png and b/image.png differ\n"
        let binaryDocument = CodexDiffDocument.parse(binary)
        a.expect(binaryDocument.files.first?.kind == .binary, "binary change has explicit binary presentation")
        a.expect(binaryDocument.files.first?.additions == nil && binaryDocument.hasIncompleteStatistics, "binary patch has unknown text-line counts")
        a.bytes(binaryDocument.files.first?.rawText ?? "", binary, "binary patch copy is the real patch")
        let gitBinary = "diff --git a/image.bin b/image.bin\nGIT binary patch\nliteral 3\nKcmZQzU|?Vb0000\n"
        a.expect(CodexDiffDocument.parse(gitBinary).files.first?.kind == .binary, "Git binary payload stays a binary patch")
        let mixedBinary = "diff --git \"a/\\346\\265\\213.bin\" b/new name.bin\nrename from \"\\346\\265\\213.bin\"\nrename to new name.bin\nBinary files differ\n"
        let mixedFile = CodexDiffDocument.parse(mixedBinary).files.first
        a.expect(mixedFile?.path == "new name.bin" && mixedFile?.previousPath == "测.bin", "binary rename uses resolved paths with mixed quoting and spaces")
        a.bytes(mixedFile?.rawText ?? "", mixedBinary, "binary rename retains original patch bytes")

        let rename = "diff --git a/old name.txt b/new name.txt\nsimilarity index 100%\nrename from old name.txt\nrename to new name.txt\n"
        let renameFile = CodexDiffDocument.parse(rename).files.first
        a.expect(renameFile?.kind == .metadata && renameFile?.additions == 0 && renameFile?.deletions == 0, "complete identical rename legitimately has zero line changes")
        a.expect(renameFile?.path == "new name.txt" && renameFile?.previousPath == "old name.txt", "rename source and destination remain distinct")
        let mode = "diff --git a/run.sh b/run.sh\nold mode 100644\nnew mode 100755\n"
        a.expect(CodexDiffDocument.parse(mode).files.first?.kind == .metadata, "complete mode-only change is metadata")
        let empty = "diff --git a/empty b/empty\nnew file mode 100644\nindex 0000000..e69de29\n"
        let emptyFile = CodexDiffDocument.parse(empty).files.first
        a.expect(emptyFile?.isNewFile == true && emptyFile?.additions == 0, "known empty blob can prove zero added lines")
        let noNewline = "diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -1 +1 @@\n-old\n\\ No newline at end of file\n+new\n\\ No newline at end of file\n"
        let noNewlineFile = CodexDiffDocument.parse(noNewline).files.first
        a.expect(noNewlineFile?.additions == 1 && noNewlineFile?.deletions == 1, "no-newline markers do not inflate statistics")
        a.expect(noNewlineFile?.hunks.first?.lines.filter { $0.kind == .noNewline }.count == 2, "both no-newline markers remain visible")
        a.expect(CodexDiffDocument.parse("").files.isEmpty, "empty Diff has no invented file")

        let duplicatePaths = second + second
        let duplicateFiles = CodexDiffDocument.parse(duplicatePaths).files
        a.expect(duplicateFiles.count == 2 && Set(duplicateFiles.map(\.id)).count == 2, "repeated paths have distinct stable row identities")
    }

    private static func unknown(_ raw: String, _ label: String, _ a: inout ReadingAssertions) {
        let parsed = CodexDiffDocument.parse(raw)
        a.expect(parsed.hasIncompleteStatistics, "\(label): incomplete statistics are explicit")
        a.expect(parsed.files.allSatisfy { $0.additions == nil && $0.deletions == nil }, "\(label): no fabricated zero counts")
        a.bytes(parsed.rawText, raw, "\(label): whole copy remains byte exact")
        a.bytes(parsed.files.map(\.rawText).joined(), raw, "\(label): fallback keeps all original patch text")
    }

    private static func testMalformedHunks(_ a: inout ReadingAssertions) {
        let gitHeaders = "diff --git a/x b/x\n--- a/x\n+++ b/x\n"
        let plainHeaders = "--- x\n+++ x\n"
        let cases: [(String, String)] = [
            ("truncated", "@@ -1,2 +1,2 @@\n-old\n+new\n"),
            ("duplicate", "@@ -1 +1 @@\n-a\n+b\n@@ -1 +1 @@\n-c\n+d\n"),
            ("reverse", "@@ -10 +10 @@\n-a\n+b\n@@ -2 +2 @@\n-c\n+d\n"),
            ("overlap old", "@@ -1,2 +1,2 @@\n a\n-b\n+c\n@@ -2 +3 @@\n-d\n+e\n"),
            ("overlap new", "@@ -1,2 +1,2 @@\n a\n-b\n+c\n@@ -3 +2 @@\n-d\n+e\n"),
            ("overflow", "@@ -\(Int.max),1 +1,1 @@\n-a\n+b\n"),
            ("invalid zero origin", "@@ -0,1 +1,1 @@\n-a\n+b\n"),
            ("orphan no-newline", "@@ -1 +1 @@\n\\ No newline at end of file\n-a\n+b\n")
        ]
        for (label, hunks) in cases {
            unknown(gitHeaders + hunks, "Git \(label)", &a)
            unknown(plainHeaders + hunks, "plain \(label)", &a)
        }
        unknown("diff --git a/x b/x\nindex 1111111..2222222 100644\n", "changed index-only patch", &a)
        unknown("diff --git a/x b/x\nnew file mode 100644\n", "new file without proven empty blob", &a)
        unknown("diff --git a/x b/y\nsimilarity index 70%\nrename from x\nrename to y\n", "rename with missing changed content", &a)
        unknown("diff --cc x\n@@@ -1,1 -1,1 +1,1 @@@\n++value\n", "combined Diff", &a)
        unknown("not a unified patch\r\n🙂\t\r\n", "unsupported raw text", &a)
    }

    private static func testPreviews(_ a: inout ReadingAssertions) {
        let source = "A🙂中éZ"
        let data = Data(source.utf8)
        let expected = [0: "", 1: "A", 2: "A", 3: "A", 4: "A", 5: "A🙂", 6: "A🙂", 7: "A🙂", 8: "A🙂中", 9: "A🙂中", 10: "A🙂中é", 11: source]
        for limit in 0...11 {
            let preview = CodexFilePreview.decode(data, limit: limit)
            a.bytes(preview.text, expected[limit]!, "UTF-8 cap at byte \(limit) keeps only complete scalars")
            a.expect(!preview.isBinary, "UTF-8 boundary \(limit) is text, not binary")
            a.expect(preview.isTruncated == (limit < data.count), "UTF-8 boundary \(limit) exposes actual truncation")
        }
        let raw = "\t中\r\ncafe\u{301}\n"
        let complete = CodexFilePreview.decode(Data(raw.utf8))
        a.bytes(complete.text, raw, "complete preview retains tabs, CRLF and combining characters")
        a.expect(!complete.isTruncated && !complete.isBinary, "complete text is neither capped nor binary")
        let empty = CodexFilePreview.decode(Data())
        a.expect(empty.text.isEmpty && !empty.isBinary && !empty.isTruncated, "empty file is readable empty text")
        let negative = CodexFilePreview.decode(Data("ABC".utf8), limit: -10)
        a.expect(negative.text.isEmpty && negative.isTruncated && !negative.isBinary, "negative cap safely becomes zero")
        a.expect(CodexFilePreview.decode(Data([0x41, 0, 0x42])).isBinary, "NUL inside valid UTF-8 still signals binary preview")
        a.expect(CodexFilePreview.decode(Data([0xFF, 0xFE, 0x42])).isBinary, "uncapped invalid UTF-8 has no invented decoded text")
        for bytes in [[UInt8(0x41), 0xFF, 0x42, 0x43], [0x41, 0x80, 0x42, 0x43], [0x41, 0xE2, 0x41, 0x42], [0x41, 0xF0, 0x80, 0x80, 0x80, 0x42]] {
            a.expect(CodexFilePreview.decode(Data(bytes), limit: 2).isBinary, "invalid capped tail cannot be repaired by deleting arbitrary bad bytes")
        }
        let invalidBeforeValidTail = Data([0x41, 0xFF, 0xF0, 0x9F, 0x99, 0x82, 0x42])
        a.expect(CodexFilePreview.decode(invalidBeforeValidTail, limit: 4).isBinary, "valid incomplete final scalar cannot hide an earlier invalid byte")
        let padded = Data([0xFF] + Array("A🙂Z".utf8))
        let sliced = CodexFilePreview.decode(padded.dropFirst(), limit: 3)
        a.expect(sliced.text == "A" && sliced.isTruncated && !sliced.isBinary, "Data slice with nonzero startIndex repairs only its true UTF-8 boundary")
    }

    private static func testFences(_ a: inout ReadingAssertions) {
        let raw = "Before\r\n```swift extra-info\r\n\tlet emoji = \"🙂\"\r\n```\r\nAfter"
        let blocks = CodexCodeFences.blocks(in: raw)
        a.expect(blocks.count == 3, "prose and fenced code are distinct native blocks")
        if blocks.count == 3 {
            a.expect(blocks[0] == .prose("Before\r\n") && blocks[2] == .prose("After"), "surrounding prose is retained")
            if case .code(let value, let language) = blocks[1] {
                a.bytes(value, "\tlet emoji = \"🙂\"\r\n", "code copy keeps original tab, emoji and final CRLF")
                a.expect(language == "swift", "fence's first info word carries language metadata")
            } else { a.expect(false, "middle block is code") }
        }
        let longer = "````python\nx = \"```\"\n```\n````\n"
        a.expect(CodexCodeFences.blocks(in: longer) == [.code("x = \"```\"\n```\n", language: "python")], "shorter or inline backticks do not prematurely close a long fence")
        a.expect(CodexCodeFences.blocks(in: "~~~js\nconst x = 1;\n~~~~\n") == [.code("const x = 1;\n", language: "js")], "tilde fence accepts a longer matching closer")
        a.expect(CodexCodeFences.blocks(in: "```json\n```\n") == [.code("", language: "json")], "empty completed code block remains explicit")
        a.expect(CodexCodeFences.blocks(in: "```swift\nlet x = ") == [.code("let x = ", language: "swift")], "unterminated streaming fence shows current raw code")
        a.expect(CodexCodeFences.blocks(in: "```swift\n") == [.code("", language: "swift")], "new streaming fence does not invent code")
        a.expect(CodexCodeFences.blocks(in: "```sh\n\n\t  \n```") == [.code("\n\t  \n", language: "sh")], "code's blank and whitespace-only lines remain byte exact")
        let invalid = "```bad`info\nplain\n"
        a.expect(CodexCodeFences.blocks(in: invalid) == [.prose(invalid)], "backtick in info prevents a false fence")
        a.expect(CodexCodeFences.blocks(in: "").isEmpty, "empty markdown has no invented block")
    }

    private static func fragment(_ span: CodexCodeSpan, in source: String) -> String {
        let text = source as NSString
        guard span.range.location >= 0, span.range.length >= 0,
              span.range.location <= text.length,
              span.range.length <= text.length - span.range.location else { return "<invalid range>" }
        return text.substring(with: span.range)
    }

    private static func checkedSpans(_ source: String, _ language: String, _ a: inout ReadingAssertions) -> [CodexCodeSpan] {
        let spans = CodexCodeHighlighter.spans(in: source, language: language)
        var end = 0
        for span in spans {
            a.expect(span.range.location >= end && span.range.length > 0 && NSMaxRange(span.range) <= (source as NSString).length, "\(language) spans are positive, ordered, nonoverlapping UTF-16 ranges")
            a.expect(Range(span.range, in: source) != nil, "\(language) range never splits a UTF-16 surrogate")
            end = NSMaxRange(span.range)
        }
        return spans
    }

    private static func testLexer(_ a: inout ReadingAssertions) {
        let swift = "let cafe\u{301} = \"🙂 // literal\" // 注释\nlet 分数 = 1.25e-3\nreturn nil"
        let spans = checkedSpans(swift, "swift", &a)
        a.expect(spans.filter { $0.kind == .comment }.count == 1, "slash comment inside Swift string is not a comment token")
        a.expect(spans.contains { $0.kind == .string && fragment($0, in: swift) == "\"🙂 // literal\"" }, "Swift quoted Unicode string is one intact span")
        a.expect(spans.contains { $0.kind == .number && fragment($0, in: swift) == "1.25e-3" }, "scientific number keeps exponent sign in its range")
        a.expect(spans.contains { $0.kind == .literal && fragment($0, in: swift) == "nil" }, "Swift nil has literal semantics")
        let returnSpan = spans.first { fragment($0, in: swift) == "return" }
        a.expect(returnSpan?.range.location == (swift as NSString).range(of: "return").location, "UTF-16 offsets after emoji and decomposed Unicode match original source")

        let escaped = "const char *s = \"quote \\\" /* not comment */\"; // actual"
        let escapedSpans = checkedSpans(escaped, "c", &a)
        a.expect(escapedSpans.filter { $0.kind == .comment }.map { fragment($0, in: escaped) } == ["// actual"], "escaped C quote does not expose comments inside its string")
        let rawSwift = ##"let message = #"quote \" // literal"# // real"##
        let rawSpans = checkedSpans(rawSwift, "swift", &a)
        a.expect(rawSpans.filter { $0.kind == .comment }.map { fragment($0, in: rawSwift) } == ["// real"], "Swift raw delimiter keeps unmatched quote and slash inside string")
        a.expect(rawSpans.contains { $0.kind == .string && fragment($0, in: rawSwift).hasPrefix("#\"") && fragment($0, in: rawSwift).hasSuffix("\"#") }, "raw-string range includes hash delimiters")
        let nested = "/* outer /* inner */ still outer */ let x = true"
        let nestedSpans = checkedSpans(nested, "swift", &a)
        a.expect(nestedSpans.filter { $0.kind == .comment }.map { fragment($0, in: nested) } == ["/* outer /* inner */ still outer */"], "Swift nested block comment closes at matching depth")
        a.expect(nestedSpans.contains { $0.kind == .keyword && fragment($0, in: nested) == "let" }, "code after nested comment is still highlighted")

        let python = "f\"\"\"line\n# not a comment {value}\n\"\"\"\nreturn True # actual"
        let pythonSpans = checkedSpans(python, "py", &a)
        a.expect(pythonSpans.filter { $0.kind == .comment }.map { fragment($0, in: python) } == ["# actual"], "Python triple-string hash is not a comment")
        a.expect(pythonSpans.contains { $0.kind == .string && fragment($0, in: python).hasPrefix("f\"\"\"") }, "Python string prefix is included in the span")
        a.expect(pythonSpans.contains { $0.kind == .literal && fragment($0, in: python) == "True" }, "Python boolean has literal semantics")
        let pythonRaw = ##"r"\"#still-string" # real"##
        let pythonRawSpans = checkedSpans(pythonRaw, "python", &a)
        a.expect(pythonRawSpans.filter { $0.kind == .comment }.map { fragment($0, in: pythonRaw) } == ["# real"], "Python raw-string escaped quote does not end the token early")

        let js = "const value = `line\n// not comment ${x}`; /* actual */ true"
        let jsSpans = checkedSpans(js, "js", &a)
        a.expect(jsSpans.filter { $0.kind == .comment }.map { fragment($0, in: js) } == ["/* actual */"], "JavaScript multiline template remains one string")
        a.expect(jsSpans.contains { $0.kind == .literal && fragment($0, in: js) == "true" }, "JavaScript boolean literal is recognized")
        let json = "{\"true\": false, \"text\": \"// literal\", \"n\": -2.5e+3}"
        let jsonSpans = checkedSpans(json, "json", &a)
        a.expect(!jsonSpans.contains { $0.kind == .comment }, "JSON quoted slash text never becomes a comment")
        a.expect(jsonSpans.filter { $0.kind == .literal }.map { fragment($0, in: json) } == ["false"], "JSON key named true is not a boolean token")
        a.expect(jsonSpans.contains { $0.kind == .number && fragment($0, in: json) == "2.5e+3" }, "JSON scientific number is exact while minus remains an operator")
        let shell = "value=${name#prefix}\necho '#not-comment' \"#also literal\" # real"
        let shellSpans = checkedSpans(shell, "bash", &a)
        a.expect(shellSpans.filter { $0.kind == .comment }.map { fragment($0, in: shell) } == ["# real"], "shell parameter trimming and quoted hashes do not begin comments")

        let streaming = "let value = \"unfinished 🙂"
        let streamingSpans = checkedSpans(streaming, "swift", &a)
        a.expect(streamingSpans.contains { $0.kind == .string && NSMaxRange($0.range) == (streaming as NSString).length }, "unfinished streamed string remains a valid bounded span")
        a.expect(CodexCodeHighlighter.spans(in: "select 123 // raw", language: "sql").isEmpty, "unknown language deliberately stays plain")
        a.expect(CodexCodeHighlighter.spans(in: "let value = 3", language: nil).isEmpty, "missing language deliberately stays plain")
        a.expect(CodexCodeLanguage.language(forFileName: "C:\\work\\你🙂 file.TSX") == "typescript", "file inference supports Windows paths, Unicode and case-insensitive extensions")
        a.expect(CodexCodeLanguage.language(forFileName: "/root/.bashrc") == "shell", "known shell startup filename is recognized")
        a.expect(CodexCodeLanguage.language(forFileName: "README.md") == nil, "unknown file extension does not guess a syntax")
        let atLimit = "let x = \"" + String(repeating: "a", count: 79_990) + "\""
        a.expect(atLimit.utf16.count == CodexCodeHighlighter.maximumUTF16Count, "large fixture reaches exact documented UTF-16 budget")
        a.expect(!CodexCodeHighlighter.spans(in: atLimit, language: "swift").isEmpty, "exact source budget remains highlightable")
        let overLimit = "let x = \"" + String(repeating: "🙂", count: 40_001) + "\""
        a.expect(CodexCodeHighlighter.spans(in: overLimit, language: "swift").isEmpty, "surrogate-heavy source above UTF-16 budget falls back to complete plain text")
        let tokenBudget = String(repeating: "if true ", count: 3_100)
        a.expect(tokenBudget.utf16.count < CodexCodeHighlighter.maximumUTF16Count && CodexCodeHighlighter.spans(in: tokenBudget, language: "swift").isEmpty, "token-heavy small source also obeys span budget")
    }
}
