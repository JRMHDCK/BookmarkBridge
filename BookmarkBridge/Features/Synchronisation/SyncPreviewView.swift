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
    @State private var confirmingApply = false

    var body: some View {
        Group {
            if model.isEmpty {
                ContentUnavailableView(
                    "Déjà synchronisés",
                    systemImage: "checkmark.circle",
                    description: Text("Aucun favori à ajouter d'un côté ou de l'autre.")
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
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if model.canApplyToChrome {
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
            VStack(alignment: .leading, spacing: 2) {
                Text("« \(model.chromeTargetName ?? "Ce profil") » est en lecture seule")
                    .font(.callout).fontWeight(.medium)
                Text("Favoris de compte ou profil à deux stockages — écriture non prise en charge en V1.")
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
        .background(.bar)
    }

    /// Read-only case: no writable Chrome target (or nothing to add).
    private var dryRunBanner: some View {
        Label("Aperçu (dry-run) — aucune modification n'est appliquée.", systemImage: "eye")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .background(.bar)
    }

    /// Safari → Chrome apply action, reflecting the apply state.
    @ViewBuilder
    private var applyBar: some View {
        let name = model.chromeTargetName ?? "Chrome"
        Group {
            switch model.applyState {
            case .idle:
                HStack(spacing: Theme.Spacing.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ajouter \(model.chromeAdditionsCount) favori(s) à \(name)")
                            .font(.callout).fontWeight(.medium)
                        Text("Google Chrome doit être fermé. Sauvegarde automatique.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button("Appliquer") { confirmingApply = true }
                        .buttonStyle(.borderedProminent)
                }
            case .applying:
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Application en cours…").foregroundStyle(.secondary)
                }
            case .applied(let count):
                HStack(spacing: Theme.Spacing.m) {
                    Label("\(count) favori(s) ajouté(s) à \(name).", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Palette.green)
                    Spacer(minLength: 0)
                    Button("Restaurer") { Task { await model.restore() } }
                }
            case .failed(let message):
                HStack(spacing: Theme.Spacing.m) {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Palette.error)
                    Spacer(minLength: 0)
                    Button("Restaurer") { Task { await model.restore() } }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(.bar)
        .confirmationDialog("Appliquer à \(name) ?", isPresented: $confirmingApply, titleVisibility: .visible) {
            Button("Appliquer") { Task { await model.apply() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Google Chrome doit être fermé. Une sauvegarde automatique est créée ; la restauration reste possible.")
        }
    }
}

private struct AdditionRow: View {
    let addition: SyncPreviewViewModel.Addition

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "bookmark")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(addition.title)
                if let subtitle = addition.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(addition.originPath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
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
