import SwiftUI

struct CodexFeatureCenterView: View {
    @ObservedObject var model: CodexWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selection: String?
    @State private var searchText = ""
    @State private var showsCatalog = false

    var body: some View {
        NavigationStack {
            GeometryReader { window in
                workspace(width: window.size.width)
            }
            .navigationTitle("Feature Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !showsCatalog {
                    ToolbarItem(placement: .confirmationAction) {
                        closeButton
                    }
                }
            }
            .toolbarBackground(CodexPalette.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(CodexPalette.cobalt)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("codexpad.feature-center")
    }

    private func workspace(width: CGFloat) -> some View {
        let compact = width < 920 || dynamicTypeSize.isAccessibilitySize || horizontalSizeClass == .compact
        // A single navigation container and stable detail slot retain the JSON
        // draft across resize. The inspector/sidebar cannot shrink this width.
        return HStack(spacing: 0) {
            if !compact {
                catalog
                    .frame(width: min(340, max(288, width * 0.3)))
                Divider().overlay(CodexPalette.line)
            }
            Group {
                if let selection, let feature = CodexFeatureCatalog.feature(method: selection) {
                    CodexFeatureDetailView(model: model, feature: feature)
                        .id(selection)
                } else if compact {
                    catalog
                } else {
                    ContentUnavailableView(
                        "Choose a Codex feature",
                        systemImage: "square.grid.3x3",
                        description: Text("Every compatible method in the pinned app-server protocol has a route here.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(CodexPalette.canvas)
        .toolbar {
            if compact && selection != nil && !showsCatalog {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsCatalog = true
                    } label: {
                        Label("Features", systemImage: "sidebar.left")
                            .frame(minHeight: CodexLayout.touchTarget)
                    }
                    .accessibilityIdentifier("codexpad.feature-back")
                }
            }
        }
        .sheet(isPresented: $showsCatalog) {
            NavigationStack {
                catalog
                    .navigationTitle("Features")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Back to feature") { showsCatalog = false }
                                .frame(minHeight: CodexLayout.touchTarget)
                                .accessibilityIdentifier("codexpad.feature-browser-back")
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            closeButton
                        }
                    }
                    .toolbarBackground(CodexPalette.surface, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .presentationDragIndicator(.visible)
        }
        .onChange(of: compact) { _, value in
            if !value { showsCatalog = false }
        }
    }

    private var closeButton: some View {
        Button {
            showsCatalog = false
            dismiss()
        } label: {
            Text("Done").frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityIdentifier("codexpad.feature-close")
    }

    private var catalog: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(CodexPalette.secondaryInk)
                    .accessibilityHidden(true)
                TextField("Search every Codex feature", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityIdentifier("codexpad.feature-search")
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(width: CodexLayout.touchTarget, height: CodexLayout.touchTarget)
                    }
                    .accessibilityLabel("Clear feature search")
                    .accessibilityIdentifier("codexpad.feature-search-clear")
                }
            }
            .font(.body)
            .padding(.leading, 12)
            .padding(.trailing, searchText.isEmpty ? 12 : 0)
            .frame(minHeight: CodexLayout.touchTarget)
            .background(CodexPalette.surface, in: RoundedRectangle(cornerRadius: CodexLayout.controlRadius))
            .padding(16)

            List(selection: $selection) {
                Section {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(CodexFeatureCatalog.compatibleFeatureCount) compatible operations")
                            .font(.headline)
                        Text("\(CodexFeatureCatalog.unavailableFeatureCount) explicit platform exceptions")
                            .font(.caption)
                            .foregroundStyle(CodexPalette.secondaryInk)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("codexpad.feature-summary")
                }
                .codexFormSection()

                if filteredFeatures.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No matching features", systemImage: "magnifyingglass")
                        } description: {
                            Text("Try a method, title or category.")
                        } actions: {
                            Button("Clear search") { searchText = "" }
                                .frame(minHeight: CodexLayout.touchTarget)
                        }
                        .accessibilityIdentifier("codexpad.feature-no-results")
                    }
                    .codexFormSection()
                }

                ForEach(CodexFeatureCategory.allCases) { category in
                    let features = filteredFeatures.filter { $0.category == category }
                    if !features.isEmpty {
                        Section {
                            ForEach(features) { feature in
                                Button {
                                    selection = feature.method
                                    showsCatalog = false
                                } label: {
                                    FeatureCatalogRow(feature: feature)
                                }
                                    .buttonStyle(.plain)
                                    .tag(feature.method)
                                    .accessibilityIdentifier("codexpad.feature.\(feature.method)")
                                    .listRowBackground(selection == feature.method ? CodexPalette.selection : CodexPalette.surface)
                            }
                        } header: {
                            CodexSectionHeader(title: category.rawValue, symbol: category.symbol)
                        }
                        .codexFormSection()
                    }
                }

                if searchText.isEmpty {
                    Section {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Experimental Code Mode").font(.subheadline.weight(.medium))
                                Text("Code Mode support is experimental on the ARM64 runtime")
                                    .font(.caption)
                                    .foregroundStyle(CodexPalette.secondaryInk)
                            }
                        } icon: {
                            Image(systemName: "nosign").foregroundStyle(CodexPalette.amber)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Client attestation").font(.subheadline.weight(.medium))
                                Text("No signing provider in this unsigned port")
                                    .font(.caption)
                                    .foregroundStyle(CodexPalette.secondaryInk)
                            }
                        } icon: {
                            Image(systemName: "nosign").foregroundStyle(CodexPalette.amber)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        CodexSectionHeader(title: "Runtime exceptions", symbol: "exclamationmark.shield")
                    }
                    .codexFormSection()
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(CodexPalette.canvas)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("codexpad.feature-catalog")
    }

    private var filteredFeatures: [CodexFeatureDefinition] {
        guard !searchText.isEmpty else { return CodexFeatureCatalog.features }
        return CodexFeatureCatalog.features.filter {
            $0.method.localizedCaseInsensitiveContains(searchText)
                || $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct FeatureCatalogRow: View {
    let feature: CodexFeatureDefinition

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feature.category.symbol)
                .foregroundStyle(feature.access == .incompatible ? CodexPalette.secondaryInk : CodexPalette.cobalt)
                .frame(width: 22)
                .padding(.top, 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(feature.title)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(feature.method)
                    .font(.caption.monospaced())
                    .foregroundStyle(CodexPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Label(feature.access.rawValue, systemImage: accessSymbol)
                    .font(.caption)
                    .foregroundStyle(feature.access == .incompatible ? CodexPalette.amber : CodexPalette.teal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature.title), \(feature.access.rawValue), \(feature.method)")
    }

    private var accessSymbol: String {
        switch feature.access {
        case .native: "rectangle.and.hand.point.up.left"
        case .advanced: "slider.horizontal.3"
        case .automatic: "arrow.trianglehead.2.clockwise.rotate.90"
        case .incompatible: "nosign"
        }
    }
}

private struct CodexFeatureDetailView: View {
    @ObservedObject var model: CodexWorkspaceModel
    let feature: CodexFeatureDefinition

    @State private var parameters = "{}"
    @State private var result = ""
    @State private var isRunning = false
    @State private var confirmsDestructiveRequest = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let reason = feature.incompatibilityReason {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Platform exception").font(.headline)
                            Text(reason).font(.body)
                        }
                    } icon: {
                        Image(systemName: "nosign")
                    }
                    .foregroundStyle(CodexPalette.amber)
                    .fixedSize(horizontal: false, vertical: true)
                    .codexPanel()
                } else if feature.access == .automatic {
                    Label("This connection feature runs automatically and cannot be repeated in an active JSON-RPC session.", systemImage: "checkmark.seal")
                        .fixedSize(horizontal: false, vertical: true)
                        .codexPanel()
                } else {
                    if let location = feature.location {
                        Label("Native control: \(location)", systemImage: "rectangle.and.hand.point.up.left")
                            .font(.callout)
                            .foregroundStyle(CodexPalette.teal)
                            .fixedSize(horizontal: false, vertical: true)
                            .codexPanel(padding: 14)
                    }
                    requestEditor
                }

                if !model.protocolEvents.isEmpty {
                    eventLog
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 56)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(CodexPalette.canvas)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("codexpad.feature-detail")
        .task {
            parameters = model.featureDefaultParams(for: feature.method)
        }
        .confirmationDialog(
            "Run destructive Codex operation?",
            isPresented: $confirmsDestructiveRequest,
            titleVisibility: .visible
        ) {
            Button("Run \(feature.method)", role: .destructive) { runRequest() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Review the JSON carefully. This operation can remove or overwrite local Codex data.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    categoryLabel
                    Spacer(minLength: 12)
                    accessLabel
                }
                VStack(alignment: .leading, spacing: 8) {
                    categoryLabel
                    accessLabel
                }
            }
            Text(feature.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(CodexPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(feature.method)
                .font(.callout.monospaced())
                .foregroundStyle(CodexPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Text(feature.summary)
                .font(.body)
                .foregroundStyle(CodexPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var categoryLabel: some View {
        Label(feature.category.rawValue, systemImage: feature.category.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(CodexPalette.cobalt)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var accessLabel: some View {
        Text(feature.access.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(CodexPalette.raised, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }

    private var requestEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Parameters", systemImage: "curlybraces")
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    parameters = model.featureDefaultParams(for: feature.method)
                    result = ""
                }
                .buttonStyle(.borderless)
                .frame(minWidth: CodexLayout.touchTarget, minHeight: CodexLayout.touchTarget)
                .accessibilityIdentifier("codexpad.feature-reset")
            }
            Text("Edit the JSON object sent as params. Contextual thread and workspace identifiers are prefilled when available.")
                .font(.caption)
                .foregroundStyle(CodexPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $parameters)
                .font(.callout.monospaced())
                .scrollContentBackground(.hidden)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: 180)
                .padding(8)
                .background(CodexPalette.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(CodexPalette.line, lineWidth: 0.5)
                }
                .accessibilityLabel("JSON parameters for \(feature.method)")
                .accessibilityIdentifier("codexpad.feature-parameters")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    runButton
                    engineAvailability
                }
                VStack(alignment: .leading, spacing: 8) {
                    runButton
                    engineAvailability
                }
            }

            if !result.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Result").font(.headline)
                    CodexCodeView(code: result, copyID: "codexpad.feature-result-copy", copyLabel: "Copy result")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("codexpad.feature-result")
            }
        }
        .codexPanel()
    }

    private var runButton: some View {
        Button {
            if feature.isDestructive {
                confirmsDestructiveRequest = true
            } else {
                runRequest()
            }
        } label: {
            Group {
                if isRunning {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Run request", systemImage: "play.fill")
                }
            }
            .frame(minHeight: CodexLayout.touchTarget)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isRunning || !model.enginePhase.isReady)
        .accessibilityIdentifier("codexpad.feature-run")
    }

    @ViewBuilder private var engineAvailability: some View {
        if !model.enginePhase.isReady {
            Text("Local engine unavailable")
                .font(.caption)
                .foregroundStyle(CodexPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var eventLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Live protocol events", systemImage: "waveform.path.ecg")
                .font(.headline)
            ForEach(model.protocolEvents.suffix(8).reversed()) { event in
                DisclosureGroup {
                    ScrollView(.horizontal) {
                        Text(event.payload)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .fixedSize(horizontal: true, vertical: true)
                            .padding(.vertical, 6)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(event.method)
                            .font(.caption.monospaced())
                            .fixedSize(horizontal: false, vertical: true)
                        Text(event.timestamp, style: .time)
                            .font(.caption)
                            .foregroundStyle(CodexPalette.secondaryInk)
                    }
                    .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
                }
            }
        }
        .codexPanel()
    }

    private func runRequest() {
        isRunning = true
        result = ""
        Task {
            result = await model.executeFeature(method: feature.method, parameters: parameters)
            isRunning = false
        }
    }
}
