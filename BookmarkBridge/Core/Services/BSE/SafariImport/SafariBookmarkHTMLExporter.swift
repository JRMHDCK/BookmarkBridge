//
//  SafariBookmarkHTMLExporter.swift
//  BookmarkBridge
//

import CryptoKit
import Foundation

nonisolated struct SafariBookmarkHTMLExport: Hashable, Sendable {
    let data: Data
    let folderCount: Int
    let bookmarkCount: Int
    let skippedBookmarks: [SafariImportSkippedBookmark]
}

nonisolated enum SafariImportCompatibilityPolicy: Hashable, Sendable {
    case requireExactPlan
    case allowAdditiveImport
}

/// Produces the Netscape bookmark HTML format accepted by Safari while
/// preserving the source hierarchy and sibling order.
nonisolated struct SafariBookmarkHTMLExporter: Sendable {
    private let compatibilityAnalyzer = SafariImportCompatibilityAnalyzer()

    func export(_ tree: BookmarkTree) -> SafariBookmarkHTMLExport {
        var lines = [
            "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
            "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">",
            "<TITLE>BookmarkBridge Safari Import</TITLE>",
            "<H1>BookmarkBridge Safari Import</H1>",
            "<DL><p>",
        ]
        var folderCount = 0
        var bookmarkCount = 0
        var skippedBookmarks: [SafariImportSkippedBookmark] = []

        for folder in tree.roots {
            append(
                folder: folder,
                depth: 1,
                to: &lines,
                folderCount: &folderCount,
                bookmarkCount: &bookmarkCount,
                skippedBookmarks: &skippedBookmarks
            )
        }
        lines.append("</DL><p>")

        return SafariBookmarkHTMLExport(
            data: Data((lines.joined(separator: "\n") + "\n").utf8),
            folderCount: folderCount,
            bookmarkCount: bookmarkCount,
            skippedBookmarks: skippedBookmarks
        )
    }

    private func append(
        folder: BookmarkFolder,
        depth: Int,
        to lines: inout [String],
        folderCount: inout Int,
        bookmarkCount: inout Int,
        skippedBookmarks: inout [SafariImportSkippedBookmark]
    ) {
        let indentation = String(repeating: "    ", count: depth)
        folderCount += 1
        lines.append("\(indentation)<DT><H3>\(escape(folder.title))</H3>")
        lines.append("\(indentation)<DL><p>")

        for child in folder.children {
            switch child {
            case .folder(let childFolder):
                append(
                    folder: childFolder,
                    depth: depth + 1,
                    to: &lines,
                    folderCount: &folderCount,
                    bookmarkCount: &bookmarkCount,
                    skippedBookmarks: &skippedBookmarks
                )
            case .bookmark(let bookmark):
                guard compatibilityAnalyzer.supports(bookmark.url) else {
                    skippedBookmarks.append(SafariImportSkippedBookmark(
                        bookmarkID: bookmark.id,
                        title: bookmark.title,
                        url: bookmark.url,
                        reason: .unsupportedURLScheme
                    ))
                    continue
                }
                bookmarkCount += 1
                let childIndentation = String(
                    repeating: "    ",
                    count: depth + 1
                )
                lines.append(
                    "\(childIndentation)<DT><A HREF=\"\(escape(bookmark.url.absoluteString))\">\(escape(bookmark.title))</A>"
                )
            }
        }

        lines.append("\(indentation)</DL><p>")
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

/// Writes an import artifact only to an explicit caller-provided directory.
/// Production integration will supply an app-controlled temporary directory;
/// this type has no access to Safari's private storage.
nonisolated struct SafariImportPackageBuilder: Sendable {
    private let exporter = SafariBookmarkHTMLExporter()
    private let compatibilityAnalyzer = SafariImportCompatibilityAnalyzer()

    func build(
        tree: BookmarkTree,
        plan: SynchronizationPlan,
        destinationDirectory: URL,
        fileName: String = "BookmarkBridge-Safari-Import.html",
        compatibilityPolicy: SafariImportCompatibilityPolicy =
            .requireExactPlan
    ) throws -> SafariImportPackage {
        guard !fileName.isEmpty,
              fileName == URL(fileURLWithPath: fileName).lastPathComponent,
              fileName.lowercased().hasSuffix(".html") else {
            throw SafariImportPackageError.invalidFileName
        }
        return try build(
            tree: tree,
            plan: plan,
            destinationFileURL: destinationDirectory.appendingPathComponent(
                fileName,
                isDirectory: false
            ),
            compatibilityPolicy: compatibilityPolicy
        )
    }

    func build(
        tree: BookmarkTree,
        plan: SynchronizationPlan,
        destinationFileURL: URL,
        compatibilityPolicy: SafariImportCompatibilityPolicy =
            .requireExactPlan
    ) throws -> SafariImportPackage {
        let compatibility = compatibilityAnalyzer.analyze(plan)
        guard compatibility.isCompatible
                || compatibilityPolicy == .allowAdditiveImport else {
            throw SafariImportPackageError.incompatiblePlan(compatibility)
        }
        guard destinationFileURL.isFileURL,
              !destinationFileURL.lastPathComponent.isEmpty,
              destinationFileURL.pathExtension.lowercased() == "html" else {
            throw SafariImportPackageError.invalidFileName
        }

        let exported = exporter.export(tree)
        let destinationDirectory = destinationFileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: destinationDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            throw SafariImportPackageError.cannotCreateDirectory
        }

        do {
            try exported.data.write(to: destinationFileURL, options: .atomic)
        } catch {
            throw SafariImportPackageError.cannotWriteFile
        }

        return SafariImportPackage(
            fileURL: destinationFileURL,
            byteCount: exported.data.count,
            sha256: Data(SHA256.hash(data: exported.data)),
            folderCount: exported.folderCount,
            bookmarkCount: exported.bookmarkCount,
            skippedBookmarks: exported.skippedBookmarks,
            compatibility: compatibility
        )
    }
}
