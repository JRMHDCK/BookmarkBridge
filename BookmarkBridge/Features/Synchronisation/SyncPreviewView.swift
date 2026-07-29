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
                    "Les deux profils sont déjà synchronisés",
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
                            Label("À ajouter à \(direction.targetName) (\(direction.additions.count))",
                                  systemImage: "arrow.down.circle")
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Aperçu de la synchronisation")
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
                Text("Profil Chrome cible")
                Spacer(minLength: 0)
                Picker("Profil Chrome cible", selection: $model.selectedChromeID) {
                    ForEach(model.chromeCandidates) { candidate in
                        Text(candidate.writable == nil
                             ? "\(candidate.source.displayName) (lecture seule)"
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
                Label("Ce profil est en lecture seule.", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).fontWeight(.medium)
                    .foregroundStyle(Theme.Palette.warning)
                Text(model.chromeTargetName ?? "Chrome")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("Appliquer") {}
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
        Label("Aperçu (dry-run) — aucune modification n'est appliquée.", systemImage: "eye")
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
        let name = model.chromeTargetName ?? "Chrome"
        Group {
            switch model.applyState {
            case .idle:
                HStack(spacing: Theme.Spacing.m) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        if model.canApplyToChrome {
                            Text("Ajouter \(model.chromeAdditionsCount) \(favoriteWord(model.chromeAdditionsCount)) à \(name)")
                                .font(.callout).fontWeight(.medium)
                            Text("Chrome doit être fermé. Une sauvegarde sera créée automatiquement.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Une sauvegarde de \(name) est disponible.")
                                .font(.callout).fontWeight(.medium)
                            Text("Chrome doit être fermé avant la restauration.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if model.canRestore {
                        Button("Restaurer") { Task { await restoreAndReload() } }
                    }
                    if model.canApplyToChrome {
                        Button("Appliquer") { confirmingApply = true }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.accentColor)
                    }
                }
            case .applying:
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Synchronisation en cours…").foregroundStyle(.secondary)
                }
            case .applied(let count):
                HStack(spacing: Theme.Spacing.m) {
                    Label("\(count) \(favoriteWord(count)) \(count == 1 ? "ajouté" : "ajoutés") à \(name).", systemImage: "checkmark.circle")
                        .foregroundStyle(Theme.Palette.green)
                    Spacer(minLength: 0)
                    if model.canRestore {
                        Button("Restaurer") { Task { await restoreAndReload() } }
                    }
                }
            case .restoring:
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Restauration en cours…").foregroundStyle(.secondary)
                }
            case .restored:
                Label("Restauration terminée.", systemImage: "checkmark.circle")
                    .foregroundStyle(Theme.Palette.green)
            case .failed(let message):
                HStack(spacing: Theme.Spacing.m) {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Palette.error)
                    Spacer(minLength: 0)
                    if model.canRestore {
                        Button("Restaurer") { Task { await restoreAndReload() } }
                    } else if model.canRetry {
                        Button("Réessayer") {
                            model.prepareRetry()
                            confirmingApply = true
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
            "Ajouter \(model.chromeAdditionsCount) \(favoriteWord(model.chromeAdditionsCount)) à \(name) ?",
            isPresented: $confirmingApply,
            titleVisibility: .visible
        ) {
            Button("Appliquer") { Task { await applyAndReload() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Chrome doit être fermé. Une sauvegarde automatique sera créée avant toute modification.")
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

    private func favoriteWord(_ count: Int) -> String {
        count == 1 ? "favori" : "favoris"
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
                        Text("·")
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
        .accessibilityLabel("Ajouter \(addition.title), \(addition.subtitle ?? ""), depuis \(addition.originPath)")
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
