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
            HStack(spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                    cellView(cell)
                    if index < cells.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .font(.callout)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
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
                    .accessibilityLabel("\(item.title), niveau courant")
            } else {
                Button(item.title) { path = item.path }
                    .buttonStyle(.link)
                    .accessibilityLabel("Revenir à \(item.title)")
            }
        case .ellipsis(let hidden):
            Menu("…") {
                ForEach(hidden) { item in
                    Button(item.title) { path = item.path }
                }
            }
            .menuStyle(.button)
            .fixedSize()
            .accessibilityLabel("Niveaux intermédiaires")
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
