import SwiftUI
import UIKit

/// A native source viewer. `code` is the exact visible preview/block; callers
/// presenting a truncated preview should pass copyLabel: "Copy preview".
struct CodexCodeView: View {
    let code: String
    var language: String? = nil
    var showsLineNumbers = false
    var copyID: String? = nil
    var copyLabel = "Copy code"

    @ScaledMetric(relativeTo: .body) private var codeFontSize: CGFloat = 14
    @State private var highlighted: CodexCodePresentation?
    @State private var copied = false
    @State private var copyFeedbackTask: Task<Void, Never>?

    private var request: CodexCodeRequest {
        CodexCodeRequest(code: code, language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Label(CodexCodeLanguage.displayName(language), systemImage: "curlybraces")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CodexPalette.secondaryInk)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button(action: copyCode) {
                    Label(copied ? "Copied" : copyLabel, systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(CodexPalette.cobalt)
                .disabled(code.isEmpty)
                .accessibilityLabel(copied ? "Copied to clipboard" : copyLabel)
                .accessibilityIdentifier(copyID ?? "codexpad.code.copy")
            }
            .padding(.horizontal, 12)

            Divider().overlay(CodexPalette.line)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    if showsLineNumbers {
                        Text(verbatim: lineNumbers)
                            .foregroundStyle(CodexPalette.secondaryInk)
                            .multilineTextAlignment(.trailing)
                            .accessibilityHidden(true)
                    }
                    codeText
                        .textSelection(.enabled)
                }
                .font(.system(size: codeFontSize, design: .monospaced))
                .lineSpacing(4)
                .fixedSize(horizontal: true, vertical: false)
                .padding(12)
            }
            .accessibilityLabel("\(CodexCodeLanguage.displayName(language)) code")
        }
        .background(CodexPalette.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(CodexPalette.line, lineWidth: 0.5)
        }
        .task(id: request) {
            let currentRequest = request
            let spans = await CodexCodeHighlightCache.shared.spans(for: currentRequest)
            guard !Task.isCancelled else { return }
            guard !spans.isEmpty else {
                highlighted = nil
                return
            }
            let colors = Self.tokenColors
            let defaultColor = CodexPalette.ink
            // Attribute construction is also off the main actor; while it runs,
            // the exact current source remains visible as ordinary native Text.
            let text = await Task.detached(priority: .utility) {
                Self.attributedCode(currentRequest.code, spans: spans, colors: colors, defaultColor: defaultColor)
            }.value
            guard !Task.isCancelled else { return }
            highlighted = CodexCodePresentation(request: currentRequest, text: text)
        }
        .onChange(of: code) { _, _ in
            copyFeedbackTask?.cancel()
            copied = false
        }
        .onDisappear {
            copyFeedbackTask?.cancel()
            copied = false
        }
    }

    @ViewBuilder
    private var codeText: some View {
        if let highlighted, highlighted.request == request {
            Text(highlighted.text)
        } else {
            Text(verbatim: code)
                .foregroundStyle(CodexPalette.ink)
        }
    }

    private var lineNumbers: String {
        // Character regards CRLF as one newline; the source itself is untouched.
        let count = code.reduce(into: 1) { count, character in
            if character.isNewline { count += 1 }
        }
        return (1...count).map(String.init).joined(separator: "\n")
    }

    private func copyCode() {
        UIPasteboard.general.string = code
        copied = true
        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }

    private static var tokenColors: [CodexCodeTokenKind: Color] {
        [
            .keyword: CodexPalette.syntaxKeyword,
            .string: CodexPalette.syntaxString,
            .comment: CodexPalette.syntaxComment,
            .number: CodexPalette.syntaxNumber,
            .literal: CodexPalette.syntaxNumber,
            .typeName: CodexPalette.syntaxType
        ]
    }

    nonisolated private static func attributedCode(
        _ source: String,
        spans: [CodexCodeSpan],
        colors: [CodexCodeTokenKind: Color],
        defaultColor: Color
    ) -> AttributedString {
        var result = AttributedString()
        let utf16 = source.utf16
        var cursor = utf16.startIndex
        var offset = 0
        let count = utf16.count
        // Spans are sorted and nonoverlapping. Advance once through UTF-16,
        // rather than searching from the beginning for each token's range.
        for span in spans {
            guard span.range.location >= offset, span.range.length > 0,
                  span.range.location <= count,
                  span.range.length <= count - span.range.location else {
                var fallback = AttributedString(source)
                fallback.foregroundColor = defaultColor
                return fallback
            }
            let start = utf16.index(cursor, offsetBy: span.range.location - offset)
            let end = utf16.index(start, offsetBy: span.range.length)
            if cursor < start {
                var plain = AttributedString(String(source[cursor..<start]))
                plain.foregroundColor = defaultColor
                result.append(plain)
            }
            var token = AttributedString(String(source[start..<end]))
            token.foregroundColor = colors[span.kind]
            result.append(token)
            cursor = end
            offset = span.range.location + span.range.length
        }
        if cursor < utf16.endIndex {
            var plain = AttributedString(String(source[cursor...]))
            plain.foregroundColor = defaultColor
            result.append(plain)
        }
        return result
    }
}

private struct CodexCodeRequest: Hashable, Sendable {
    let code: String
    let language: String?
}

private struct CodexCodePresentation {
    let request: CodexCodeRequest
    let text: AttributedString
}

/// Lexing is serialized off the main actor and shared between previews/blocks.
/// Cache budgets retain at most 16 results and 320k UTF-16 units of source.
private actor CodexCodeHighlightCache {
    static let shared = CodexCodeHighlightCache()
    private var entries: [CodexCodeRequest: [CodexCodeSpan]] = [:]
    private var order: [CodexCodeRequest] = []
    private var utf16Cost = 0

    func spans(for request: CodexCodeRequest) -> [CodexCodeSpan] {
        guard CodexCodeLanguage.canonical(request.language) != nil,
              request.code.utf16.count <= CodexCodeHighlighter.maximumUTF16Count else { return [] }
        if let cached = entries[request] {
            order.removeAll { $0 == request }
            order.append(request)
            return cached
        }
        let result = CodexCodeHighlighter.spans(in: request.code, language: request.language)
        let cost = request.code.utf16.count
        while !order.isEmpty && (order.count >= 16 || utf16Cost + cost > 320_000) {
            let oldest = order.removeFirst()
            utf16Cost -= oldest.code.utf16.count
            entries.removeValue(forKey: oldest)
        }
        entries[request] = result
        order.append(request)
        utf16Cost += cost
        return result
    }
}
