import SwiftUI

/// Presentation-only states share the same surface and reading rules. The caller
/// owns the state, progress label, and every action; this view does not retry or
/// change workspace data on its own.
enum CodexStateTone {
    case neutral, accent, warning, danger

    var color: Color {
        switch self {
        case .neutral: CodexPalette.secondaryInk
        case .accent: CodexPalette.cobalt
        case .warning: CodexPalette.amber
        case .danger: CodexPalette.danger
        }
    }
}

struct CodexStateCard<Actions: View>: View {
    let title: String
    let message: String
    let systemImage: String
    let tone: CodexStateTone
    let progress: String?
    private let actions: Actions

    init(
        title: String,
        message: String,
        systemImage: String,
        tone: CodexStateTone = .neutral,
        progress: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tone = tone
        self.progress = progress
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(tone.color)
                    .frame(width: 48, height: 48)
                    .background(tone.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(CodexPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(CodexPalette.secondaryInk)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let progress {
                HStack(spacing: 12) {
                    ProgressView().tint(tone.color)
                        .accessibilityHidden(true)
                    Text(progress)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(tone.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .codexPanel(padding: 24)
        .accessibilityElement(children: .contain)
    }
}

extension CodexStateCard where Actions == EmptyView {
    init(title: String, message: String, systemImage: String, tone: CodexStateTone = .neutral, progress: String? = nil) {
        self.init(title: title, message: message, systemImage: systemImage, tone: tone, progress: progress) {
            EmptyView()
        }
    }
}

private struct CodexRequestHeader: View {
    let title: String
    let status: String
    let systemImage: String
    let tone: CodexStateTone

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(status, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(tone.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .fixedSize(horizontal: false, vertical: true)
            Text(title)
                .font(.headline)
                .foregroundStyle(CodexPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EngineStatusPill: View {
    let phase: EnginePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .symbolEffect(.pulse, isActive: isAnimated && !reduceMotion)
            Text(phase.title)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 30)
        .background(color.opacity(0.11), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Engine status, \(phase.title)")
    }

    private var icon: String {
        switch phase {
        case .starting, .connecting: "bolt.horizontal.circle"
        case .ready: "ipad.and.arrow.forward"
        case .offline: "pause.circle"
        }
    }

    private var color: Color {
        switch phase {
        case .ready: CodexPalette.teal
        case .offline: CodexPalette.amber
        case .starting, .connecting: CodexPalette.cobalt
        }
    }

    private var isAnimated: Bool {
        switch phase {
        case .starting, .connecting: true
        default: false
        }
    }
}

struct ThreadRow: View {
    let thread: CodexThreadRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: activityIcon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(activityColor)
                .frame(width: 20, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text(thread.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(CodexPalette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .accessibilityHidden(true)
                    Text(workspaceName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.caption)
                .foregroundStyle(CodexPalette.secondaryInk)

                HStack(spacing: 8) {
                    Text(activityLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(activityColor)
                        .lineLimit(1)
                    if let nickname = thread.agentNickname {
                        Text(nickname)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(CodexPalette.cobalt)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(CodexPalette.cobalt.opacity(0.1), in: Capsule())
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(thread.title), \(activityLabel), \(thread.cwd)")
        .accessibilityIdentifier("codexpad.thread.\(thread.id)")
    }

    private var activityIcon: String {
        switch thread.activity {
        case .idle: "circle"
        case .running: "play.circle.fill"
        case .waiting: "hand.raised.circle.fill"
        case .offline: "circle.dotted"
        case .failed: "exclamationmark.circle.fill"
        }
    }

    private var workspaceName: String {
        thread.cwd.split(separator: "/").last.map(String.init) ?? thread.cwd
    }

    private var activityColor: Color {
        switch thread.activity {
        case .idle, .offline: CodexPalette.secondaryInk
        case .running: CodexPalette.teal
        case .waiting: CodexPalette.amber
        case .failed: CodexPalette.danger
        }
    }

    private var activityLabel: String {
        switch thread.activity {
        case .idle: "idle"
        case .running: "running"
        case .waiting: "waiting for approval"
        case .offline: "not loaded"
        case .failed: "failed"
        }
    }
}

struct TimelineCard: View {
    let item: TimelineItem
    let isFirst: Bool
    let isLast: Bool

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    // Nil follows the item's live state. A user's explicit choice survives deltas
    // and completion; the containing ForEach must identify rows by item.id.
    @State private var outputExpansionOverride: Bool?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ActivityLoomMark(
                kind: item.kind,
                state: item.state,
                isFirst: isFirst,
                isLast: isLast
            )
            card
        }
        .padding(.bottom, isMessage ? 24 : 12)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var card: some View {
        VStack(alignment: .leading, spacing: isMessage ? 12 : 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(item.title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                if item.kind != .user {
                    Label(stateLabel, systemImage: stateIcon)
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(stateColor)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            if item.kind == .reasoning {
                DisclosureGroup(isExpanded: outputExpansion) {
                    bodyText
                        .padding(.top, 8)
                } label: {
                    Text("Show reasoning summary").frame(minHeight: 44, alignment: .leading)
                }
                .font(.subheadline)
            } else if foldsBody {
                Text(bodyPreview)
                    .font(.callout)
                    .foregroundStyle(CodexPalette.secondaryInk)
                    .lineLimit(3)
                DisclosureGroup(isExpanded: outputExpansion) {
                    bodyText.padding(.top, 8)
                    if !item.detail.isEmpty {
                        detailText.padding(.top, 8)
                    }
                } label: {
                    Text("Show full content").frame(minHeight: 44, alignment: .leading)
                }
                .font(.subheadline)
            } else if !item.body.isEmpty {
                bodyText
            }

            if !item.detail.isEmpty && !foldsBody {
                if isActivity && hasLongDetail {
                    DisclosureGroup(isExpanded: outputExpansion) {
                        detailText.padding(.top, 8)
                    } label: {
                        Text("Show output").frame(minHeight: 44, alignment: .leading)
                    }
                    .font(.subheadline)
                } else {
                    detailText
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(item.kind == .agent ? 0 : 16)
        .background {
            if item.kind == .user {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CodexPalette.userSurface)
            } else if isActivity {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CodexPalette.surface)
            }
        }
        .overlay(alignment: .leading) {
            if differentiateWithoutColor && item.state == .failed {
                Rectangle().fill(CodexPalette.danger).frame(width: 4).clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var bodyText: some View {
        if item.kind == .command {
            ScrollView(.horizontal) {
                Text(item.body)
                    .font(.callout.monospaced())
                    .foregroundStyle(CodexPalette.ink)
                    .fixedSize(horizontal: true, vertical: false)
                    .textSelection(.enabled)
                    .padding(.vertical, 2)
            }
        } else {
            TimelineBodyText(text: item.body, copyPrefix: "codexpad.timeline.\(item.id)")
        }
    }

    private var detailText: some View {
        ScrollView(.horizontal) {
            Text(item.detail)
                .font(.callout.monospaced())
                .foregroundStyle(CodexPalette.ink)
                .fixedSize(horizontal: true, vertical: false)
                .textSelection(.enabled)
                .padding(12)
        }
        .background(CodexPalette.canvas, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("Output")
    }

    private var isMessage: Bool { item.kind == .user || item.kind == .agent }
    private var isActivity: Bool { !isMessage }
    private var hasLongDetail: Bool { isLong(item.detail) }
    private var foldsBody: Bool {
        isActivity && item.kind != .command && item.kind != .reasoning && isLong(item.body)
    }

    private func isLong(_ text: String) -> Bool {
        text.count > 600 || text.split(separator: "\n", omittingEmptySubsequences: false).count > 10
    }

    private var bodyPreview: String {
        String(item.body.prefix(180))
    }

    private var outputExpansion: Binding<Bool> {
        Binding(
            get: { outputExpansionOverride ?? defaultOutputExpanded },
            set: { outputExpansionOverride = $0 }
        )
    }

    private var defaultOutputExpanded: Bool {
        if item.kind == .reasoning {
            return item.state == .running || item.state == .failed
        }
        return item.state != .completed
    }

    private var stateColor: Color {
        switch item.state {
        case .pending, .declined: CodexPalette.amber
        case .running: CodexPalette.cobalt
        case .completed: CodexPalette.secondaryInk
        case .failed: CodexPalette.danger
        }
    }

    private var icon: String {
        switch item.kind {
        case .user: "person.fill"
        case .agent: "sparkles"
        case .reasoning: "brain.head.profile"
        case .plan: "checklist"
        case .command: "terminal"
        case .fileChange: "doc.badge.gearshape"
        case .tool: "wrench.and.screwdriver"
        case .search: "globe"
        case .notice: "info.circle"
        }
    }

    private var accent: Color {
        switch item.kind {
        case .user: CodexPalette.secondaryInk
        case .agent, .plan: CodexPalette.cobalt
        case .command, .tool: CodexPalette.teal
        case .fileChange: CodexPalette.amber
        case .reasoning, .search, .notice: CodexPalette.secondaryInk
        }
    }

    private var stateIcon: String {
        switch item.state {
        case .pending: "clock"
        case .running: "arrow.trianglehead.2.clockwise.rotate.90"
        case .completed: "checkmark"
        case .failed: "xmark"
        case .declined: "hand.raised"
        }
    }

    private var stateLabel: String {
        switch item.state {
        case .pending: "Pending"
        case .running: "Running"
        case .completed: "Done"
        case .failed: "Failed"
        case .declined: "Declined"
        }
    }
}

/// Body prose keeps its line breaks; fenced source uses the same native code
/// renderer as file previews without widening the conversation.
private struct TimelineBodyText: View {
    let text: String
    let copyPrefix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                switch block {
                case .prose(let value):
                    prose(value)
                case .code(let value, let language):
                    CodexCodeView(
                        code: value,
                        language: language,
                        copyID: "\(copyPrefix).code.\(index)"
                    )
                }
            }
        }
        .foregroundStyle(CodexPalette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func prose(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(value.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                if !paragraph.isEmpty {
                    let style = paragraphStyle(paragraph)
                    Text(inlineMarkdown(style.text))
                        .font(style.font)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, style.isQuote ? 12 : 0)
                        .overlay(alignment: .leading) {
                            if style.isQuote {
                                Rectangle().fill(CodexPalette.line).frame(width: 2)
                            }
                        }
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func inlineMarkdown(_ value: String) -> AttributedString {
        (try? AttributedString(
            markdown: value,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(value)
    }

    private func paragraphStyle(_ value: String) -> (text: String, font: Font, isQuote: Bool) {
        let heading = value.trimmingCharacters(in: .newlines)
        if !heading.contains("\n") {
            for (prefix, font) in [("# ", Font.title2.weight(.semibold)), ("## ", Font.title3.weight(.semibold)), ("### ", Font.headline)] {
                if heading.hasPrefix(prefix) {
                    return (String(heading.dropFirst(prefix.count)), font, false)
                }
            }
        }
        let lines = value.components(separatedBy: "\n")
        if lines.allSatisfy({ $0.hasPrefix("> ") || $0 == ">" }) {
            return (lines.map { String($0.dropFirst($0 == ">" ? 1 : 2)) }.joined(separator: "\n"), .body, true)
        }
        return (value, .body, false)
    }

    private var blocks: [CodexMarkdownBlock] {
        CodexCodeFences.blocks(in: text)
    }
}

private struct ActivityLoomMark: View {
    let kind: TimelineKind
    let state: TimelineState
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : CodexPalette.line)
                .frame(width: 2, height: 8)
            ZStack {
                Circle()
                    .fill(CodexPalette.canvas)
                    .frame(width: 27, height: 27)
                Circle()
                    .strokeBorder(nodeColor, lineWidth: state == .running ? 3 : 2)
                    .frame(width: 21, height: 21)
                if state == .completed {
                    Circle().fill(nodeColor).frame(width: 7, height: 7)
                }
            }
            Rectangle()
                .fill(isLast ? Color.clear : CodexPalette.line)
                .frame(width: 2)
        }
        .frame(width: 28)
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    private var nodeColor: Color {
        if state == .failed { return CodexPalette.danger }
        if state == .pending || state == .declined { return CodexPalette.amber }
        switch kind {
        case .agent, .plan: return CodexPalette.cobalt
        case .command, .tool: return CodexPalette.teal
        case .fileChange: return CodexPalette.amber
        default: return CodexPalette.secondaryInk
        }
    }
}

struct ApprovalRequestCard: View {
    let request: PendingServerRequest
    let resolve: (ApprovalChoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CodexRequestHeader(
                title: request.title,
                status: request.kind == .unsupported ? "Unsupported request" : request.kind == .elicitation ? "Response required" : "Approval required",
                systemImage: request.kind == .fileChange ? "doc.badge.gearshape" : "hand.raised.fill",
                tone: .warning
            )
            Text(request.message)
                .font(.body)
                .foregroundStyle(CodexPalette.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if !request.detail.isEmpty {
                ScrollView(.horizontal) {
                    Text(request.detail)
                        .font(.callout.monospaced())
                        .foregroundStyle(CodexPalette.ink)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(12)
                }
                .background(CodexPalette.canvas, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    actionButtons
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 10) {
                    actionButtons
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .controlSize(.large)
        .codexPanel()
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CodexPalette.amber.opacity(0.65), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("codexpad.approval.\(request.id)")
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch request.kind {
        case .elicitation:
            Button("Decline", role: .destructive) { resolve(.decline) }
                .buttonStyle(.bordered)
                .tint(CodexPalette.danger)
                .frame(minHeight: 44)
                .accessibilityIdentifier("codexpad.approval.decline.\(request.id)")
            Button("Cancel request", role: .cancel) { resolve(.cancel) }
                .buttonStyle(.bordered)
                .tint(CodexPalette.secondaryInk)
                .frame(minHeight: 44)
                .accessibilityIdentifier("codexpad.approval.cancel.\(request.id)")
        case .unsupported:
            Button("Dismiss") { resolve(.decline) }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .accessibilityIdentifier("codexpad.approval.dismiss.\(request.id)")
        default:
            Button("Allow once") { resolve(.once) }
                .buttonStyle(.borderedProminent)
                .tint(CodexPalette.cobalt)
                .frame(minHeight: 44)
                .accessibilityIdentifier("codexpad.approval.once.\(request.id)")
            Button("Allow for thread") { resolve(.session) }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .accessibilityIdentifier("codexpad.approval.session.\(request.id)")
            Button("Don’t allow", role: .destructive) { resolve(.decline) }
                .buttonStyle(.bordered)
                .tint(CodexPalette.danger)
                .frame(minHeight: 44)
                .accessibilityIdentifier("codexpad.approval.decline.\(request.id)")
        }
    }
}

struct QuestionRequestCard: View {
    let request: PendingServerRequest
    let submit: ([String: String]) -> Void

    @State private var answers: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CodexRequestHeader(
                title: request.title,
                status: "Answer required",
                systemImage: "questionmark.bubble.fill",
                tone: .accent
            )
            ForEach(request.questions) { question in
                VStack(alignment: .leading, spacing: 12) {
                    Text(question.header)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CodexPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(question.prompt)
                        .font(.body)
                        .foregroundStyle(CodexPalette.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    if !question.options.isEmpty {
                        Picker(question.header, selection: answerBinding(for: question.id)) {
                            Text("Choose").tag("")
                            ForEach(question.options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(CodexPalette.cobalt)
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .background(CodexPalette.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(CodexPalette.line, lineWidth: 1)
                        }
                        .accessibilityIdentifier("codexpad.question.options.\(question.id)")
                        if !question.isSecret, let answer = answers[question.id], question.options.contains(answer) {
                            // Native menu controls may shorten a long selected label.
                            // Keep that complete option readable without changing the
                            // same binding used by freeform and structured answers.
                            Text(answer)
                                .font(.callout)
                                .foregroundStyle(CodexPalette.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                    if question.allowsFreeform || question.options.isEmpty {
                        if question.isSecret {
                            SecureField("Your answer", text: answerBinding(for: question.id))
                                .textFieldStyle(.roundedBorder)
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("codexpad.question.field.\(question.id)")
                        } else {
                            TextField("Your answer", text: answerBinding(for: question.id), axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("codexpad.question.field.\(question.id)")
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CodexPalette.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Button("Send answers") { submit(answers) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 44)
                .tint(CodexPalette.cobalt)
                .accessibilityIdentifier("codexpad.question.submit.\(request.id)")
                .disabled(request.questions.contains { answers[$0.id, default: ""].isEmpty })
        }
        .codexPanel()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("codexpad.question.\(request.id)")
    }

    private func answerBinding(for id: String) -> Binding<String> {
        Binding(
            get: { answers[id, default: ""] },
            set: { answers[id] = $0 }
        )
    }
}

struct AdvancedServerRequestCard: View {
    let request: PendingServerRequest
    let submit: (String) async -> String?
    let reject: () -> Void

    @State private var resultText = ""
    @State private var validationError: String?
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CodexRequestHeader(title: request.title, status: "Response required", systemImage: "curlybraces.square", tone: .accent)
            Text(request.method)
                .font(.caption.monospaced())
                .foregroundStyle(CodexPalette.secondaryInk)
                .textSelection(.enabled)
            Text(request.message)
                .font(.body)
                .foregroundStyle(CodexPalette.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup("Request parameters") {
                ScrollView(.horizontal) {
                    Text(request.rawParams.prettyPrinted)
                        .font(.callout.monospaced())
                        .foregroundStyle(CodexPalette.ink)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(12)
                }
                .background(CodexPalette.canvas, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 6)
            }
            .font(.subheadline)
            .tint(CodexPalette.cobalt)
            TextEditor(text: $resultText)
                .font(.callout.monospaced())
                .foregroundStyle(CodexPalette.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 130)
                .padding(8)
                .background(CodexPalette.canvas, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(CodexPalette.line, lineWidth: 0.5)
                }
                .accessibilityLabel("JSON response for \(request.method)")
                .accessibilityIdentifier("codexpad.advanced.response.\(request.id)")

            if let validationError {
                Label(validationError, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(CodexPalette.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("codexpad.advanced.error.\(request.id)")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { actionButtons }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 10) { actionButtons }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .codexPanel()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("codexpad.advanced.\(request.id)")
        .task {
            if request.method == "item/tool/call" {
                resultText = JSONValue.object([
                    "contentItems": .array([.object([
                        "type": .string("inputText"),
                        "text": .string("")
                    ])]),
                    "success": .bool(true)
                ]).prettyPrinted
            } else {
                resultText = "{}"
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            isSubmitting = true
            validationError = nil
            Task {
                validationError = await submit(resultText)
                isSubmitting = false
            }
        } label: {
            if isSubmitting {
                ProgressView().controlSize(.small)
            } else {
                Text("Send JSON response")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(minHeight: 44)
        .tint(CodexPalette.cobalt)
        .accessibilityIdentifier("codexpad.advanced.submit.\(request.id)")
        .disabled(isSubmitting || resultText.isEmpty)
        Button("Reject request", role: .destructive, action: reject)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(minHeight: 44)
            .tint(CodexPalette.danger)
            .accessibilityIdentifier("codexpad.advanced.reject.\(request.id)")
    }
}
