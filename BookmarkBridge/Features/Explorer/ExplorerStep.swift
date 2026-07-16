//
//  ExplorerStep.swift
//  BookmarkBridge
//

import Foundation

/// One level of the explorer navigation stack: either a source's root level or a
/// folder within it. Used as the typed navigation path value (wired in a later
/// step) and as the input to the breadcrumb mapper.
nonisolated enum ExplorerStep: Hashable, Sendable {
    case source(BookmarkSource, BookmarkTree)
    case folder(BookmarkFolder)
}
