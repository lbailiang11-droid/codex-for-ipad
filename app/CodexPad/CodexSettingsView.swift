import SwiftUI

struct CodexSettingsView: View {
    @ObservedObject var model: CodexWorkspaceModel
    var openFeatureCenter: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var apiKey = ""
    @State private var confirmsUnlink = false

    var body: some View {
        NavigationStack {
            Form {
                inputSection
                modelSection
                accountSection
                workspaceSection
                featureSection

                Section {
                    Label("Commands and file writes require native approval when Codex requests it.", systemImage: "hand.raised")
                        .fixedSize(horizontal: false, vertical: true)
                    Label("The app-server is bound only to 127.0.0.1 inside the app.", systemImage: "lock.shield")
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    CodexSectionHeader(title: "Safety", symbol: "hand.raised")
                }
                .codexFormSection()

                Section {
                    Text("iPadOS may suspend active work when CodexPad is backgrounded. Keep the app visible for long turns and builds.")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("The terminal remains available as a recovery surface from the workspace toolbar.")
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    CodexSectionHeader(title: "Platform behavior", symbol: "ipad")
                }
                .codexFormSection()

                Section {
                    CodexSettingValue(title: "Codex", value: "Apache-2.0")
                    CodexSettingValue(title: "iSH", value: "GPL with iOS permission")
                    Text("Source and third-party notices are included with every release.")
                        .font(.callout)
                        .foregroundStyle(CodexPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    CodexSectionHeader(title: "Open source", symbol: "chevron.left.forwardslash.chevron.right")
                }
                .codexFormSection()
            }
            .scrollContentBackground(.hidden)
            .background(CodexPalette.canvas)
            .foregroundStyle(CodexPalette.ink)
            .tint(CodexPalette.cobalt)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: 24)
                    .accessibilityHidden(true)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Text("Done").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityIdentifier("codexpad.settings-done")
                }
            }
            .toolbarBackground(CodexPalette.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .confirmationDialog(
                "Unlink the Files folder?",
                isPresented: $confirmsUnlink,
                titleVisibility: .visible
            ) {
                Button("Unlink", role: .destructive) {
                    Task { await model.unlinkFilesFolder() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The folder and its files are not deleted. CodexPad only removes its saved access and iSH mount.")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("codexpad.settings-screen")
    }

    private var inputSection: some View {
        Section {
            Toggle("Desktop mode", isOn: $model.desktopModeEnabled)
                .frame(minHeight: CodexLayout.touchTarget)
                .accessibilityIdentifier("codexpad.desktop-mode")

            if !model.desktopModeEnabled {
                Toggle("Show all Codex features", isOn: $model.showAllFeaturesInTouchMode)
                    .frame(minHeight: CodexLayout.touchTarget)
                    .accessibilityIdentifier("codexpad.touch-show-all")
            } else {
                Label("All compatible features are always visible in desktop mode.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(CodexPalette.teal)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            CodexSectionHeader(title: "Input mode", symbol: "cursorarrow.rays")
        } footer: {
            Text(inputModeDescription)
        }
        .codexFormSection()
    }

    private var inputModeDescription: String {
        if model.desktopModeEnabled {
            return "Desktop mode is optimized for a pointer and hardware keyboard. After the composer is engaged once, focus returns after sends, stops, navigation, settings, and terminal use."
        }
        if model.showAllFeaturesInTouchMode {
            return "Touch input and software-keyboard behavior stay active while the complete Feature Center and long-tail controls are visible."
        }
        return "Touch mode prioritizes direct input and software-keyboard behavior while hiding less-used controls."
    }

    private var modelSection: some View {
        Section {
            if model.availableModels.isEmpty {
                LabeledContent("Catalog") {
                    ProgressView().controlSize(.small)
                }
            } else {
                modelPicker

                if let selected = model.selectedModel {
                    Picker("Reasoning", selection: reasoningSelection) {
                        ForEach(selected.reasoningEfforts) { effort in
                            Text(effort.effort.capitalized).tag(effort.effort)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: CodexLayout.touchTarget)
                    .accessibilityIdentifier("codexpad.settings-reasoning")

                    if model.showsCompleteFeatureSet, !selected.serviceTiers.isEmpty {
                        Picker("Service tier", selection: serviceTierSelection) {
                            Text("Provider default").tag("")
                            ForEach(selected.serviceTiers) { tier in
                                Text(tier.name).tag(tier.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minHeight: CodexLayout.touchTarget)
                        .accessibilityIdentifier("codexpad.settings-service-tier")
                    }
                }

                if model.showsCompleteFeatureSet, !model.collaborationModes.isEmpty {
                    Picker("Collaboration", selection: collaborationSelection) {
                        Text("Standard").tag("")
                        ForEach(model.collaborationModes) { mode in
                            Text(mode.name).tag(mode.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: CodexLayout.touchTarget)
                    .accessibilityIdentifier("codexpad.settings-collaboration")
                }
            }

            Button("Refresh model catalog") {
                Task {
                    await model.refreshModels()
                    await model.refreshCollaborationModes()
                }
            }
            .disabled(!model.enginePhase.isReady)
            .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
            .accessibilityIdentifier("codexpad.settings-refresh-models")
        } header: {
            CodexSectionHeader(title: "Model", symbol: "cpu")
        } footer: {
            if let selected = model.selectedModel, !selected.description.isEmpty {
                Text(selected.description)
            } else {
                Text("The catalog is loaded from the active Codex provider and includes its supported reasoning and collaboration options.")
            }
        }
        .codexFormSection()
    }

    private var modelPicker: some View {
        Menu {
            Picker("Model", selection: modelSelection) {
                ForEach(model.availableModels.filter { !$0.hidden }) { option in
                    Text(option.displayName).tag(option.id)
                }
                if model.availableModels.contains(where: \.hidden) {
                    Section("Hidden provider entries") {
                        ForEach(model.availableModels.filter(\.hidden)) { option in
                            Text("\(option.displayName) - Hidden").tag(option.id)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Model")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(CodexPalette.secondaryInk)
                    Text(model.selectedModel?.displayName ?? "Choose model")
                        .font(.body.weight(.medium))
                        .foregroundStyle(CodexPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CodexPalette.cobalt)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: CodexLayout.touchTarget)
        }
        .accessibilityLabel("Model")
        .accessibilityValue(model.selectedModel?.displayName ?? "Choose model")
        .accessibilityIdentifier("codexpad.settings-model")
    }

    private var accountSection: some View {
        Section {
            if model.account.isAuthenticated {
                CodexSettingValue(title: "Signed in", value: model.account.displayName)
                if let plan = model.account.plan {
                    CodexSettingValue(title: "Plan", value: plan.capitalized)
                }
                Button("Sign out", role: .destructive) {
                    Task { await model.signOut() }
                }
                .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
                .accessibilityIdentifier("codexpad.settings-sign-out")
            } else {
                Button("Continue with ChatGPT") {
                    Task { await model.signInWithChatGPT() }
                }
                .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
                Button("Use a device code") {
                    Task { await model.signInWithDeviceCode() }
                }
                .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
                SecureField("OpenAI API key", text: $apiKey)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(minHeight: CodexLayout.touchTarget)
                Button("Save API key") {
                    let key = apiKey
                    apiKey = ""
                    Task { await model.signIn(apiKey: key) }
                }
                .disabled(apiKey.isEmpty)
                .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
            }

            if let code = model.deviceCode, let url = model.deviceVerificationURL {
                CodexSettingValue(title: "Device code", value: code, monospaced: true)
                Button("Open \(url.host ?? "verification page")") {
                    openURL(url)
                }
                .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
            }
        } header: {
            CodexSectionHeader(title: "Account", symbol: "person.crop.circle")
        }
        .codexFormSection()
    }

    private var workspaceSection: some View {
        Section {
            switch model.linkedFolderPhase {
            case .disconnected:
                Button("Choose folder in Files", systemImage: "folder.badge.plus") {
                    Task { await model.chooseFilesFolder() }
                }
                .disabled(!model.enginePhase.isReady)
                .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
            case .choosing:
                HStack {
                    ProgressView()
                    Text("Waiting for Files selection...")
                }
            case .linked(let name):
                VStack(alignment: .leading, spacing: 6) {
                    Text("Linked folder")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(CodexPalette.secondaryInk)
                    Text(name)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("codexpad.linked-folder-name")
                }
                .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
                Button("Unlink Files folder", role: .destructive) {
                    confirmsUnlink = true
                }
                .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
            case .needsRelink(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(CodexPalette.amber)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Select folder again") {
                    Task { await model.chooseFilesFolder() }
                }
                .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
            }

            TextField("Guest path", text: $model.workspacePath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .frame(minHeight: CodexLayout.touchTarget)
                .accessibilityIdentifier("codexpad.settings-workspace-path")
            CodexSettingValue(title: "Current guest path", value: model.workspacePath, monospaced: true)
            CodexSettingValue(title: "Runtime", value: "iSH – Alpine ARM64")
            CodexSettingValue(title: "Transport", value: "Guest loopback")
        } header: {
            CodexSectionHeader(title: "Workspace", symbol: "folder")
        } footer: {
            Text(workspaceDescription)
        }
        .codexFormSection()
    }

    private var workspaceDescription: String {
        switch model.linkedFolderPhase {
        case .disconnected:
            "Choose a folder to mount it directly into iSH and make it Codex’s working directory. The guest path above is the default local workspace."
        case .choosing:
            "CodexPad is waiting for a security-scoped folder selection from Files."
        case .linked:
            "This Files folder is mounted as a distinct linked workspace; unlinking removes access without deleting any files."
        case .needsRelink:
            "The saved Files permission is no longer usable. Select the folder again to restore its iSH mount."
        }
    }

    private var featureSection: some View {
        Section {
            CodexSettingValue(title: "Compatible operations", value: "\(CodexFeatureCatalog.compatibleFeatureCount)")
            CodexSettingValue(title: "Platform exceptions", value: "\(CodexFeatureCatalog.unavailableFeatureCount)")
            if model.showsCompleteFeatureSet {
                Button("Open complete Feature Center", systemImage: "square.grid.3x3") {
                    if let openFeatureCenter {
                        openFeatureCenter()
                    } else {
                        dismiss()
                        DispatchQueue.main.async {
                            model.showsFeatureCenter = true
                        }
                    }
                }
                .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
                .accessibilityIdentifier("codexpad.open-feature-center")
            }
        } header: {
            CodexSectionHeader(title: "Codex feature coverage", symbol: "square.grid.3x3")
        } footer: {
            if !model.showsCompleteFeatureSet {
                Text("Turn on Show all Codex features above to reveal advanced, experimental, and long-tail operations while staying in touch mode.")
            } else {
                Text("Every compatible operation in the pinned app-server protocol is available through a native control or the structured Feature Center.")
            }
        }
        .codexFormSection()
    }

    private var modelSelection: Binding<String> {
        Binding(
            get: { model.selectedModelID ?? model.availableModels.first?.id ?? "" },
            set: { model.selectModel($0) }
        )
    }

    private var reasoningSelection: Binding<String> {
        Binding(
            get: { model.selectedReasoningEffort ?? model.selectedModel?.defaultReasoningEffort ?? "" },
            set: { model.selectedReasoningEffort = $0 }
        )
    }

    private var serviceTierSelection: Binding<String> {
        Binding(
            get: { model.selectedServiceTier ?? "" },
            set: { model.selectedServiceTier = $0.isEmpty ? nil : $0 }
        )
    }

    private var collaborationSelection: Binding<String> {
        Binding(
            get: { model.selectedCollaborationMode ?? "" },
            set: { model.selectedCollaborationMode = $0.isEmpty ? nil : $0 }
        )
    }
}
