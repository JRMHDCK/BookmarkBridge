//
//  SynchronizationBackup.swift
//  BookmarkBridge
//

import Foundation

/// One retained, byte-for-byte copy of the target before a transaction starts.
nonisolated struct SynchronizationBackup: Hashable, Codable, Sendable {
    let backupURL: URL
    let targetURL: URL
    let createdAt: Date
}

nonisolated protocol SynchronizationBackupManaging: Sendable {
    func createBackup(
        targetURL: URL,
        backupDirectoryURL: URL
    ) throws -> SynchronizationBackup

    func restore(_ backup: SynchronizationBackup) throws
}

/// Filesystem implementation shared by both browser composition paths.
/// It copies the original once, then restores through a same-volume temporary
/// file and an atomic replacement.
nonisolated struct FileSynchronizationBackupManager:
    SynchronizationBackupManaging
{
    private let dateProvider: @Sendable () -> Date
    private let temporaryNameProvider: @Sendable () -> String
    private let fileExists: @Sendable (URL) -> Bool
    private let createDirectory: @Sendable (URL) throws -> Void
    private let copyItem: @Sendable (URL, URL) throws -> Void
    private let removeItem: @Sendable (URL) throws -> Void
    private let createEmptyFile: @Sendable (URL) -> Bool
    private let replaceItem: @Sendable (URL, URL) throws -> Void
    private let readData: @Sendable (URL) throws -> Data

    init(
        dateProvider: @escaping @Sendable () -> Date = Date.init,
        temporaryNameProvider: @escaping @Sendable () -> String = {
            UUID().uuidString
        },
        fileExists: @escaping @Sendable (URL) -> Bool = {
            FileManager().fileExists(atPath: $0.path(percentEncoded: false))
        },
        createDirectory: @escaping @Sendable (URL) throws -> Void = {
            try FileManager().createDirectory(
                at: $0,
                withIntermediateDirectories: true
            )
        },
        copyItem: @escaping @Sendable (URL, URL) throws -> Void = {
            try FileManager().copyItem(at: $0, to: $1)
        },
        removeItem: @escaping @Sendable (URL) throws -> Void = {
            try FileManager().removeItem(at: $0)
        },
        createEmptyFile: @escaping @Sendable (URL) -> Bool = {
            FileManager().createFile(
                atPath: $0.path(percentEncoded: false),
                contents: nil
            )
        },
        replaceItem: @escaping @Sendable (URL, URL) throws -> Void = {
            _ = try FileManager().replaceItemAt($0, withItemAt: $1)
        },
        readData: @escaping @Sendable (URL) throws -> Data = {
            try Data(contentsOf: $0)
        }
    ) {
        self.dateProvider = dateProvider
        self.temporaryNameProvider = temporaryNameProvider
        self.fileExists = fileExists
        self.createDirectory = createDirectory
        self.copyItem = copyItem
        self.removeItem = removeItem
        self.createEmptyFile = createEmptyFile
        self.replaceItem = replaceItem
        self.readData = readData
    }

    func createBackup(
        targetURL: URL,
        backupDirectoryURL: URL
    ) throws -> SynchronizationBackup {
        guard fileExists(targetURL) else {
            throw SynchronizationBackupFailure.targetMissing
        }
        let createdAt = dateProvider()
        let timestamp = Int64(createdAt.timeIntervalSince1970 * 1_000_000)
        let backupURL = backupDirectoryURL.appendingPathComponent(
            "\(targetURL.lastPathComponent)-\(timestamp).synchronization-backup",
            isDirectory: false
        )

        do {
            try createDirectory(backupDirectoryURL)
            guard !fileExists(backupURL) else {
                throw SynchronizationBackupFailure.backupCollision
            }
            try copyItem(targetURL, backupURL)
            guard try readData(targetURL) == readData(backupURL) else {
                try? removeItem(backupURL)
                throw SynchronizationBackupFailure.copyVerificationFailed
            }
        } catch let error as SynchronizationBackupFailure {
            throw error
        } catch {
            throw SynchronizationBackupFailure.copyFailed
        }

        return SynchronizationBackup(
            backupURL: backupURL,
            targetURL: targetURL,
            createdAt: createdAt
        )
    }

    func restore(_ backup: SynchronizationBackup) throws {
        let backupData: Data
        do {
            backupData = try readData(backup.backupURL)
            if try readData(backup.targetURL) == backupData {
                return
            }
        } catch {
            throw SynchronizationBackupFailure.atomicReplacementFailed
        }

        let temporaryURL = backup.targetURL.deletingLastPathComponent()
            .appendingPathComponent(
                ".\(backup.targetURL.lastPathComponent)."
                    + "\(temporaryNameProvider()).restore",
                isDirectory: false
            )
        defer {
            try? removeItem(temporaryURL)
        }

        do {
            guard !fileExists(temporaryURL) else {
                throw SynchronizationBackupFailure.temporaryCollision
            }
            guard createEmptyFile(temporaryURL) else {
                throw SynchronizationBackupFailure.temporaryWriteFailed
            }
            let handle = try FileHandle(forWritingTo: temporaryURL)
            do {
                try handle.write(contentsOf: backupData)
                try handle.synchronize()
                try handle.close()
            } catch {
                try? handle.close()
                throw SynchronizationBackupFailure.temporaryWriteFailed
            }
            try replaceItem(backup.targetURL, temporaryURL)
            guard try readData(backup.targetURL) == backupData else {
                throw SynchronizationBackupFailure.restoreVerificationFailed
            }
        } catch let error as SynchronizationBackupFailure {
            throw error
        } catch {
            throw SynchronizationBackupFailure.atomicReplacementFailed
        }
    }
}

nonisolated enum SynchronizationBackupFailure: Error, Hashable, Sendable {
    case targetMissing
    case backupCollision
    case copyFailed
    case copyVerificationFailed
    case temporaryCollision
    case temporaryWriteFailed
    case atomicReplacementFailed
    case restoreVerificationFailed
}
