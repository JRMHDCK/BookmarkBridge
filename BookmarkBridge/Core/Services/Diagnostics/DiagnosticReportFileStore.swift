//
//  DiagnosticReportFileStore.swift
//  BookmarkBridge
//

import Foundation

nonisolated protocol DiagnosticReportFileWriting: Sendable {
    func write(
        text: String,
        reportID: DiagnosticReportID,
        now: Date
    ) async throws -> URL

    func removeReport(at fileURL: URL) async throws
}

nonisolated enum DiagnosticReportFileError: Error, Equatable, Sendable {
    case fileCreationFailed
    case fileRemovalFailed
}

/// Writes shareable reports to a private temporary directory. Only files with
/// the generated BookmarkBridge report naming scheme are ever removed.
actor FileDiagnosticReportStore: DiagnosticReportFileWriting {
    static let defaultMaximumAge: TimeInterval = 24 * 60 * 60

    private let directory: URL
    private let maximumAge: TimeInterval
    private let fileManager: FileManager

    init(
        directory: URL,
        maximumAge: TimeInterval = FileDiagnosticReportStore.defaultMaximumAge,
        fileManager: FileManager = .default
    ) {
        self.directory = directory.standardizedFileURL
        self.maximumAge = max(0, maximumAge)
        self.fileManager = fileManager
    }

    static func inTemporaryDirectory() -> FileDiagnosticReportStore {
        FileDiagnosticReportStore(
            directory: FileManager.default.temporaryDirectory.appending(
                path: "BookmarkBridge/DiagnosticReports",
                directoryHint: .isDirectory
            )
        )
    }

    func write(
        text: String,
        reportID: DiagnosticReportID,
        now: Date
    ) throws -> URL {
        do {
            try ensureDirectory()
            try removeExpiredReports(now: now)
            let fileURL = directory.appending(
                path: "BookmarkBridge-\(reportID.rawValue).txt",
                directoryHint: .notDirectory
            )
            try Data(text.utf8).write(to: fileURL, options: .atomic)
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path(percentEncoded: false)
            )
            return fileURL
        } catch {
            throw DiagnosticReportFileError.fileCreationFailed
        }
    }

    func removeReport(at fileURL: URL) throws {
        let candidate = fileURL.standardizedFileURL
        guard candidate.deletingLastPathComponent() == directory,
              Self.isReportFile(candidate) else {
            return
        }
        guard fileManager.fileExists(
            atPath: candidate.path(percentEncoded: false)
        ) else {
            return
        }
        do {
            try fileManager.removeItem(at: candidate)
        } catch {
            throw DiagnosticReportFileError.fileRemovalFailed
        }
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path(percentEncoded: false)
        )
    }

    private func removeExpiredReports(now: Date) throws {
        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let cutoff = now.addingTimeInterval(-maximumAge)
        for fileURL in files where Self.isReportFile(fileURL) {
            let values = try fileURL.resourceValues(
                forKeys: [.contentModificationDateKey]
            )
            guard let modifiedAt = values.contentModificationDate,
                  modifiedAt < cutoff else {
                continue
            }
            try fileManager.removeItem(at: fileURL)
        }
    }

    private static func isReportFile(_ fileURL: URL) -> Bool {
        let name = fileURL.lastPathComponent
        return name.hasPrefix("BookmarkBridge-BB-")
            && name.hasSuffix(".txt")
    }
}
