//
//  SyncPreviewView.swift
//  BookmarkBridge
//
//  The dry-run preview: what a bidirectional sync WOULD add to each browser.
//  Strictly read-only — there is deliberately no "Apply" action here; writing
//  (with backup and safeguards) comes in a later phase.
//

import SwiftUI

struct SyncPreviewView: View {
    @Bindable var model: SyncPreviewViewModel
    let reloadChromeTree: @MainActor (BookmarkSourceID) async -> BookmarkTree?
    let dismissAfterSuccess: @MainActor () -> Void
    @State private var confirmingApply = false

    init(
        model: SyncPreviewViewModel,
        reloadChromeTree: @escaping @MainActor (BookmarkSourceID) async -> BookmarkTree? = { _ in nil },
        dismissAfterSuccess: @escaping @MainActor () -> Void = {}
    ) {
        self.model = model
        self.reloadChromeTree = reloadChromeTree
        self.dismissAfterSuccess = dismissAfterSuccess
    }

    var body: some View {
        Group {
            if model.isEmpty {
                ContentUnavailableView(
                    DocumentationText.value("legacyPreview.upToDate"),
                    systemImage: "checkmark.circle"
                )
            } else {
                List {
                    ForEach(model.directions) { direction in
                        Section {
                            ForEach(direction.additions) { addition in
                                AdditionRow(addition: addition)
                            }
                        } header: {
                            Label(
                                DocumentationText.formatted(
                                    "legacyPreview.addToTarget",
                                    direction.targetName,
                                    direction.additions.count
                                ),
                                systemImage: "arrow.down.circle"
                            )
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(DocumentationText.value("legacyPreview.title"))
        .safeAreaInset(edge: .top) { profilePicker }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .task(id: model.selectedChromeID) {
            await model.refreshAvailableBackup()
        }
        .animation(Theme.Motion.stateChange, value: model.applyState)
    }

    /// Lets the user choose the target Chrome profile when several are available.
    @ViewBuilder
    private var profilePicker: some View {
        if model.chromeCandidates.count > 1 {
            HStack(spacing: Theme.Spacing.m) {
                Text(DocumentationText.value("legacyPreview.targetProfile"))
                Spacer(minLength: 0)
                Picker(
                    DocumentationText.value("legacyPreview.targetProfile"),
                    selection: $model.selectedChromeID
                ) {
                    ForEach(model.chromeCandidates) { candidate in
                        Text(candidate.writable == nil
                             ? DocumentationText.formatted(
                                 "legacyPreview.readOnlyProfile",
                                 candidate.source.displayName
                             )
                             : candidate.source.displayName)
                            .tag(Optional(candidate.id))
                    }
                }
                .labelsHidden()
                .fixedSize()
                .disabled(model.isBusy)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Materials.bar)
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if model.applyState != .idle {
            applyBar
        } else if model.canRestore {
            applyBar
        } else if model.canApplyToChrome {
            applyBar
        } else if model.selectedChromeIsReadOnly {
            readOnlyBar
        } else {
            dryRunBanner
        }
    }

    /// Explains why Apply is unavailable for a read-only profile (rather than
    /// silently hiding the button).
    private var readOnlyBar: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label(
                    DocumentationText.value("legacyPreview.readOnly"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                    .font(.callout).fontWeight(.medium)
                    .foregroundStyle(Theme.Palette.warning)
                Text(
                    model.chromeTargetName
                        ?? DocumentationText.value("browser.chrome.shortName")
                )
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(DocumentationText.value("action.apply")) {}
                .buttonStyle(.borderedProminent)
                .disabled(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.Materials.bar)
    }

    /// Read-only case: no writable Chrome target (or nothing to add).
    private var dryRunBanner: some View {
        Label(
            DocumentationText.value("legacyPreview.dryRun"),
            systemImage: "eye"
        )
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .background(Theme.Materials.bar)
    }

    /// Safari → Chrome apply action, reflecting the apply state.
    @ViewBuilder
    private var applyBar: some View {
        let name = model.chromeTargetName
            ?? DocumentationText.value("browser.chrome.shortName")
        Group {
            switch model.applyState {
            case .idle:
                HStack(spacing: Theme.Spacing.m) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        if model.canApplyToChrome {
                            Text(additionText(count: model.chromeAdditionsCount, target: name))
                                .font(.callout).fontWeight(.medium)
                            Text(DocumentationText.value("sync.closeAndBackup"))
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text(
                                DocumentationText.formatted(
                                    "legacyPreview.backupAvailable",
                                    name
                                )
                            )
                                .font(.callout).fontWeight(.medium)
                            Text(DocumentationText.value("sync.closeBeforeRestore"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if model.canRestore {
                        Button(DocumentationText.value("action.restore")) {
                            Task { await restoreAndReload() }
                        }
                            .help(
                                DocumentationText.value(
                                    "tooltip.restore"
                                )
                            )
                    }
                    if model.canApplyToChrome {
                        Button(DocumentationText.value("action.apply")) {
                            confirmingApply = true
                        }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.accentColor)
                            .help(
                                DocumentationText.value(
                                    "tooltip.synchronize"
                                )
                            )
                    }
                }
            case .applying:
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text(DocumentationText.value("sync.inProgress"))
                        .foregroundStyle(.secondary)
                }
            case .applied(let count):
                HStack(spacing: Theme.Spacing.m) {
                    Label(
                        appliedText(count: count, target: name),
                        systemImage: "checkmark.circle"
                    )
                        .foregroundStyle(Theme.Palette.green)
                    Spacer(minLength: 0)
                    if model.canRestore {
                        Button(DocumentationText.value("action.restore")) {
                            Task { await restoreAndReload() }
                        }
                            .help(
                                DocumentationText.value(
                                    "tooltip.restore"
                                )
                            )
                    }
                }
            case .restoring:
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text(DocumentationText.value("restore.inProgress"))
                        .foregroundStyle(.secondary)
                }
            case .restored:
                Label(
                    DocumentationText.value("restore.completed"),
                    systemImage: "checkmark.circle"
                )
                    .foregroundStyle(Theme.Palette.green)
            case .failed(let message):
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    UserFacingErrorDetails(
                        presentation:
                            UserFacingErrorPresentation.presentation(
                                for: message
                            )
                    )
                    HStack {
                        Spacer(minLength: 0)
                        if model.canRestore {
                            Button(DocumentationText.value("action.restore")) {
                                Task { await restoreAndReload() }
                            }
                            .help(
                                DocumentationText.value(
                                    "tooltip.restore"
                                )
                            )
                        } else if model.canRetry {
                            Button(DocumentationText.value("action.retry")) {
                                model.prepareRetry()
                                confirmingApply = true
                            }
                            .help(
                                DocumentationText.value(
                                    "tooltip.retry"
                                )
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.Materials.bar)
        .confirmationDialog(
            additionConfirmation(
                count: model.chromeAdditionsCount,
                target: name
            ),
            isPresented: $confirmingApply,
            titleVisibility: .visible
        ) {
            Button(DocumentationText.value("action.apply")) {
                Task { await applyAndReload() }
            }
            Button(DocumentationText.value("action.cancel"), role: .cancel) {}
        } message: {
            Text(DocumentationText.value("sync.confirmation.message"))
        }
    }

    private func applyAndReload() async {
        await model.apply()
        guard case .applied = model.applyState,
              let sourceID = model.selectedChromeID else { return }
        if let tree = await reloadChromeTree(sourceID) {
            model.updateSelectedChromeTree(tree)
        }
        do {
            try await Task.sleep(for: .seconds(1))
        } catch {
            return
        }
        guard case .applied = model.applyState else { return }
        dismissAfterSuccess()
    }

    private func restoreAndReload() async {
        let sourceID = model.selectedChromeID
        await model.restore()
        guard case .restored = model.applyState else { return }
        if let sourceID, let tree = await reloadChromeTree(sourceID) {
            model.updateSelectedChromeTree(tree)
        }
        do {
            try await Task.sleep(for: .seconds(1))
        } catch {
            return
        }
        guard case .restored = model.applyState else { return }
        dismissAfterSuccess()
    }

    private func additionText(count: Int, target: String) -> String {
        DocumentationText.formatted(
            count == 1
                ? "legacyPreview.addition.one"
                : "legacyPreview.addition.other",
            count,
            target
        )
    }

    private func appliedText(count: Int, target: String) -> String {
        DocumentationText.formatted(
            count == 1
                ? "legacyPreview.applied.one"
                : "legacyPreview.applied.other",
            count,
            target
        )
    }

    private func additionConfirmation(count: Int, target: String) -> String {
        DocumentationText.formatted(
            count == 1
                ? "legacyPreview.confirm.one"
                : "legacyPreview.confirm.other",
            count,
            target
        )
    }
}

private struct AdditionRow: View {
    let addition: SyncPreviewViewModel.Addition

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "bookmark")
                .foregroundStyle(.secondary)
                .frame(width: Theme.Size.minimumInteractive)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(addition.title)
                    .lineLimit(1)
                HStack(spacing: Theme.Spacing.xs) {
                    if let subtitle = addition.subtitle {
                        Text(subtitle)
                            .truncationMode(.middle)
                        Text(DocumentationText.value("common.separator"))
                            .accessibilityHidden(true)
                    }
                    Text(addition.originPath)
                        .foregroundStyle(.tertiary)
                        .truncationMode(.head)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            DocumentationText.formatted(
                "legacyPreview.addition.accessibility",
                addition.title,
                addition.subtitle ?? "",
                addition.originPath
            )
        )
    }
}

// MARK: - Preview

@MainActor
private func previewModel() -> SyncPreviewViewModel {
    func bookmark(_ id: String, _ title: String, _ url: String) -> BookmarkNode {
        .bookmark(Bookmark(id: BookmarkID(id), title: title, url: URL(string: url)!))
    }
    let safariBar = BookmarkFolder(id: BookmarkID("s.bar"), title: "BookmarksBar", children: [
        bookmark("s.apple", "Apple", "https://apple.com"),
        BookmarkFolder(id: BookmarkID("s.dev"), title: "Dev", children: [
            bookmark("s.swift", "Swift", "https://swift.org"),
        ]).asNode,
    ])
    let safari = BookmarkTree(browser: .safari, roots: [safariBar], capturedAt: .distantPast)

    let chromeBar = BookmarkFolder(id: BookmarkID("c.bar"), title: "Barre", children: [
        bookmark("c.hn", "Hacker News", "https://news.ycombinator.com"),
    ])
    let chrome = BookmarkTree(browser: .chrome, roots: [chromeBar], capturedAt: .distantPast)

    let model = SyncPreviewViewModel()
    model.computePreview(
        (.singleProfile(.safari), safari),
        (BookmarkSource(browser: .chrome, profile: "Default", displayName: "Chrome — Perso"), chrome)
    )
    return model
}

private extension BookmarkFolder {
    var asNode: BookmarkNode { .folder(self) }
}

#Preview("Aperçu") {
    NavigationStack { SyncPreviewView(model: previewModel()) }
        .frame(width: 520, height: 460)
}

#Preview("Déjà synchronisés") {
    let model = SyncPreviewViewModel()
    return NavigationStack { SyncPreviewView(model: model) }
        .frame(width: 520, height: 300)
}
