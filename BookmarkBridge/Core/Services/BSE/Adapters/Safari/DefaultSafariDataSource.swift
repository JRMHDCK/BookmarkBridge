//
//  DefaultSafariDataSource.swift
//  BookmarkBridge
//

import Foundation

/// Stable file attributes checked before and after one read.
nonisolated struct SafariStorageFingerprint: Hashable, Sendable {
    let modificationDate: Date
    let fileSize: Int

    init(modificationDate: Date, fileSize: Int) {
        self.modificationDate = modificationDate
        self.fileSize = fileSize
    }
}

/// Extracts Safari's official local `Bookmarks.plist` into private native
/// records. It never creates, updates, replaces, or deletes a file.
nonisolated struct DefaultSafariDataSource: SafariDataSource {
    private static let supportedStorageVersions = Set(["1"])

    private let bookmarksFileURL: URL
    private let fileExists: @Sendable (URL) async -> Bool
    private let isReadable: @Sendable (URL) async -> Bool
    private let readData: @Sendable (URL) async throws -> Data
    private let fingerprint: @Sendable (URL) async throws -> SafariStorageFingerprint
    private let safariVersion: @Sendable () -> String?
    private let startAccessing: @Sendable (URL) -> Bool
    private let stopAccessing: @Sendable (URL) -> Void

    init(
        bookmarksFileURL: URL,
        fileExists: @escaping @Sendable (URL) async -> Bool = {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        },
        isReadable: @escaping @Sendable (URL) async -> Bool = {
            FileManager.default.isReadableFile(atPath: $0.path(percentEncoded: false))
        },
        readData: @escaping @Sendable (URL) async throws -> Data = {
            try Data(contentsOf: $0)
        },
        fingerprint: @escaping @Sendable (URL) async throws -> SafariStorageFingerprint = {
            let values = try $0.resourceValues(forKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
            ])
            guard let modificationDate = values.contentModificationDate,
                  let fileSize = values.fileSize else {
                throw SafariReadError.snapshotInconsistent
            }
            return SafariStorageFingerprint(
                modificationDate: modificationDate,
                fileSize: fileSize
            )
        },
        safariVersion: @escaping @Sendable () -> String? = {
            Self.installedSafariVersion()
        },
        startAccessing: @escaping @Sendable (URL) -> Bool = {
            $0.startAccessingSecurityScopedResource()
        },
        stopAccessing: @escaping @Sendable (URL) -> Void = {
            $0.stopAccessingSecurityScopedResource()
        }
    ) {
        self.bookmarksFileURL = bookmarksFileURL
        self.fileExists = fileExists
        self.isReadable = isReadable
        self.readData = readData
        self.fingerprint = fingerprint
        self.safariVersion = safariVersion
        self.startAccessing = startAccessing
        self.stopAccessing = stopAccessing
    }

    func checkPermissions() async -> BSEAdapterPermissionStatus {
        guard isOfficialLocalSource else {
            return BSEAdapterPermissionStatus(
                state: .unavailable,
                detail: BSEAdapterPermissionDetail(code: .sourceUnavailable)
            )
        }

        let accessing = startAccessing(bookmarksFileURL)
        defer { if accessing { stopAccessing(bookmarksFileURL) } }

        guard await fileExists(bookmarksFileURL) else {
            return BSEAdapterPermissionStatus(
                state: .unavailable,
                detail: BSEAdapterPermissionDetail(code: .sourceUnavailable)
            )
        }
        guard await isReadable(bookmarksFileURL) else {
            return BSEAdapterPermissionStatus(
                state: .denied,
                detail: BSEAdapterPermissionDetail(code: .accessDenied)
            )
        }
        return BSEAdapterPermissionStatus(
            state: .granted,
            detail: BSEAdapterPermissionDetail(code: .authorized)
        )
    }

    func checkCompatibility() async -> BSEAdapterCompatibility {
        do {
            let version = try await readStorageVersion()
            let sourceVersion = version.map(BSEAdapterSourceVersion.init)
            guard let version else {
                return BSEAdapterCompatibility(
                    state: .untested,
                    detail: BSEAdapterCompatibilityDetail(
                        code: .versionNotValidated,
                        sourceVersion: sourceVersion
                    )
                )
            }
            guard Self.supportedStorageVersions.contains(version) else {
                return BSEAdapterCompatibility(
                    state: .unsupported,
                    detail: BSEAdapterCompatibilityDetail(
                        code: .versionOutsideSupportedRange,
                        sourceVersion: sourceVersion
                    )
                )
            }
            return BSEAdapterCompatibility(
                state: .supported,
                detail: BSEAdapterCompatibilityDetail(
                    code: .versionInSupportedRange,
                    sourceVersion: sourceVersion
                )
            )
        } catch {
            return BSEAdapterCompatibility(
                state: .unavailable,
                detail: BSEAdapterCompatibilityDetail(code: .sourceUnavailable)
            )
        }
    }

    func extract() async throws -> SafariExtraction {
        guard isOfficialLocalSource else {
            throw SafariReadError.storageUnavailable
        }

        let accessing = startAccessing(bookmarksFileURL)
        defer { if accessing { stopAccessing(bookmarksFileURL) } }

        guard await fileExists(bookmarksFileURL) else {
            throw SafariReadError.storageUnavailable
        }
        guard await isReadable(bookmarksFileURL) else {
            throw SafariReadError.permissionDenied
        }

        let before: SafariStorageFingerprint
        do {
            before = try await fingerprint(bookmarksFileURL)
        } catch let error as SafariReadError {
            throw error
        } catch {
            throw SafariReadError.snapshotInconsistent
        }

        let data: Data
        do {
            data = try await readData(bookmarksFileURL)
        } catch {
            throw SafariReadError.readFailure
        }

        let after: SafariStorageFingerprint
        do {
            after = try await fingerprint(bookmarksFileURL)
        } catch {
            throw SafariReadError.snapshotInconsistent
        }
        guard before == after else {
            throw SafariReadError.snapshotInconsistent
        }

        return try Self.decode(
            data,
            capturedAt: before.modificationDate,
            safariVersion: safariVersion()
        )
    }

    private func readStorageVersion() async throws -> String? {
        guard isOfficialLocalSource else {
            throw SafariReadError.storageUnavailable
        }
        let accessing = startAccessing(bookmarksFileURL)
        defer { if accessing { stopAccessing(bookmarksFileURL) } }
        guard await fileExists(bookmarksFileURL) else {
            throw SafariReadError.storageUnavailable
        }
        guard await isReadable(bookmarksFileURL) else {
            throw SafariReadError.permissionDenied
        }
        let data = try await readData(bookmarksFileURL)
        let root = try Self.propertyListRoot(from: data)
        return Self.storageVersion(in: root)
    }

    private var isOfficialLocalSource: Bool {
        guard bookmarksFileURL.isFileURL,
              bookmarksFileURL.lastPathComponent == "Bookmarks.plist" else {
            return false
        }
        let safariDirectory = bookmarksFileURL.deletingLastPathComponent()
        let libraryDirectory = safariDirectory.deletingLastPathComponent()
        return safariDirectory.lastPathComponent == "Safari"
            && libraryDirectory.lastPathComponent == "Library"
    }

    private static func decode(
        _ data: Data,
        capturedAt: Date,
        safariVersion: String?
    ) throws -> SafariExtraction {
        let root = try propertyListRoot(from: data)
        let version = storageVersion(in: root)
        guard let version, supportedStorageVersions.contains(version) else {
            throw SafariReadError.unsupportedStorageVersion(version)
        }

        var issues: [SafariReadIssue] = []
        let children: [Any]
        if let values = root["Children"] as? [Any] {
            children = values
        } else if root["Children"] == nil {
            children = []
        } else {
            throw SafariReadError.storageCorrupted
        }
        let records = decodeChildren(
            children,
            pathPrefix: [],
            issues: &issues
        )
        return SafariExtraction(
            records: records,
            capturedAt: capturedAt,
            safariVersion: safariVersion,
            storageVersion: version,
            issues: issues
        )
    }

    private static func propertyListRoot(from data: Data) throws -> [String: Any] {
        let propertyList: Any
        do {
            propertyList = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
        } catch {
            throw SafariReadError.storageCorrupted
        }
        guard let root = propertyList as? [String: Any],
              root["WebBookmarkType"] as? String == "WebBookmarkTypeList" else {
            throw SafariReadError.storageCorrupted
        }
        return root
    }

    private static func storageVersion(in root: [String: Any]) -> String? {
        if let version = root["WebBookmarkFileVersion"] as? Int {
            return String(version)
        }
        if let version = root["WebBookmarkFileVersion"] as? String {
            return version
        }
        return nil
    }

    private static func decodeRecord(
        _ value: Any,
        position: Int,
        path: SafariRecordPath,
        issues: inout [SafariReadIssue]
    ) -> SafariRecord? {
        guard let dictionary = value as? [String: Any] else {
            issues.append(.unsupportedNode(path: path))
            return nil
        }

        switch dictionary["WebBookmarkType"] as? String {
        case "WebBookmarkTypeLeaf":
            let title = (dictionary["URIDictionary"] as? [String: Any])?["title"] as? String
            return .bookmark(SafariBookmarkRecord(
                nativeIdentifier: dictionary["WebBookmarkUUID"] as? String,
                title: title,
                urlString: dictionary["URLString"] as? String,
                position: position,
                path: path
            ))
        case "WebBookmarkTypeList":
            let childValues: [Any]
            if let children = dictionary["Children"] as? [Any] {
                childValues = children
            } else if dictionary["Children"] == nil {
                childValues = []
            } else {
                issues.append(.unsupportedNode(path: path))
                childValues = []
            }
            let children = decodeChildren(
                childValues,
                pathPrefix: path.positions,
                issues: &issues
            )
            return .folder(SafariFolderRecord(
                nativeIdentifier: dictionary["WebBookmarkUUID"] as? String,
                permanentRootRole: path.positions.count == 1
                    ? permanentRootRole(
                        identifier:
                            dictionary["WebBookmarkIdentifier"] as? String,
                        title: dictionary["Title"] as? String
                    )
                    : nil,
                title: dictionary["Title"] as? String,
                position: position,
                path: path,
                children: children
            ))
        case .some, .none:
            issues.append(.unknownNodeType(path: path))
            return nil
        }
    }

    /// Raw indices remain in `path` for precise diagnostics, while positions
    /// are compacted over accepted records so the universal tree never exposes
    /// insertion gaps caused by unsupported browser-specific entries.
    private static func decodeChildren(
        _ values: [Any],
        pathPrefix: [Int],
        issues: inout [SafariReadIssue]
    ) -> [SafariRecord] {
        var records: [SafariRecord] = []
        records.reserveCapacity(values.count)
        for (rawPosition, value) in values.enumerated() {
            guard let record = decodeRecord(
                value,
                position: records.count,
                path: SafariRecordPath(pathPrefix + [rawPosition]),
                issues: &issues
            ) else {
                continue
            }
            records.append(record)
        }
        return records
    }

    private static func permanentRootRole(
        identifier: String?,
        title: String?
    ) -> PermanentRootRole? {
        let marker = identifier ?? title
        return switch marker {
        case "BookmarksBar":
            .primaryBookmarks
        case "BookmarksMenu":
            .secondaryBookmarks
        case "com.apple.ReadingList":
            .readingList
        default:
            nil
        }
    }

    private static func installedSafariVersion() -> String? {
        let candidates = [
            URL(fileURLWithPath: "/Applications/Safari.app"),
            URL(fileURLWithPath: "/System/Applications/Safari.app"),
        ]
        for candidate in candidates {
            if let version = Bundle(url: candidate)?
                .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                return version
            }
        }
        return nil
    }
}
