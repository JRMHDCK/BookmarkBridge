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
    let model: SyncPreviewViewModel

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
        .safeAreaInset(edge: .bottom) { dryRunBanner }
    }

    /// Makes the read-only nature explicit; there is no apply button yet.
    private var dryRunBanner: some View {
        Label("Aperçu (dry-run) — aucune modification n'est appliquée.", systemImage: "eye")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .background(.bar)
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
