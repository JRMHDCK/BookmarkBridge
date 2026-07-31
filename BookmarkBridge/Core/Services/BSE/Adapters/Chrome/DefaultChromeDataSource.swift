//
//  DefaultChromeDataSource.swift
//  BookmarkBridge
//

import Foundation

/// File attributes checked before and after one profile read.
nonisolated struct ChromeStorageFingerprint: Hashable, Sendable {
    let modificationDate: Date
    let fileSize: Int
}

/// Extracts one official local Chrome `Bookmarks` file into private records.
/// It never creates, updates, replaces, or deletes a file and never starts Chrome.
nonisolated struct DefaultChromeDataSource: ChromeDataSource {
    private static let validatedStorageVersions = Set(["1"])

    let profileIdentifier: ChromeProfileIdentifier

    private let bookmarksFileURL: URL
    private let securityScopeURL: URL
    private let fileExists: @Sendable (URL) async -> Bool
    private let isReadable: @Sendable (URL) async -> Bool
    private let readData: @Sendable (URL) async throws -> Data
    private let fingerprint: @Sendable (URL) async throws -> ChromeStorageFingerprint
    private let chromeVersion: @Sendable () -> String?
    private let startAccessing: @Sendable (URL) -> Bool
    private let stopAccessing: @Sendable (URL) -> Void

    init(
        bookmarksFileURL: URL,
        profileIdentifier: ChromeProfileIdentifier,
        securityScopeURL: URL? = nil,
        fileExists: @escaping @Sendable (URL) async -> Bool = {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        },
        isReadable: @escaping @Sendable (URL) async -> Bool = {
            FileManager.default.isReadableFile(atPath: $0.path(percentEncoded: false))
        },
        readData: @escaping @Sendable (URL) async throws -> Data = {
            try Data(contentsOf: $0)
        },
        fingerprint: @escaping @Sendable (URL) async throws -> ChromeStorageFingerprint = {
            let values = try $0.resourceValues(forKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
            ])
            guard let modificationDate = values.contentModificationDate,
                  let fileSize = values.fileSize else {
                throw ChromeReadError.snapshotInconsistent
            }
            return ChromeStorageFingerprint(
                modificationDate: modificationDate,
                fileSize: fileSize
            )
        },
        chromeVersion: @escaping @Sendable () -> String? = {
            Self.installedChromeVersion()
        },
        startAccessing: @escaping @Sendable (URL) -> Bool = {
            $0.startAccessingSecurityScopedResource()
        },
        stopAccessing: @escaping @Sendable (URL) -> Void = {
            $0.stopAccessingSecurityScopedResource()
        }
    ) {
        self.bookmarksFileURL = bookmarksFileURL
        self.securityScopeURL = securityScopeURL ?? bookmarksFileURL
        self.profileIdentifier = profileIdentifier
        self.fileExists = fileExists
        self.isReadable = isReadable
        self.readData = readData
        self.fingerprint = fingerprint
        self.chromeVersion = chromeVersion
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

        let accessing = startAccessing(securityScopeURL)
        defer { if accessing { stopAccessing(securityScopeURL) } }

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
            guard let version,
                  Self.validatedStorageVersions.contains(version) else {
                return BSEAdapterCompatibility(
                    state: .untested,
                    detail: BSEAdapterCompatibilityDetail(
                        code: .versionNotValidated,
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

    func extract() async throws -> ChromeExtraction {
        guard isOfficialLocalSource else {
            throw ChromeReadError.storageUnavailable
        }

        let accessing = startAccessing(securityScopeURL)
        defer { if accessing { stopAccessing(securityScopeURL) } }

        guard await fileExists(bookmarksFileURL) else {
            throw ChromeReadError.storageUnavailable
        }
        guard await isReadable(bookmarksFileURL) else {
            throw ChromeReadError.permissionDenied
        }

        let before: ChromeStorageFingerprint
        do {
            before = try await fingerprint(bookmarksFileURL)
        } catch let error as ChromeReadError {
            throw error
        } catch {
            throw ChromeReadError.snapshotInconsistent
        }

        let data: Data
        do {
            data = try await readData(bookmarksFileURL)
        } catch {
            throw ChromeReadError.readFailure
        }

        let after: ChromeStorageFingerprint
        do {
            after = try await fingerprint(bookmarksFileURL)
        } catch {
            throw ChromeReadError.snapshotInconsistent
        }
        guard before == after else {
            throw ChromeReadError.snapshotInconsistent
        }

        return try Self.decode(
            data,
            capturedAt: before.modificationDate,
            chromeVersion: chromeVersion(),
            profileIdentifier: profileIdentifier
        )
    }

    private func readStorageVersion() async throws -> String? {
        guard isOfficialLocalSource else {
            throw ChromeReadError.storageUnavailable
        }
        let accessing = startAccessing(securityScopeURL)
        defer { if accessing { stopAccessing(securityScopeURL) } }
        guard await fileExists(bookmarksFileURL) else {
            throw ChromeReadError.storageUnavailable
        }
        guard await isReadable(bookmarksFileURL) else {
            throw ChromeReadError.permissionDenied
        }
        let data = try await readData(bookmarksFileURL)
        return Self.storageVersion(in: try Self.jsonRoot(from: data))
    }

    private var isOfficialLocalSource: Bool {
        guard bookmarksFileURL.isFileURL,
              bookmarksFileURL.lastPathComponent == "Bookmarks" else {
            return false
        }
        let profileDirectory = bookmarksFileURL.deletingLastPathComponent()
        let chromeDirectory = profileDirectory.deletingLastPathComponent()
        let googleDirectory = chromeDirectory.deletingLastPathComponent()
        let applicationSupportDirectory = googleDirectory.deletingLastPathComponent()
        return profileDirectory.lastPathComponent == profileIdentifier.rawValue
            && chromeDirectory.lastPathComponent == "Chrome"
            && googleDirectory.lastPathComponent == "Google"
            && applicationSupportDirectory.lastPathComponent == "Application Support"
    }

    private static func decode(
        _ data: Data,
        capturedAt: Date,
        chromeVersion: String?,
        profileIdentifier: ChromeProfileIdentifier
    ) throws -> ChromeExtraction {
        let root = try jsonRoot(from: data)
        guard let roots = root["roots"] as? [String: Any] else {
            throw ChromeReadError.storageCorrupted
        }

        var issues: [ChromeReadIssue] = []
        let rootDefinitions: [(key: String, kind: ChromeRootKind)] = [
            ("bookmark_bar", .bookmarksBar),
            ("other", .otherBookmarks),
            ("synced", .mobileBookmarks),
        ]
        var records: [ChromeRecord] = []
        for (position, definition) in rootDefinitions.enumerated() {
            guard let value = roots[definition.key] else { continue }
            guard let record = decodeRecord(
                value,
                position: position,
                path: ChromeRecordPath(root: definition.kind),
                issues: &issues
            ) else { continue }
            records.append(record)
        }

        return ChromeExtraction(
            records: records,
            capturedAt: capturedAt,
            chromeVersion: chromeVersion,
            storageVersion: storageVersion(in: root),
            profileIdentifier: profileIdentifier,
            issues: issues
        )
    }

    private static func jsonRoot(from data: Data) throws -> [String: Any] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ChromeReadError.storageCorrupted
        }
        guard let root = object as? [String: Any] else {
            throw ChromeReadError.storageCorrupted
        }
        return root
    }

    private static func storageVersion(in root: [String: Any]) -> String? {
        if let version = root["version"] as? Int {
            return String(version)
        }
        if let version = root["version"] as? String {
            return version
        }
        return nil
    }

    private static func decodeRecord(
        _ value: Any,
        position: Int,
        path: ChromeRecordPath,
        issues: inout [ChromeReadIssue]
    ) -> ChromeRecord? {
        guard let dictionary = value as? [String: Any] else {
            issues.append(.unsupportedNode(path: path))
            return nil
        }

        let chromeID = dictionary["id"] as? String
        let chromeGUID = dictionary["guid"] as? String
        switch dictionary["type"] as? String {
        case "url":
            return .bookmark(ChromeBookmarkRecord(
                chromeID: chromeID,
                chromeGUID: chromeGUID,
                title: dictionary["name"] as? String,
                urlString: dictionary["url"] as? String,
                position: position,
                path: path
            ))
        case "folder":
            let childValues: [Any]
            if let children = dictionary["children"] as? [Any] {
                childValues = children
            } else if dictionary["children"] == nil {
                childValues = []
            } else {
                issues.append(.unsupportedNode(path: path))
                childValues = []
            }
            let children = decodeChildren(
                childValues,
                root: path.root,
                pathPrefix: path.positions,
                issues: &issues
            )
            return .folder(ChromeFolderRecord(
                chromeID: chromeID,
                chromeGUID: chromeGUID,
                title: dictionary["name"] as? String,
                position: position,
                path: path,
                children: children
            ))
        case .some, .none:
            issues.append(.unknownNodeType(path: path))
            return nil
        }
    }

    /// Keep the raw JSON index in the diagnostic path, but expose contiguous
    /// logical positions after unsupported Chrome-specific entries are skipped.
    private static func decodeChildren(
        _ values: [Any],
        root: ChromeRootKind,
        pathPrefix: [Int],
        issues: inout [ChromeReadIssue]
    ) -> [ChromeRecord] {
        var records: [ChromeRecord] = []
        records.reserveCapacity(values.count)
        for (rawPosition, value) in values.enumerated() {
            guard let record = decodeRecord(
                value,
                position: records.count,
                path: ChromeRecordPath(
                    root: root,
                    positions: pathPrefix + [rawPosition]
                ),
                issues: &issues
            ) else {
                continue
            }
            records.append(record)
        }
        return records
    }

    private static func installedChromeVersion() -> String? {
        let candidates = [
            URL(fileURLWithPath: "/Applications/Google Chrome.app"),
            FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Applications/Google Chrome.app"),
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
