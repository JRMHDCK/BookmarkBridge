//
//  SafariAtomicWriter.swift
//  BookmarkBridge
//

import Foundation

nonisolated protocol SafariAtomicallyWriting: Sendable {
    func write(
        _ data: Data,
        to destinationURL: URL,
        replacing expectedFingerprint: SafariDocumentFingerprint
    ) throws
}

/// Writes and synchronizes a sibling temporary file, verifies the optimistic
/// concurrency token, then atomically replaces the destination.
nonisolated struct SafariAtomicWriter: SafariAtomicallyWriting {
    private let fileExists: @Sendable (URL) -> Bool
    private let createFile: @Sendable (URL) -> Bool
    private let removeItem: @Sendable (URL) throws -> Void
    private let temporaryURLProvider: @Sendable (URL) -> URL
    private let fingerprintProvider: @Sendable (URL) throws -> SafariDocumentFingerprint
    private let replace: @Sendable (URL, URL) throws -> Void

    init(
        fileExists: @escaping @Sendable (URL) -> Bool = {
            FileManager().fileExists(atPath: $0.path(percentEncoded: false))
        },
        createFile: @escaping @Sendable (URL) -> Bool = {
            FileManager().createFile(atPath: $0.path(percentEncoded: false), contents: nil)
        },
        removeItem: @escaping @Sendable (URL) throws -> Void = {
            try FileManager().removeItem(at: $0)
        },
        temporaryURLProvider: @escaping @Sendable (URL) -> URL = { destinationURL in
            FileManager.default.temporaryDirectory.appendingPathComponent(
                ".\(destinationURL.lastPathComponent).bookmarkbridge-\(UUID().uuidString).tmp",
                isDirectory: false
            )
        },
        fingerprintProvider: @escaping @Sendable (URL) throws -> SafariDocumentFingerprint = {
            try SafariDocumentFingerprint.capture(at: $0)
        },
        replace: (@Sendable (URL, URL) throws -> Void)? = nil
    ) {
        self.fileExists = fileExists
        self.createFile = createFile
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
        replacing expectedFingerprint: SafariDocumentFingerprint
    ) throws {
        let temporaryURL = temporaryURLProvider(destinationURL)
        guard !fileExists(temporaryURL) else {
            throw SafariPersistenceError.temporaryWriteFailed
        }
        defer { try? removeItem(temporaryURL) }

        do {
            guard createFile(temporaryURL) else {
                throw SafariPersistenceError.temporaryWriteFailed
            }
            let handle = try FileHandle(forWritingTo: temporaryURL)
            do {
                try handle.write(contentsOf: data)
                try handle.synchronize()
                try handle.close()
            } catch {
                try? handle.close()
                throw SafariPersistenceError.temporaryWriteFailed
            }
        } catch let error as SafariPersistenceError {
            throw error
        } catch {
            throw SafariPersistenceError.temporaryWriteFailed
        }

        let currentFingerprint: SafariDocumentFingerprint
        do {
            currentFingerprint = try fingerprintProvider(destinationURL)
        } catch let error as SafariPersistenceError {
            throw error
        } catch {
            throw SafariPersistenceError.invalidFingerprint
        }
        guard currentFingerprint == expectedFingerprint else {
            throw SafariPersistenceError.concurrentModification
        }

        do {
            try replace(destinationURL, temporaryURL)
        } catch {
            throw SafariPersistenceError.atomicReplacementFailed
        }
    }
}
