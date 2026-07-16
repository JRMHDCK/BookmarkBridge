//
//  SearchResultsView.swift
//  BookmarkBridge
//

import SwiftUI

/// The global-search results, shown in place of the dashboard while a query is
/// active. Deliberately plain and macOS-native: a sectioned list grouped by
/// source, and the system "no results" view when nothing matches. No custom
/// Spotlight-style overlay, no extra animation.
struct SearchResultsView: View {
    let model: SearchViewModel
    /// Invoked when the user activates a result; the dashboard turns it into an
    /// explorer navigation. The view itself performs no navigation logic.
    let onSelect: (BookmarkSearchResult) -> Void

    var body: some View {
        if model.showsNoResults {
            ContentUnavailableView.search(text: model.query)
        } else {
            List {
                ForEach(model.resultsBySource) { group in
                    Section {
                        ForEach(group.results) { result in
                            Button {
                                onSelect(result)
                            } label: {
                                SearchResultRow(result: result)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Ouvre l'emplacement dans l'explorateur")
                        }
                    } header: {
                        Text(group.source.displayName)
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

/// One search hit: type icon, title, its host/URL, and the full folder path.
/// Read-only display; navigation to the item is wired in a later palier.
private struct SearchResultRow: View {
    let result: BookmarkSearchResult

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: result.isFolder ? "folder.fill" : "bookmark")
                .foregroundStyle(result.isFolder ? Theme.Palette.blue : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(displayTitle)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(pathText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var displayTitle: String {
        result.title.isEmpty ? "(Sans titre)" : result.title
    }

    /// Bookmarks show their host (falling back to the full URL); folders have no
    /// subtitle.
    private var subtitle: String? {
        guard !result.isFolder else { return nil }
        return result.host ?? result.url?.absoluteString
    }

    /// The full path: the source, then each ancestor folder with its friendly
    /// name — e.g. "Safari › Barre des favoris › Dev".
    private var pathText: String {
        ([result.source.displayName] + result.path.map { FolderTitleFormatter.friendly($0.title) })
            .joined(separator: " › ")
    }

    private var accessibilityLabel: String {
        let kind = result.isFolder ? "Dossier" : "Favori"
        let where_ = "dans \(pathText)"
        if let subtitle {
            return "\(kind) \(displayTitle), \(subtitle), \(where_)"
        }
        return "\(kind) \(displayTitle), \(where_)"
    }
}

// MARK: - Previews

@MainActor
private func previewModel(query: String) -> SearchViewModel {
    let model = SearchViewModel(engine: BookmarkSearchEngine())
    model.updateSources([
        SearchableSource(source: .singleProfile(.safari), tree: .sample(for: .safari)),
        SearchableSource(
            source: BookmarkSource(browser: .chrome, profile: "Default", displayName: "Chrome — Perso"),
            tree: .sample(for: .chrome)
        ),
    ])
    model.query = query
    return model
}

#Preview("Résultats") {
    NavigationStack {
        SearchResultsView(model: previewModel(query: "s"), onSelect: { _ in })
    }
    .frame(width: 480, height: 440)
}

#Preview("Aucun résultat") {
    NavigationStack {
        SearchResultsView(model: previewModel(query: "zzzzz"), onSelect: { _ in })
    }
    .frame(width: 480, height: 300)
}
