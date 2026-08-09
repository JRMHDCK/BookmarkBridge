//
//  BreadcrumbView.swift
//  BookmarkBridge
//

import SwiftUI

/// A read-only breadcrumb bar shown atop the explorer. Each crumb (except the
/// current one) truncates the navigation path back to its level when tapped; a
/// long trail folds its middle levels into a "…" menu.
struct BreadcrumbView: View {
    @Binding var path: [ExplorerStep]

    var body: some View {
        if !path.isEmpty {
            let cells = breadcrumbCells
            HStack(spacing: Theme.Spacing.s) {
                ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                    cellView(cell)
                    if index < cells.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .font(.callout)
            .lineLimit(1)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Materials.bar)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
    }

    private var breadcrumbCells: [BreadcrumbCell] {
        let layout = Breadcrumb(path: path).layout()
        var cells = layout.leading.map(BreadcrumbCell.crumb)
        if layout.isCollapsed {
            cells.append(.ellipsis(layout.collapsed))
        }
        cells.append(contentsOf: layout.trailing.map(BreadcrumbCell.crumb))
        return cells
    }

    @ViewBuilder
    private func cellView(_ cell: BreadcrumbCell) -> some View {
        switch cell {
        case .crumb(let item):
            if item.isCurrent {
                Text(item.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(
                        maxWidth:
                            Theme.Size.breadcrumbItemMaximumWidth
                    )
                    .help(item.title)
                    .accessibilityLabel(
                        DocumentationText.formatted(
                            "explorer.currentLevel",
                            item.title
                        )
                    )
            } else {
                Button {
                    path = item.path
                } label: {
                    Text(item.title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(
                            maxWidth:
                                Theme.Size.breadcrumbItemMaximumWidth
                        )
                }
                .buttonStyle(.link)
                .help(item.title)
                .accessibilityLabel(
                    DocumentationText.formatted(
                        "explorer.returnTo",
                        item.title
                    )
                )
            }
        case .ellipsis(let hidden):
            Menu {
                ForEach(hidden) { item in
                    Button(item.title) { path = item.path }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .help(DocumentationText.value("explorer.intermediate.tooltip"))
            .fixedSize()
            .accessibilityLabel(
                DocumentationText.value("explorer.intermediate.accessibility")
            )
        }
    }
}

/// One rendered element of the breadcrumb bar.
private enum BreadcrumbCell: Identifiable {
    case crumb(BreadcrumbItem)
    case ellipsis([BreadcrumbItem])

    var id: String {
        switch self {
        case .crumb(let item): "crumb-\(item.id)"
        case .ellipsis: "ellipsis"
        }
    }
}

// MARK: - Previews

private let previewSafari = BookmarkSource.singleProfile(.safari)
private let previewTree = BookmarkTree(browser: .safari, roots: [], capturedAt: .distantPast)
private func previewFolder(_ title: String) -> BookmarkFolder {
    BookmarkFolder(id: BookmarkID(title), title: title)
}

#Preview("Court") {
    BreadcrumbView(path: .constant([
        .source(previewSafari, previewTree),
        .folder(previewFolder("BookmarksBar")),
    ]))
    .frame(width: 520)
}

#Preview("Long (replié)") {
    BreadcrumbView(path: .constant([
        .source(previewSafari, previewTree),
        .folder(previewFolder("A")),
        .folder(previewFolder("B")),
        .folder(previewFolder("C")),
        .folder(previewFolder("D")),
        .folder(previewFolder("E")),
    ]))
    .frame(width: 520)
}
