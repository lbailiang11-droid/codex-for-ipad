import SwiftUI

struct CodexConversationView: View {
    @ObservedObject var model: CodexWorkspaceModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var followsLatest = true
    @State private var previousContentFrame: CGRect?

    var body: some View {
        Group {
            if !model.enginePhase.isReady {
                EngineUnavailableView(model: model)
            } else if let thread = model.selectedThread {
                conversation(thread)
            } else {
                WelcomeWorkspaceView(model: model)
            }
        }
        .background(CodexPalette.canvas)
        .navigationTitle(model.selectedThread == nil ? "Workspace" : "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func conversation(_ thread: CodexThreadRecord) -> some View {
        GeometryReader { workspace in
            VStack(spacing: 0) {
                conversationHeader(
                    thread,
                    compact: workspace.size.width < 480 || dynamicTypeSize.isAccessibilitySize
                )
                Divider().overlay(CodexPalette.line)
                if let error = model.errorBanner {
                    ErrorBanner(message: error) {
                        model.errorBanner = nil
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(CodexPalette.canvas)
                }
                timeline
                ComposerBar(model: model)
            }
            .background(CodexPalette.surface)
        }
    }

    private func conversationHeader(_ thread: CodexThreadRecord, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(thread.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(CodexPalette.ink)
                        .lineLimit(2)
                        .accessibilityIdentifier("codexpad.conversation-title")
                    Label(thread.cwd, systemImage: "folder")
                        .font(.caption.monospaced())
                        .foregroundStyle(CodexPalette.secondaryInk)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !compact {
                    EngineStatusPill(phase: model.enginePhase)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            if compact {
                EngineStatusPill(phase: model.enginePhase)
            }
        }
        .padding(.horizontal, compact ? 16 : 24)
        .padding(.vertical, 16)
        .background(CodexPalette.surface)
    }

    private var timeline: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        let items = model.selectedTimeline
                        if items.isEmpty && relevantRequests.isEmpty && !model.isTurnRunning {
                            CodexStateCard(
                                title: "Ready for your first message",
                                message: "Ask Codex to explain, change, or verify something in this workspace.",
                                systemImage: "text.bubble",
                                tone: .accent
                            )
                            .accessibilityIdentifier("codexpad.empty-conversation")
                            .padding(.bottom, 24)
                        }
                        ForEach(items) { item in
                            TimelineCard(
                                item: item,
                                isFirst: item.id == items.first?.id,
                                isLast: item.id == items.last?.id && relevantRequests.isEmpty
                            )
                            .id(item.id)
                        }

                        ForEach(relevantRequests) { request in
                            Group {
                                if request.kind == .question {
                                    QuestionRequestCard(request: request) { values in
                                        Task { await model.answer(request, values: values) }
                                    }
                                } else if request.kind == .advanced {
                                    AdvancedServerRequestCard(request: request) { result in
                                        await model.answerAdvancedRequest(request, resultText: result)
                                    } reject: {
                                        Task { await model.rejectAdvancedRequest(request) }
                                    }
                                } else {
                                    ApprovalRequestCard(request: request) { choice in
                                        Task { await model.resolve(request, choice: choice) }
                                    }
                                }
                            }
                            .padding(.leading, viewport.size.width < 500 ? 0 : 42)
                            .padding(.top, 12)
                        }

                        if model.isTurnRunning {
                            WorkingIndicator()
                                .id("working")
                        }
                        Color.clear.frame(height: 1).id("timeline-end")
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: 820)
                    .padding(.horizontal, viewport.size.width < 500 ? 16 : 24)
                    .frame(maxWidth: .infinity)
                    .background {
                        GeometryReader { content in
                            Color.clear.preference(
                                key: TimelineContentFrameKey.self,
                                value: content.frame(in: .named("codexpad.timeline"))
                            )
                        }
                    }
                }
                .coordinateSpace(name: "codexpad.timeline")
                .background(CodexPalette.surface)
                .scrollDismissesKeyboard(model.desktopModeEnabled ? .never : .interactively)
                .onPreferenceChange(TimelineContentFrameKey.self) { frame in
                    // Growth does not disable following. Moving upward does, including
                    // while streamed content is growing at the bottom of the timeline.
                    if let previous = previousContentFrame {
                        let nearBottom = frame.maxY - viewport.size.height <= 80
                        let movedUp = frame.minY > previous.minY + 1
                        let stableHeight = abs(frame.height - previous.height) < 1
                        let moved = abs(frame.minY - previous.minY) > 1
                        if nearBottom {
                            followsLatest = true
                        } else if (movedUp && frame.height >= previous.height - 1) || (stableHeight && moved) {
                            followsLatest = false
                        }
                    }
                    previousContentFrame = frame
                }
                .onAppear {
                    followsLatest = true
                    previousContentFrame = nil
                    scrollToEnd(proxy, animated: false)
                }
                .onChange(of: model.selectedThreadID) { _, _ in
                    followsLatest = true
                    previousContentFrame = nil
                    scrollToEnd(proxy, animated: false)
                }
                .onChange(of: model.selectedTimeline) { oldItems, newItems in
                    guard followsLatest else { return }
                    scrollToEnd(proxy, animated: oldItems.count != newItems.count)
                }
                .onChange(of: relevantRequests.map(\.id)) { _, _ in
                    guard followsLatest else { return }
                    scrollToEnd(proxy)
                }
                .onChange(of: model.isTurnRunning) { _, _ in
                    guard followsLatest else { return }
                    scrollToEnd(proxy)
                }
                .onChange(of: viewport.size.height) { _, _ in
                    guard followsLatest else { return }
                    scrollToEnd(proxy, animated: false)
                }
                .onChange(of: viewport.size.width) { _, _ in
                    guard followsLatest else { return }
                    scrollToEnd(proxy, animated: false)
                }
                .overlay(alignment: .bottomTrailing) {
                    if !followsLatest {
                        Button {
                            followsLatest = true
                            scrollToEnd(proxy)
                        } label: {
                            Label(relevantRequests.isEmpty ? "Latest" : "Pending request", systemImage: "arrow.down")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(CodexPalette.raised, in: Capsule())
                                .overlay(Capsule().stroke(CodexPalette.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(CodexPalette.cobalt)
                        .accessibilityLabel(relevantRequests.isEmpty ? "Scroll to latest message" : "Scroll to pending request")
                        .accessibilityIdentifier("codexpad.latest-message")
                        .padding(16)
                    }
                }
            }
        }
    }

    private var relevantRequests: [PendingServerRequest] {
        model.pendingRequests.filter {
            $0.threadID == nil || $0.threadID == model.selectedThreadID
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if reduceMotion || !animated {
            proxy.scrollTo("timeline-end", anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.24)) {
                proxy.scrollTo("timeline-end", anchor: .bottom)
            }
        }
    }
}

private struct TimelineContentFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct ComposerBar: View {
    @ObservedObject var model: CodexWorkspaceModel
    @FocusState private var isFocused: Bool
    @ScaledMetric(relativeTo: .subheadline) private var controlHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Ask Codex to change, explain, or verify…", text: $model.composerText, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(CodexPalette.ink)
                    .lineSpacing(4)
                    .lineLimit(1...7)
                    .frame(minWidth: 80, maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
                    .focused($isFocused)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .accessibilityLabel("Message Codex")
                    .accessibilityIdentifier("codexpad.composer")
                    .onChange(of: isFocused) { _, focused in
                        if focused { model.composerDidGainFocus() }
                    }
                    .onChange(of: model.composerFocusGeneration) { _, _ in
                        guard model.desktopModeEnabled else { return }
                        isFocused = true
                    }
                    .onChange(of: model.desktopModeEnabled) { _, enabled in
                        if !enabled { isFocused = false }
                    }

                HStack(alignment: .bottom, spacing: 8) {
                    modelControls
                    if model.isTurnRunning {
                        Button {
                            if !model.desktopModeEnabled { isFocused = false }
                            Task { await model.interruptTurn() }
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(CodexPalette.surface)
                                .frame(width: 44, height: 44)
                                .background(CodexPalette.danger, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(".", modifiers: .command)
                        .accessibilityLabel("Stop the current turn")
                        .accessibilityIdentifier("codexpad.stop")
                    } else {
                        Button {
                            if !model.desktopModeEnabled { isFocused = false }
                            Task { await model.sendComposer() }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.body.weight(.bold))
                                .foregroundStyle(CodexPalette.surface)
                                .frame(width: 44, height: 44)
                                .background(CodexPalette.cobalt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .opacity(canSend ? 1 : 0.4)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSend)
                        .keyboardShortcut(.return, modifiers: .command)
                        .accessibilityLabel("Send message")
                        .accessibilityIdentifier("codexpad.send")
                    }
                }
            }
            .padding(12)
            .background(CodexPalette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isFocused ? CodexPalette.cobalt : CodexPalette.line, lineWidth: isFocused ? 1.5 : 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)

            HStack {
                Label("Local iSH", systemImage: "ipad")
                Spacer()
                Label(
                    model.desktopModeEnabled ? "Desktop focus on" : "Touch input",
                    systemImage: model.desktopModeEnabled ? "keyboard" : "hand.tap"
                )
            }
            .font(.caption2)
            .foregroundStyle(CodexPalette.secondaryInk)
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(CodexPalette.surface)
    }

    private var canSend: Bool {
        !model.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var modelControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(model.availableModels.filter { !$0.hidden }) { option in
                        Button {
                            model.selectModel(option.id)
                        } label: {
                            if option.id == model.selectedModelID {
                                Label(option.displayName, systemImage: "checkmark")
                            } else {
                                Text(option.displayName)
                            }
                        }
                    }
                    if model.availableModels.contains(where: \.hidden) {
                        Section("Hidden provider entries") {
                            ForEach(model.availableModels.filter(\.hidden)) { option in
                                Button("\(option.displayName) - Hidden") {
                                    model.selectModel(option.id)
                                }
                            }
                        }
                    }
                } label: {
                    controlLabel(model.selectedModel?.displayName ?? "Model", systemImage: "cpu")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.plain)
                .disabled(model.availableModels.isEmpty)
                .accessibilityIdentifier("codexpad.model-picker")

                if let selected = model.selectedModel, !selected.reasoningEfforts.isEmpty {
                    Menu {
                        ForEach(selected.reasoningEfforts) { option in
                            Button {
                                model.selectedReasoningEffort = option.effort
                                model.selectedCollaborationMode = nil
                            } label: {
                                if option.effort == model.selectedReasoningEffort {
                                    Label(option.effort.capitalized, systemImage: "checkmark")
                                } else {
                                    Text(option.effort.capitalized)
                                }
                            }
                        }
                    } label: {
                        controlLabel(model.selectedReasoningEffort?.capitalized ?? "Reasoning", systemImage: "brain.head.profile")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("codexpad.reasoning-picker")
                }

                if hasServiceTierControls || hasCollaborationControls {
                    Menu {
                        if let selected = model.selectedModel, hasServiceTierControls {
                            Menu {
                                Button("Provider default") { model.selectedServiceTier = nil }
                                ForEach(selected.serviceTiers) { tier in
                                    Button(tier.name) { model.selectedServiceTier = tier.id }
                                }
                            } label: {
                                let tierName = selected.serviceTiers.first { $0.id == model.selectedServiceTier }?.name
                                Label(tierName ?? "Service tier", systemImage: "speedometer")
                            }
                        }

                        if hasCollaborationControls {
                            Menu {
                                Button("Standard") { model.selectedCollaborationMode = nil }
                                ForEach(model.collaborationModes) { mode in
                                    Button(mode.name) { model.selectedCollaborationMode = mode.name }
                                }
                            } label: {
                                Label(model.selectedCollaborationMode ?? "Collaboration", systemImage: "person.2")
                            }
                            .accessibilityIdentifier("codexpad.collaboration-picker")
                        }
                    } label: {
                        controlLabel("More", systemImage: "ellipsis")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More model options")
                    .accessibilityIdentifier("codexpad.more-options")
                }
            }
        }
        .frame(height: controlHeight)
        .frame(maxWidth: .infinity)
        .controlSize(.small)
    }

    private var hasServiceTierControls: Bool {
        guard let selected = model.selectedModel else { return false }
        return model.showsCompleteFeatureSet && !selected.reasoningEfforts.isEmpty && !selected.serviceTiers.isEmpty
    }

    private var hasCollaborationControls: Bool {
        model.showsCompleteFeatureSet && !model.collaborationModes.isEmpty
    }

    private func controlLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(CodexPalette.secondaryInk)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minHeight: controlHeight)
            .background(CodexPalette.canvas, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct WorkingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(CodexPalette.cobalt)
                .symbolEffect(.pulse, isActive: !reduceMotion)
            Text("Codex is working on-device")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(CodexPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.leading, 43)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Codex is working on-device")
        .accessibilityIdentifier("codexpad.working")
    }
}

private struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(CodexPalette.danger)
            VStack(alignment: .leading, spacing: 6) {
                Text("Workspace error")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CodexPalette.danger)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(CodexPalette.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
                    .background(CodexPalette.canvas, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(CodexPalette.secondaryInk)
            .accessibilityLabel("Dismiss error")
            .accessibilityIdentifier("codexpad.error-dismiss")
        }
        .codexPanel(padding: 12)
        .overlay {
            RoundedRectangle(cornerRadius: CodexLayout.panelRadius, style: .continuous)
                .stroke(CodexPalette.danger.opacity(0.35), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("codexpad.error-banner")
    }
}

private struct WelcomeWorkspaceView: View {
    @ObservedObject var model: CodexWorkspaceModel

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(spacing: 16) {
                    if let error = model.errorBanner {
                        ErrorBanner(message: error) { model.errorBanner = nil }
                    }
                    CodexStateCard(
                        title: "Start in your local workspace",
                        message: "Create a thread to plan, edit, run commands, and review changes in the bundled iSH Linux environment.",
                        systemImage: "ipad.gen2.landscape",
                        tone: .accent
                    ) {
                        Button {
                            Task { await model.createThread() }
                        } label: {
                            Label("New thread", systemImage: "square.and.pencil")
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CodexPalette.cobalt)
                        .keyboardShortcut("n", modifiers: .command)
                        .accessibilityIdentifier("codexpad.welcome-new-thread")
                    }
                    .accessibilityIdentifier("codexpad.welcome")
                }
                .frame(maxWidth: 560)
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: viewport.size.height)
            }
        }
    }
}

private struct EngineUnavailableView: View {
    @ObservedObject var model: CodexWorkspaceModel

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(spacing: 16) {
                    if let error = model.errorBanner {
                        ErrorBanner(message: error) { model.errorBanner = nil }
                    }
                    CodexStateCard(
                        title: model.enginePhase.title,
                        message: message,
                        systemImage: systemImage,
                        tone: isOffline ? .warning : .accent,
                        progress: progress
                    ) {
                        if isOffline {
                            Button {
                                Task { await model.retryConnection() }
                            } label: {
                                Label("Try again", systemImage: "arrow.clockwise")
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(CodexPalette.cobalt)
                            .accessibilityIdentifier("codexpad.engine-retry")
                        }
                    }
                    .accessibilityIdentifier(stateIdentifier)
                }
                .frame(maxWidth: 560)
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: viewport.size.height)
            }
        }
    }

    private var isOffline: Bool {
        if case .offline = model.enginePhase { return true }
        return false
    }

    private var message: String {
        switch model.enginePhase {
        case .offline(let message): message
        case .connecting: "Waiting for the local Codex service. Your workspace will appear when the connection is ready."
        default: "Preparing the bundled Linux workspace and local Codex service."
        }
    }

    private var systemImage: String {
        switch model.enginePhase {
        case .starting: "shippingbox"
        case .connecting: "bolt.horizontal.circle"
        case .offline: "pause.circle"
        case .ready: "ipad.and.arrow.forward"
        }
    }

    private var progress: String? {
        switch model.enginePhase {
        case .starting: "Preparing workspace"
        case .connecting(let attempt): "Connection attempt \(attempt)"
        default: nil
        }
    }

    private var stateIdentifier: String {
        switch model.enginePhase {
        case .starting: "codexpad.engine-starting"
        case .connecting: "codexpad.engine-connecting"
        case .offline: "codexpad.engine-offline"
        case .ready: "codexpad.engine-ready"
        }
    }
}
