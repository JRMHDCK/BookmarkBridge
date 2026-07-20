//
//  ChromeAtomicWriter.swift
//  BookmarkBridge
//

import Foundation

nonisolated protocol ChromeAtomicallyWriting: Sendable {
    func write(
        _ data: Data,
        to destinationURL: URL,
        replacing expectedFingerprint: ChromeDocumentFingerprint
    ) throws
}

/// Stages bytes beside the destination, synchronizes them, verifies the source
/// fingerprint, then performs one same-volume atomic replacement.
nonisolated struct ChromeAtomicWriter: ChromeAtomicallyWriting {
    private let fileExists: @Sendable (URL) -> Bool
    private let writeTemporaryFile: @Sendable (Data, URL) throws -> Void
    private let synchronizeTemporaryFile: @Sendable (URL) throws -> Void
    private let removeItem: @Sendable (URL) throws -> Void
    private let temporaryURLProvider: @Sendable (URL) -> URL
    private let fingerprintProvider: @Sendable (URL) throws -> ChromeDocumentFingerprint
    private let replace: @Sendable (URL, URL) throws -> Void

    init(
        fileExists: @escaping @Sendable (URL) -> Bool = {
            FileManager().fileExists(atPath: $0.path(percentEncoded: false))
        },
        writeTemporaryFile: @escaping @Sendable (Data, URL) throws -> Void = {
            try $0.write(to: $1, options: [.withoutOverwriting])
        },
        synchronizeTemporaryFile: @escaping @Sendable (URL) throws -> Void = { URL in
            let handle = try FileHandle(forWritingTo: URL)
            do {
                try handle.synchronize()
                try handle.close()
            } catch {
                try? handle.close()
                throw error
            }
        },
        removeItem: @escaping @Sendable (URL) throws -> Void = {
            try FileManager().removeItem(at: $0)
        },
        temporaryURLProvider: @escaping @Sendable (URL) -> URL = { destinationURL in
            destinationURL.deletingLastPathComponent().appendingPathComponent(
                ".\(destinationURL.lastPathComponent).bookmarkbridge-\(UUID().uuidString).tmp",
                isDirectory: false
            )
        },
        fingerprintProvider: @escaping @Sendable (URL) throws -> ChromeDocumentFingerprint = {
            try ChromeDocumentFingerprint.capture(at: $0)
        },
        replace: (@Sendable (URL, URL) throws -> Void)? = nil
    ) {
        self.fileExists = fileExists
        self.writeTemporaryFile = writeTemporaryFile
        self.synchronizeTemporaryFile = synchronizeTemporaryFile
        self.removeItem = removeItem
        self.temporaryURLProvider = temporaryURLProvider
        self.fingerprintProvider = fingerprintProvider
        if let replace {
            self.replace = replace
        } else {
            self.replace = { destinationURL, temporaryURL in
                _ = try FileManager().replaceItemAt(
                    destinationURL,
                    withItemAt: temporaryURL,
                    backupItemName: nil,
                    options: []
                )
            }
        }
    }

    func write(
        _ data: Data,
        to destinationURL: URL,
        replacing expectedFingerprint: ChromeDocumentFingerprint
    ) throws {
        let temporaryURL = temporaryURLProvider(destinationURL)
        guard !fileExists(temporaryURL) else {
            throw ChromePersistenceError.temporaryWriteFailed
        }
        defer {
            if fileExists(temporaryURL) {
                try? removeItem(temporaryURL)
            }
        }

        do {
            try writeTemporaryFile(data, temporaryURL)
        } catch {
            throw ChromePersistenceError.temporaryWriteFailed
        }
        do {
            try synchronizeTemporaryFile(temporaryURL)
        } catch {
            throw ChromePersistenceError.synchronizationFailed
        }

        let currentFingerprint: ChromeDocumentFingerprint
        do {
            currentFingerprint = try fingerprintProvider(destinationURL)
        } catch let error as ChromePersistenceError {
            throw error
        } catch {
            throw ChromePersistenceError.invalidFingerprint
        }
        guard currentFingerprint == expectedFingerprint else {
            throw ChromePersistenceError.concurrentModification
        }

        do {
            try replace(destinationURL, temporaryURL)
        } catch {
            throw ChromePersistenceError.atomicReplacementFailed
        }
    }
}
