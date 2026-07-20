//
//  ChromeBookmarkStore.swift
//  BookmarkBridge
//

import Foundation

/// Coordinates Chrome persistence safety only. It never interprets bookmark
/// intent, resolves identities or applies synchronization operations.
nonisolated struct ChromeBookmarkStore: Sendable {
    private let bookmarksFileURL: URL
    private let validator: any ChromeBookmarkValidating
    private let backupService: any ChromeBookmarkBackingUp
    private let atomicWriter: any ChromeAtomicallyWriting
    private let applicationStateChecker: any ChromeApplicationStateChecking
    private let fileExists: @Sendable (URL) -> Bool
    private let isReadable: @Sendable (URL) -> Bool
    private let readData: @Sendable (URL) throws -> Data
    private let fingerprintProvider: @Sendable (URL) throws -> ChromeDocumentFingerprint

    init(
        bookmarksFileURL: URL,
        validator: any ChromeBookmarkValidating,
        backupService: any ChromeBookmarkBackingUp,
        atomicWriter: any ChromeAtomicallyWriting,
        applicationStateChecker: any ChromeApplicationStateChecking,
        fileExists: @escaping @Sendable (URL) -> Bool = {
            FileManager().fileExists(atPath: $0.path(percentEncoded: false))
        },
        isReadable: @escaping @Sendable (URL) -> Bool = {
            FileManager().isReadableFile(atPath: $0.path(percentEncoded: false))
        },
        readData: @escaping @Sendable (URL) throws -> Data = {
            try Data(contentsOf: $0, options: .mappedIfSafe)
        },
        fingerprintProvider: @escaping @Sendable (URL) throws -> ChromeDocumentFingerprint = {
            try ChromeDocumentFingerprint.capture(at: $0)
        }
    ) {
        self.bookmarksFileURL = bookmarksFileURL
        self.validator = validator
        self.backupService = backupService
        self.atomicWriter = atomicWriter
        self.applicationStateChecker = applicationStateChecker
        self.fileExists = fileExists
        self.isReadable = isReadable
        self.readData = readData
        self.fingerprintProvider = fingerprintProvider
    }

    func load() throws -> ChromeBookmarkDocument {
        guard fileExists(bookmarksFileURL) else {
            throw ChromePersistenceError.fileMissing
        }
        guard isReadable(bookmarksFileURL) else {
            throw ChromePersistenceError.accessDenied
        }

        let before = try captureFingerprint()
        let data: Data
        do {
            data = try readData(bookmarksFileURL)
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            throw ChromePersistenceError.accessDenied
        } catch {
            throw ChromePersistenceError.invalidJSON
        }
        let after = try captureFingerprint()
        guard before == after,
              ChromeDocumentFingerprint.digest(of: data) == after.contentDigest,
              data.count == after.fileSize else {
            throw ChromePersistenceError.concurrentModification
        }

        let document = try ChromeBookmarkDocument(
            data: data,
            sourceFingerprint: after
        )
        try validator.validate(document)
        return document
    }

    /// Persists the supplied document and returns the mandatory retained backup.
    @discardableResult
    func save(_ document: ChromeBookmarkDocument) throws -> URL {
        try applicationStateChecker.ensureChromeIsClosed()

        let persistedData = try document.dataForPersistence()
        let persistedDocument = try ChromeBookmarkDocument(
            data: persistedData,
            sourceFingerprint: document.sourceFingerprint
        )
        try validator.validate(persistedDocument)

        let currentFingerprint = try captureFingerprint()
        guard currentFingerprint == document.sourceFingerprint else {
            throw ChromePersistenceError.concurrentModification
        }

        let backupURL = try backupService.createBackup(of: bookmarksFileURL)
        try atomicWriter.write(
            persistedData,
            to: bookmarksFileURL,
            replacing: document.sourceFingerprint
        )
        return backupURL
    }

    private func captureFingerprint() throws -> ChromeDocumentFingerprint {
        do {
            return try fingerprintProvider(bookmarksFileURL)
        } catch let error as ChromePersistenceError {
            throw error
        } catch {
            throw ChromePersistenceError.invalidFingerprint
        }
    }
}
