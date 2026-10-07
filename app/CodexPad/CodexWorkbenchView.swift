import SwiftUI
import UIKit

struct CodexWorkbenchView: View {
    @ObservedObject var model: CodexWorkspaceModel
    @State private var parsedDiff: WorkbenchDiffPresentation?
    @State private var collapsedDiffFiles: Set<String> = []
    @ScaledMetric(relativeTo: .callout) private var diffCharacterWidth: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            Picker("Workbench", selection: $model.workbenchTab) {
                ForEach(WorkbenchTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(16)

            Divider().overlay(CodexPalette.line)

            Group {
                switch model.workbenchTab {
                case .plan: planView
                case .changes: changesView
                case .files: filesView
                case .runtime: runtimeView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(CodexPalette.canvas)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("codexpad.workbench")
        .navigationTitle("Workbench")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var planView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Turn plan").codexDisplayTitle()
                    Spacer()
                    Text("\(model.plan.filter(\.isComplete).count)/\(model.plan.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(CodexPalette.secondaryInk)
                }
                if model.plan.isEmpty {
                    ContentUnavailableView(
                        "No plan yet",
                        systemImage: "checklist",
                        description: Text("A structured plan appears here when Codex creates one.")
                    )
                } else {
                    ForEach(model.plan) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: planIcon(step.status))
                                .foregroundStyle(planColor(step.status))
                                .frame(width: 22, height: 22)
                            Text(step.text)
                                .font(.body)
                                .foregroundStyle(CodexPalette.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(step.text), \(step.status)")
                    }
                }
            }
            .padding(20)
        }
    }

    private var changesView: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Text("Working tree").font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    changesActions
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Working tree").font(.subheadline.weight(.semibold))
                    HStack(spacing: 12) { changesActions }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(CodexPalette.surface)

            if model.currentDiff.isEmpty {
                ContentUnavailableView(
                    "No changes yet",
                    systemImage: "doc.badge.gearshape",
                    description: Text("The current turn’s patch appears here as Codex edits files.")
                )
            } else if let presentation = parsedDiff, presentation.document.rawText == model.currentDiff {
                GeometryReader { viewport in
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            diffSummary(presentation)
                            if presentation.document.files.isEmpty {
                                CodexCodeView(code: presentation.document.rawText, language: "diff", copyLabel: "Copy diff")
                            } else {
                                ForEach(presentation.document.files) { file in
                                    diffFile(file, minimumLineWidth: max(0, viewport.size.width - 64))
                                }
                            }
                        }
                        .padding(16)
                    }
                    .accessibilityLabel("Current file changes")
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("codexpad.diff-content")
                }
            } else {
                ProgressView("Preparing changes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("codexpad.diff-loading")
            }
        }
        .task(id: model.currentDiff) {
            let snapshot = model.currentDiff
            guard !snapshot.isEmpty else {
                parsedDiff = nil
                return
            }
            // Parsing is tied to the raw diff, not every observed model update.
            // Keep stale results out when another patch arrives during parsing.
            let presentation = await Task.detached(priority: .utility) {
                WorkbenchDiffPresentation(document: CodexDiffDocument.parse(snapshot))
            }.value
            guard !Task.isCancelled, model.currentDiff == snapshot else { return }
            parsedDiff = presentation
        }
    }

    private var changesActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { changesActionButtons }
            VStack(alignment: .leading, spacing: 8) { changesActionButtons }
        }
    }

    @ViewBuilder
    private var changesActionButtons: some View {
        Button {
            UIPasteboard.general.string = model.currentDiff
        } label: {
            Label("Copy diff", systemImage: "doc.on.doc")
                .frame(minHeight: CodexLayout.touchTarget)
        }
        .disabled(model.currentDiff.isEmpty)
        .accessibilityIdentifier("codexpad.diff-copy")

        Button {
            Task { await model.startReview() }
        } label: {
            Label("Review changes", systemImage: "checkmark.bubble")
                .frame(minHeight: CodexLayout.touchTarget)
        }
        .buttonStyle(.bordered)
        .disabled(model.selectedThreadID == nil || model.isTurnRunning)
        .accessibilityIdentifier("codexpad.review")
    }

    private func diffSummary(_ presentation: WorkbenchDiffPresentation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if presentation.hasKnownStatistics {
                HStack(spacing: 16) {
                    Text("+\(presentation.additions)")
                        .foregroundStyle(CodexPalette.diffAddedInk)
                    Text("−\(presentation.deletions)")
                        .foregroundStyle(CodexPalette.diffRemovedInk)
                }
                .font(.subheadline.monospaced().weight(.semibold))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(presentation.additions) added lines, \(presentation.deletions) removed lines in validated text hunks")
                .accessibilityIdentifier("codexpad.diff-summary")
            } else {
                Label("Line counts unavailable", systemImage: "info.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CodexPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("codexpad.diff-summary")
            }

            if presentation.hasIncompleteStatistics && presentation.hasKnownStatistics {
                Label("Counts include validated text hunks only. Raw and binary patches remain available below.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(CodexPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func diffFile(_ file: CodexDiffFile, minimumLineWidth: CGFloat) -> some View {
        let expanded = !collapsedDiffFiles.contains(file.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    if expanded {
                        collapsedDiffFiles.insert(file.id)
                    } else {
                        collapsedDiffFiles.remove(file.id)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .frame(width: 16, height: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text((file.path as NSString).lastPathComponent)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CodexPalette.ink)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(file.path)
                                .font(.caption.monospaced())
                                .foregroundStyle(CodexPalette.secondaryInk)
                                .lineLimit(2)
                                .truncationMode(.middle)
                            if let previousPath = file.previousPath {
                                Text("Previously: \(previousPath)")
                                    .font(.caption)
                                    .foregroundStyle(CodexPalette.secondaryInk)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                            fileStatus(file)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: CodexLayout.touchTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(diffFileLabel(file))
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                .accessibilityHint("Shows or hides this file’s patch")
                .accessibilityIdentifier("codexpad.diff-file-toggle.\(file.id)")

                Button {
                    UIPasteboard.general.string = file.rawText
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: CodexLayout.touchTarget, height: CodexLayout.touchTarget)
                }
                .accessibilityLabel("Copy patch for \(file.path)")
                .accessibilityIdentifier("codexpad.diff-file-copy.\(file.id)")
            }

            if expanded {
                if let note = file.note {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(CodexPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if file.kind == .text && file.hunks.reduce(0, { $0 + $1.lines.count }) <= 2_000 {
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(file.hunks, id: \.id) { hunk in
                                diffHunk(hunk, fileID: file.id, minimumLineWidth: minimumLineWidth)
                            }
                        }
                    }
                } else {
                    if file.kind == .text {
                        Text("Large patch shown as raw text for responsive scrolling.")
                            .font(.caption)
                            .foregroundStyle(CodexPalette.secondaryInk)
                    }
                    CodexCodeView(
                        code: file.rawText,
                        language: "diff",
                        copyID: "codexpad.diff-raw-copy.\(file.id)",
                        copyLabel: "Copy raw patch"
                    )
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("codexpad.diff-raw.\(file.id)")
                }
            }
        }
        .codexPanel()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("codexpad.diff-file.\(file.id)")
    }

    private func fileStatus(_ file: CodexDiffFile) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { fileStatusLabels(file) }
            VStack(alignment: .leading, spacing: 6) { fileStatusLabels(file) }
        }
        .font(.caption.weight(.medium))
    }

    @ViewBuilder
    private func fileStatusLabels(_ file: CodexDiffFile) -> some View {
        let statistics = parsedDiff?.fileStatistics[file.id]
        if file.isNewFile {
            Label("New file", systemImage: "plus.circle")
                .foregroundStyle(CodexPalette.diffAddedInk)
        } else if file.isDeletedFile {
            Label("Deleted file", systemImage: "minus.circle")
                .foregroundStyle(CodexPalette.diffRemovedInk)
        }
        if let additions = statistics?.additions, let deletions = statistics?.deletions {
            Text("+\(additions)").foregroundStyle(CodexPalette.diffAddedInk)
            Text("−\(deletions)").foregroundStyle(CodexPalette.diffRemovedInk)
        } else {
            Text(file.kind == .binary ? "Binary patch" : "Raw patch")
                .foregroundStyle(CodexPalette.secondaryInk)
        }
    }

    private func diffFileLabel(_ file: CodexDiffFile) -> String {
        var labels = [file.path]
        if let previousPath = file.previousPath { labels.append("Previously \(previousPath)") }
        if file.isNewFile { labels.append("New file") }
        if file.isDeletedFile { labels.append("Deleted file") }
        if let statistics = parsedDiff?.fileStatistics[file.id],
           let additions = statistics.additions, let deletions = statistics.deletions {
            labels.append("\(additions) added lines, \(deletions) removed lines")
        } else {
            labels.append(file.kind == .binary ? "Binary patch" : "Raw patch")
        }
        return labels.joined(separator: ", ")
    }

    private func diffHunk(_ hunk: CodexDiffHunk, fileID: String, minimumLineWidth: CGFloat) -> some View {
        let largestNumber = hunk.lines.map { max($0.oldNumber ?? 0, $0.newNumber ?? 0) }.max() ?? 0
        let numberWidth = CGFloat(max(4, String(largestNumber).count)) * diffCharacterWidth + 8
        return VStack(alignment: .leading, spacing: 0) {
            Text(hunk.header)
                .font(.caption.monospaced())
                .foregroundStyle(CodexPalette.secondaryInk)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(minWidth: minimumLineWidth, alignment: .leading)
                .background(CodexPalette.canvas)

            ForEach(hunk.lines, id: \.id) { line in
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(line.oldNumber.map(String.init) ?? " ")
                        .foregroundStyle(CodexPalette.secondaryInk)
                        .frame(width: numberWidth, alignment: .trailing)
                    Text(line.newNumber.map(String.init) ?? " ")
                        .foregroundStyle(CodexPalette.secondaryInk)
                        .frame(width: numberWidth, alignment: .trailing)
                    Text(line.prefix)
                        .frame(width: diffCharacterWidth * 2, alignment: .center)
                    Text(line.text)
                        .fixedSize(horizontal: true, vertical: false)
                        .textSelection(.enabled)
                        .padding(.trailing, 12)
                }
                .font(.callout.monospaced())
                .foregroundStyle(diffLineInk(line.kind))
                .padding(.vertical, 3)
                .frame(minWidth: minimumLineWidth, alignment: .leading)
                .background(diffLineSurface(line.kind))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(diffLineLabel(line))
                .accessibilityIdentifier("codexpad.diff-line.\(fileID).\(hunk.id).\(line.id)")
            }
        }
    }

    private func diffLineInk(_ kind: CodexDiffLine.Kind) -> Color {
        switch kind {
        case .addition: CodexPalette.diffAddedInk
        case .deletion: CodexPalette.diffRemovedInk
        case .context: CodexPalette.ink
        case .noNewline: CodexPalette.secondaryInk
        }
    }

    private func diffLineSurface(_ kind: CodexDiffLine.Kind) -> Color {
        switch kind {
        case .addition: CodexPalette.diffAddedSurface
        case .deletion: CodexPalette.diffRemovedSurface
        case .context, .noNewline: Color.clear
        }
    }

    private func diffLineLabel(_ line: CodexDiffLine) -> String {
        let position: String
        switch line.kind {
        case .addition: position = "Added line \(line.newNumber.map(String.init) ?? "")"
        case .deletion: position = "Removed line \(line.oldNumber.map(String.init) ?? "")"
        case .context: position = "Context, old line \(line.oldNumber.map(String.init) ?? ""), new line \(line.newNumber.map(String.init) ?? "")"
        case .noNewline: position = "No newline"
        }
        return "\(position), \(line.prefix)\(line.text)"
    }

    private var filesView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    Task { await model.navigateUpDirectory() }
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: CodexLayout.touchTarget, height: CodexLayout.touchTarget)
                }
                .disabled(model.directoryPath == "/")
                .accessibilityLabel("Parent directory")
                .accessibilityIdentifier("codexpad.files-parent")

                VStack(alignment: .leading, spacing: 5) {
                    Label(directoryName, systemImage: "folder")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CodexPalette.ink)
                        .lineLimit(2)
                    Text(model.directoryPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(CodexPalette.secondaryInk)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .accessibilityLabel("Directory path, \(model.directoryPath)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task { await model.loadDirectory(model.directoryPath) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: CodexLayout.touchTarget, height: CodexLayout.touchTarget)
                }
                .accessibilityLabel("Refresh directory")
                .accessibilityIdentifier("codexpad.files-refresh")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(CodexPalette.surface)

            if let fileName = model.filePreviewName {
                filePreview(fileName)
            } else if model.directoryEntries.isEmpty {
                ContentUnavailableView(
                    "No entries loaded",
                    systemImage: "folder",
                    description: Text("Refresh this directory to load its files and folders.")
                )
            } else {
                List(model.directoryEntries) { entry in
                    Button {
                        Task { await model.openEntry(entry) }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.text")
                                .font(.title3)
                                .foregroundStyle(entry.isDirectory ? CodexPalette.cobalt : CodexPalette.secondaryInk)
                                .frame(width: 26)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(CodexPalette.ink)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(entry.path)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(CodexPalette.secondaryInk)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: entry.isDirectory ? "chevron.right" : "eye")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CodexPalette.secondaryInk)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: CodexLayout.touchTarget)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!entry.isDirectory && !entry.isFile)
                    .accessibilityLabel("\(entry.name), \(entry.isDirectory ? "directory" : "file")")
                    .accessibilityHint(entry.isDirectory ? "Opens directory" : "Previews file")
                    .accessibilityIdentifier("codexpad.file-entry.\(entry.path)")
                    .listRowBackground(CodexPalette.surface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var directoryName: String {
        model.directoryPath == "/" ? "File system" : (model.directoryPath as NSString).lastPathComponent
    }

    private func filePreview(_ fileName: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    model.filePreviewName = nil
                    model.filePreview = ""
                    model.filePreviewIsTruncated = false
                    model.filePreviewIsBinary = false
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(minHeight: CodexLayout.touchTarget)
                }
                .accessibilityIdentifier("codexpad.file-preview-back")

                Text(fileName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CodexPalette.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("codexpad.file-preview-name")

                Button {
                    UIPasteboard.general.string = model.filePreview
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: CodexLayout.touchTarget, height: CodexLayout.touchTarget)
                }
                .disabled(model.filePreviewIsBinary)
                .accessibilityLabel(model.filePreviewIsTruncated ? "Copy preview" : "Copy file content")
                .accessibilityIdentifier("codexpad.file-preview-copy")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(CodexPalette.surface)

            if model.filePreviewIsTruncated && !model.filePreviewIsBinary {
                Label("Preview limited to the first 200 KB. Copy includes only this preview.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(CodexPalette.amber)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(CodexPalette.amber.opacity(0.08))
                    .accessibilityIdentifier("codexpad.file-preview-truncated")
            }

            if model.filePreviewIsBinary {
                ContentUnavailableView(
                    "Preview unavailable",
                    systemImage: "doc",
                    description: Text("This file cannot be displayed as UTF-8 text.")
                )
                .accessibilityIdentifier("codexpad.file-preview-binary")
            } else if model.filePreview.isEmpty {
                ContentUnavailableView("Empty file", systemImage: "doc.text")
            } else {
                ScrollView(.vertical) {
                    if isPlainTextFile(fileName) {
                        Text(model.filePreview)
                            .font(.body)
                            .lineSpacing(5)
                            .foregroundStyle(CodexPalette.ink)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    } else {
                        CodexCodeView(
                            code: model.filePreview,
                            language: CodexCodeLanguage.language(forFileName: fileName),
                            showsLineNumbers: true,
                            copyID: "codexpad.file-preview-code-copy",
                            copyLabel: model.filePreviewIsTruncated ? "Copy preview" : "Copy file content"
                        )
                        .padding(16)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("codexpad.file-preview-content")
            }
        }
    }

    private func isPlainTextFile(_ fileName: String) -> Bool {
        ["txt", "md", "markdown", "log", "csv", "tsv"].contains((fileName as NSString).pathExtension.lowercased())
    }

    private var runtimeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Label("On-device Linux", systemImage: "cpu")
                    .font(.headline)
                    .foregroundStyle(CodexPalette.teal)
                Text("iSH runs an ARM64 Alpine Linux guest in this app. Codex, shell commands, Git, and project files stay on the iPad.")
                    .font(.callout)
                    .foregroundStyle(CodexPalette.secondaryInk)
                Divider()
                ForEach(model.runtimeLog.indices, id: \.self) { index in
                    Text(model.runtimeLog[index])
                        .font(.caption.monospaced())
                        .foregroundStyle(CodexPalette.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .codexPanel()
            .padding(16)
        }
    }

    private func planIcon(_ status: String) -> String {
        switch status {
        case "completed": "checkmark.circle.fill"
        case "inProgress", "in_progress": "circle.dotted.circle.fill"
        default: "circle"
        }
    }

    private func planColor(_ status: String) -> Color {
        switch status {
        case "completed": CodexPalette.teal
        case "inProgress", "in_progress": CodexPalette.cobalt
        default: CodexPalette.secondaryInk
        }
    }
}

/// Counts are derived once alongside parsing, so streamed conversation updates
/// do not repeatedly scan every diff line while this workbench remains open.
private struct WorkbenchDiffPresentation: Sendable {
    struct FileStatistics: Sendable {
        let additions: Int?
        let deletions: Int?
    }

    let document: CodexDiffDocument
    let fileStatistics: [String: FileStatistics]
    let additions: Int
    let deletions: Int
    let hasKnownStatistics: Bool
    let hasIncompleteStatistics: Bool

    init(document: CodexDiffDocument) {
        self.document = document
        var statistics: [String: FileStatistics] = [:]
        var added = 0
        var removed = 0
        var known = false
        var incomplete = false
        for file in document.files {
            let additions = file.additions
            let deletions = file.deletions
            statistics[file.id] = FileStatistics(additions: additions, deletions: deletions)
            if let additions, let deletions {
                known = true
                added += additions
                removed += deletions
            } else {
                incomplete = true
            }
        }
        fileStatistics = statistics
        additions = added
        deletions = removed
        hasKnownStatistics = known
        hasIncompleteStatistics = incomplete
    }
}
