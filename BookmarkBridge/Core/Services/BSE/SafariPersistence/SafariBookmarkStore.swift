//
//  SafariBookmarkStore.swift
//  BookmarkBridge
//

import Foundation

/// Coordinates persistence safety only: read, validate, back up and replace.
/// It never interprets or mutates bookmark content.
nonisolated struct SafariBookmarkStore: Sendable {
    private let bookmarksFileURL: URL
    private let validator: any SafariBookmarkValidating
    private let backupService: any SafariBookmarkBackingUp
    private let atomicWriter: any SafariAtomicallyWriting
    private let applicationStateChecker: any SafariApplicationStateChecking
    private let fileExists: @Sendable (URL) -> Bool
    private let isReadable: @Sendable (URL) -> Bool
    private let readData: @Sendable (URL) throws -> Data
    private let fingerprintProvider: @Sendable (URL) throws -> SafariDocumentFingerprint

    init(
        bookmarksFileURL: URL,
        validator: any SafariBookmarkValidating,
        backupService: any SafariBookmarkBackingUp,
        atomicWriter: any SafariAtomicallyWriting,
        applicationStateChecker: any SafariApplicationStateChecking,
        fileExists: @escaping @Sendable (URL) -> Bool = {
            FileManager().fileExists(atPath: $0.path(percentEncoded: false))
        },
        isReadable: @escaping @Sendable (URL) -> Bool = {
            FileManager().isReadableFile(atPath: $0.path(percentEncoded: false))
        },
        readData: @escaping @Sendable (URL) throws -> Data = {
            try Data(contentsOf: $0, options: .mappedIfSafe)
        },
        fingerprintProvider: @escaping @Sendable (URL) throws -> SafariDocumentFingerprint = {
            try SafariDocumentFingerprint.capture(at: $0)
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

    func load() throws -> SafariBookmarkDocument {
        guard fileExists(bookmarksFileURL) else {
            throw SafariPersistenceError.fileMissing
        }
        guard isReadable(bookmarksFileURL) else {
            throw SafariPersistenceError.accessDenied
        }

        let before = try captureFingerprint()
        let data: Data
        do {
            data = try readData(bookmarksFileURL)
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            throw SafariPersistenceError.accessDenied
        } catch {
            throw SafariPersistenceError.invalidPropertyList
        }
        let after = try captureFingerprint()
        guard before == after,
              SafariDocumentFingerprint.digest(of: data) == after.contentDigest,
              data.count == after.fileSize else {
            throw SafariPersistenceError.concurrentModification
        }

        let document = try SafariBookmarkDocument(data: data, sourceFingerprint: after)
        try validator.validate(document)
        return document
    }

    /// Persists the supplied document and returns the mandatory retained backup.
    @discardableResult
    func save(_ document: SafariBookmarkDocument) throws -> URL {
        try applicationStateChecker.ensureSafariIsClosed()
        try validator.validate(document)

        let currentFingerprint = try captureFingerprint()
        guard currentFingerprint == document.sourceFingerprint else {
            throw SafariPersistenceError.concurrentModification
        }

        let backupURL = try backupService.createBackup(of: bookmarksFileURL)
        try atomicWriter.write(
            document.data,
            to: bookmarksFileURL,
            replacing: document.sourceFingerprint
        )
        return backupURL
    }

    private func captureFingerprint() throws -> SafariDocumentFingerprint {
        do {
            return try fingerprintProvider(bookmarksFileURL)
        } catch let error as SafariPersistenceError {
            throw error
        } catch {
            throw SafariPersistenceError.invalidFingerprint
        }
    }
}
