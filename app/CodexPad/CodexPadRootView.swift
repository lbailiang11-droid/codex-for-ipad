import SwiftUI
import UIKit

struct CodexPadRootView: View {
    @ObservedObject var model: CodexWorkspaceModel
    let showTerminal: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsWorkbench = false
    @State private var showsThreadBrowser = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var compactColumn: NavigationSplitViewColumn = .detail
    @State private var workbenchMode: WorkbenchPresentation = .sheet
    @State private var searchText = ""

    private enum WorkbenchPresentation {
        case inspector, sheet
    }

    var body: some View {
        GeometryReader { window in
            workspace(width: window.size.width)
        }
    }

    private func workspace(width: CGFloat) -> some View {
        adaptiveWorkspace(width: width)
        .onAppear { updateWorkbenchMode(width: width) }
        .onChange(of: width) { _, value in updateWorkbenchMode(width: value) }
        .onChange(of: dynamicTypeSize) { _, _ in updateWorkbenchMode(width: width) }
        .onChange(of: horizontalSizeClass) { _, _ in updateWorkbenchMode(width: width) }
        .inspector(isPresented: workbenchPresentation(.inspector)) {
            NavigationStack {
                CodexWorkbenchView(model: model)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            closeWorkbenchButton
                        }
                    }
            }
            .inspectorColumnWidth(min: 300, ideal: 330, max: 400)
        }
        .sheet(isPresented: workbenchPresentation(.sheet), onDismiss: restoreFocusAfterWorkbench) {
            NavigationStack {
                CodexWorkbenchView(model: model)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            closeWorkbenchButton
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
        .accessibilityIdentifier("codexpad.workspace")
        .tint(CodexPalette.cobalt)
        .background(CodexPalette.canvas)
        .sheet(isPresented: $model.showsSettings, onDismiss: model.requestComposerFocus) {
            CodexSettingsView(model: model)
        }
        .sheet(isPresented: $model.showsFeatureCenter, onDismiss: model.requestComposerFocus) {
            CodexFeatureCenterView(model: model)
        }
        .sheet(isPresented: $showsThreadBrowser) {
            NavigationStack {
                sidebar(compact: true)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showsThreadBrowser = false
                            }
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
        .task {
            await model.start()
        }
        .onChange(of: model.loginURL) { _, url in
            if let url { openURL(url) }
        }
    }

    private func adaptiveWorkspace(width: CGFloat) -> some View {
        let compact = prioritizesConversation(width: width)
        // Keep the conversation's identity across resize/rotation so scroll and
        // disclosure state are not discarded by swapping navigation containers.
        return NavigationSplitView(
            columnVisibility: Binding(
                get: { compact ? .detailOnly : columnVisibility },
                set: { if !compact { columnVisibility = $0 } }
            ),
            preferredCompactColumn: $compactColumn
        ) {
            sidebar(compact: false)
                .navigationSplitViewColumnWidth(min: 260, ideal: CodexLayout.sidebarIdealWidth, max: 320)
        } detail: {
            conversation(compact: compact)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
    }

    private func conversation(compact: Bool) -> some View {
        CodexConversationView(model: model)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if compact {
                            showsThreadBrowser = true
                        } else {
                            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                        }
                    } label: {
                        Label("Threads", systemImage: "sidebar.left")
                    }
                    .accessibilityIdentifier("codexpad.threads")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: showTerminal) {
                        Label("Terminal", systemImage: "terminal")
                    }
                    .accessibilityIdentifier("codexpad.terminal")
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Desktop mode", isOn: $model.desktopModeEnabled)
                        if !model.desktopModeEnabled {
                            Toggle("Show all Codex features", isOn: $model.showAllFeaturesInTouchMode)
                        }
                    } label: {
                        Label(
                            model.desktopModeEnabled ? "Desktop mode" : "Touch mode",
                            systemImage: model.desktopModeEnabled ? "cursorarrow.rays" : "hand.tap"
                        )
                    }
                    .accessibilityIdentifier("codexpad.input-mode")

                    if model.showsCompleteFeatureSet {
                        Button {
                            model.showsFeatureCenter = true
                        } label: {
                            Label("All Codex features", systemImage: "square.grid.3x3")
                        }
                        .accessibilityIdentifier("codexpad.features")
                        .keyboardShortcut(",", modifiers: [.command, .shift])
                    }

                    Button {
                        Task { await model.createThread() }
                    } label: {
                        Label("New thread", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("codexpad.new-thread")
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(!model.enginePhase.isReady)

                    Button {
                        showsWorkbench.toggle()
                    } label: {
                        Label(
                            showsWorkbench ? "Hide workbench" : "Show workbench",
                            systemImage: "sidebar.right"
                        )
                    }
                    .accessibilityIdentifier("codexpad.toggle-workbench")
                    .accessibilityValue(showsWorkbench ? "Shown" : "Hidden")
                    .keyboardShortcut("i", modifiers: [.command, .option])
                }
            }
    }

    private func sidebar(compact: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "terminal")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CodexPalette.cobalt)
                    .frame(width: 40, height: 40)
                    .background(CodexPalette.selection, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("CodexPad")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(CodexPalette.ink)
                    Text(model.enginePhase.title)
                        .font(.caption)
                        .foregroundStyle(CodexPalette.secondaryInk)
                }
                Spacer(minLength: 0)
                Button {
                    Task { await model.createThread() }
                    if compact { showsThreadBrowser = false }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.body.weight(.medium))
                        .frame(width: CodexLayout.touchTarget, height: CodexLayout.touchTarget)
                }
                .disabled(!model.enginePhase.isReady)
                .accessibilityLabel("New thread")
                .accessibilityIdentifier("codexpad.new-thread-sidebar")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(CodexPalette.secondaryInk)
                    .accessibilityHidden(true)
                TextField("Search threads", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("codexpad.thread-search")
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .frame(minHeight: CodexLayout.touchTarget)
            .background(CodexPalette.surface, in: RoundedRectangle(cornerRadius: CodexLayout.controlRadius))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            List(selection: selection(compact: compact)) {
                Section {
                    ForEach(filteredThreads) { thread in
                        ThreadRow(thread: thread)
                            .tag(thread.id)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                            .listRowSeparator(.hidden)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(model.selectedThreadID == thread.id ? CodexPalette.selection : Color.clear)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                            )
                            .contextMenu {
                                Button("Archive", systemImage: "archivebox") {
                                    model.selectedThreadID = thread.id
                                    Task { await model.archiveSelectedThread() }
                                }
                            }
                    }
                } header: {
                    Text("Recent threads")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(CodexPalette.secondaryInk)
                        .textCase(nil)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Divider().overlay(CodexPalette.line)
            Button {
                showsThreadBrowser = false
                model.showsSettings = true
            } label: {
                HStack {
                    Image(systemName: model.account.isAuthenticated ? "person.crop.circle.fill" : "person.crop.circle.badge.questionmark")
                        .font(.title2)
                        .foregroundStyle(CodexPalette.secondaryInk)
                    Text(model.account.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CodexPalette.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CodexPalette.secondaryInk)
                }
            }
            .accessibilityLabel("Account settings, \(model.account.displayName)")
            .accessibilityIdentifier("codexpad.settings")
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .padding(.horizontal, 18)
            .frame(minHeight: 54)
            .background(CodexPalette.surface)
        }
        .accessibilityIdentifier("codexpad.sidebar")
        .background(CodexPalette.canvas)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selection(compact: Bool) -> Binding<String?> {
        Binding(
            get: { model.selectedThreadID },
            set: { id in
                if compact {
                    showsThreadBrowser = false
                }
                Task { await model.selectThread(id) }
            }
        )
    }

    private var filteredThreads: [CodexThreadRecord] {
        guard !searchText.isEmpty else { return model.threads }
        return model.threads.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.cwd.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var closeWorkbenchButton: some View {
        Button("Done") {
            showsWorkbench = false
            if workbenchMode == .inspector { model.requestComposerFocus() }
        }
        .accessibilityIdentifier("codexpad.close-workbench")
    }

    private func workbenchPresentation(_ mode: WorkbenchPresentation) -> Binding<Bool> {
        return Binding(
            get: { showsWorkbench && workbenchMode == mode },
            set: { shown in
                // Read current State rather than a captured width. A delayed
                // dismiss from the previous form must not close the new form.
                if workbenchMode == mode { showsWorkbench = shown }
            }
        )
    }

    private func updateWorkbenchMode(width: CGFloat) {
        workbenchMode = width >= CodexLayout.inspectorThreshold
            && !prioritizesConversation(width: width) ? .inspector : .sheet
    }

    private func restoreFocusAfterWorkbench() {
        if !showsWorkbench { model.requestComposerFocus() }
    }

    private func prioritizesConversation(width: CGFloat) -> Bool {
        dynamicTypeSize.isAccessibilitySize
            || horizontalSizeClass == .compact
            || width < CodexLayout.sidebarThreshold
    }
}
