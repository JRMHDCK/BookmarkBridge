//
//  DiagnosticReport.swift
//  BookmarkBridge
//

import Foundation

/// A short, non-identifying value used only for application and system versions.
/// Arbitrary text is rejected so paths and user content cannot be smuggled into
/// a diagnostic report through a nominally safe field.
nonisolated struct DiagnosticVersionValue: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    static let unknown = DiagnosticVersionValue(knownSafeValue: "unknown")

    init?(rawValue: String) {
        guard Self.isAllowed(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    init?(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let validated = Self(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid diagnostic version value"
            )
        }
        self = validated
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private init(knownSafeValue: String) {
        rawValue = knownSafeValue
    }

    private static func isAllowed(_ value: String) -> Bool {
        guard (1...64).contains(value.utf8.count) else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 45, 46, 43, 48...57, 65...90, 95, 97...122:
                true
            default:
                false
            }
        }
    }
}

/// Public correlation identifier safe to include in an e-mail subject.
nonisolated struct DiagnosticReportID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init?(rawValue: String) {
        let scalars = Array(rawValue.unicodeScalars)
        guard scalars.count == 9,
              scalars[0].value == 66,
              scalars[1].value == 66,
              scalars[2].value == 45,
              scalars[3...8].allSatisfy(Self.isUppercaseHexDigit)
        else {
            return nil
        }
        self.rawValue = rawValue
    }

    init?(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let validated = Self(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid diagnostic report identifier"
            )
        }
        self = validated
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func isUppercaseHexDigit(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 48...57, 65...70:
            true
        default:
            false
        }
    }
}

nonisolated enum DiagnosticReportOrigin: String, Hashable, Codable, Sendable {
    case contextualError
    case helpCenter
}

nonisolated enum DiagnosticJournalStatus: String, Hashable, Codable, Sendable {
    case available
    case unavailable
    case corrupted
    case unsupportedVersion
}

nonisolated enum DiagnosticSynchronizationDirection: String, Hashable, Codable, Sendable {
    case safariToChrome
    case chromeToSafari
}

nonisolated enum DiagnosticStage: String, Hashable, Codable, Sendable {
    case authorization
    case sourceRead
    case targetRead
    case matching
    case projection
    case diff
    case planning
    case preview
    case browserClosure
    case backup
    case writing
    case importPreparation
    case validation
    case restoration
    case unknown
}

nonisolated enum DiagnosticErrorType: String, Hashable, Codable, Sendable {
    case authorization
    case reading
    case decoding
    case planning
    case synchronization
    case backup
    case writing
    case validation
    case restoration
    case unsupportedOperation
    case unknown
}

/// Stable error codes. Free-form error descriptions are deliberately absent.
nonisolated enum DiagnosticErrorCode: String, Hashable, Codable, Sendable {
    case sourceNotFound
    case accessDenied
    case authorizationRequired
    case decodingFailed
    case unsupportedBrowser
    case multipleBookmarkStores
    case readOnlyDestination
    case browserStillRunning
    case securityScopeDenied
    case backupFailed
    case transactionFailed
    case validationFailed
    case restorationFailed
    case previewFailed
    case unknown
}

nonisolated enum DiagnosticAuthorizationState: String, Hashable, Codable, Sendable {
    case granted
    case denied
    case notDetermined
    case unavailable
    case invalid
}

/// Non-identifying source categories used instead of profile names and paths.
nonisolated enum DiagnosticSourceCategory: String, Hashable, Codable, Sendable {
    case safariBookmarks
    case chromeLocal
    case chromeAccount
}

nonisolated enum DiagnosticEventLevel: String, Hashable, Codable, Sendable {
    case information
    case warning
    case error
}

nonisolated enum DiagnosticEventOutcome: String, Hashable, Codable, Sendable {
    case started
    case succeeded
    case failed
    case cancelled
}

nonisolated enum DiagnosticComponent: String, Hashable, Codable, Sendable {
    case application
    case authorization
    case safariReader
    case chromeReader
    case synchronization
    case backup
    case writer
    case restoration
}

/// Privacy-safe identity and content evidence for the selected Safari file.
/// The absolute path is deliberately represented as a category so reports can
/// distinguish the standard library from an alternate target without exposing
/// an account name.
nonisolated enum DiagnosticSafariFileLocation: String, Hashable, Codable, Sendable {
    case canonicalBookmarks
    case alternateBookmarks
}

nonisolated struct DiagnosticFileEvidence: Hashable, Codable, Sendable {
    let location: DiagnosticSafariFileLocation
    let fileSize: UInt64
    let modificationDate: Date
    let sha256: Data
    let fileSystemNumber: UInt64
    let inode: UInt64

    init(
        location: DiagnosticSafariFileLocation,
        fileSize: UInt64,
        modificationDate: Date,
        sha256: Data,
        fileSystemNumber: UInt64,
        inode: UInt64
    ) {
        self.location = location
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.sha256 = sha256
        self.fileSystemNumber = fileSystemNumber
        self.inode = inode
    }
}

/// Aggregate-only metrics. They contain no bookmark content or identifiers.
nonisolated struct DiagnosticCounts: Hashable, Codable, Sendable {
    let bookmarks: Int?
    let folders: Int?
    let matches: Int?
    let changes: Int?

    init(
        bookmarks: Int? = nil,
        folders: Int? = nil,
        matches: Int? = nil,
        changes: Int? = nil
    ) {
        self.bookmarks = bookmarks.map { max(0, $0) }
        self.folders = folders.map { max(0, $0) }
        self.matches = matches.map { max(0, $0) }
        self.changes = changes.map { max(0, $0) }
    }

    private enum CodingKeys: String, CodingKey {
        case bookmarks
        case folders
        case matches
        case changes
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            bookmarks: try container.decodeIfPresent(Int.self, forKey: .bookmarks),
            folders: try container.decodeIfPresent(Int.self, forKey: .folders),
            matches: try container.decodeIfPresent(Int.self, forKey: .matches),
            changes: try container.decodeIfPresent(Int.self, forKey: .changes)
        )
    }
}

nonisolated struct DiagnosticApplicationInfo: Hashable, Codable, Sendable {
    let version: DiagnosticVersionValue
    let build: DiagnosticVersionValue

    init(version: DiagnosticVersionValue, build: DiagnosticVersionValue) {
        self.version = version
        self.build = build
    }
}

nonisolated enum DiagnosticMachineArchitecture: String, Hashable, Codable, Sendable {
    case arm64
    case x86_64
    case unknown
}

nonisolated struct DiagnosticSystemInfo: Hashable, Codable, Sendable {
    let macOSVersion: DiagnosticVersionValue
    let architecture: DiagnosticMachineArchitecture

    init(
        macOSVersion: DiagnosticVersionValue,
        architecture: DiagnosticMachineArchitecture
    ) {
        self.macOSVersion = macOSVersion
        self.architecture = architecture
    }
}

nonisolated struct DiagnosticContext: Hashable, Codable, Sendable {
    let direction: DiagnosticSynchronizationDirection?
    let stage: DiagnosticStage
    let errorType: DiagnosticErrorType?
    let errorCode: DiagnosticErrorCode?
    let durationMilliseconds: UInt64?
    let counts: DiagnosticCounts
    let safariAuthorization: DiagnosticAuthorizationState
    let chromeAuthorization: DiagnosticAuthorizationState

    init(
        direction: DiagnosticSynchronizationDirection? = nil,
        stage: DiagnosticStage = .unknown,
        errorType: DiagnosticErrorType? = nil,
        errorCode: DiagnosticErrorCode? = nil,
        durationMilliseconds: UInt64? = nil,
        counts: DiagnosticCounts = DiagnosticCounts(),
        safariAuthorization: DiagnosticAuthorizationState = .notDetermined,
        chromeAuthorization: DiagnosticAuthorizationState = .notDetermined
    ) {
        self.direction = direction
        self.stage = stage
        self.errorType = errorType
        self.errorCode = errorCode
        self.durationMilliseconds = durationMilliseconds
        self.counts = counts
        self.safariAuthorization = safariAuthorization
        self.chromeAuthorization = chromeAuthorization
    }
}

/// One allow-listed diagnostic event. It cannot carry arbitrary messages,
/// bookmark data, profile names, usernames, or paths.
nonisolated struct DiagnosticEvent: Hashable, Codable, Sendable {
    let timestamp: Date
    let level: DiagnosticEventLevel
    let component: DiagnosticComponent
    let stage: DiagnosticStage
    let outcome: DiagnosticEventOutcome
    let direction: DiagnosticSynchronizationDirection?
    let source: DiagnosticSourceCategory?
    let errorType: DiagnosticErrorType?
    let errorCode: DiagnosticErrorCode?
    let durationMilliseconds: UInt64?
    let counts: DiagnosticCounts
    let fileEvidence: DiagnosticFileEvidence?

    init(
        timestamp: Date,
        level: DiagnosticEventLevel,
        component: DiagnosticComponent,
        stage: DiagnosticStage,
        outcome: DiagnosticEventOutcome,
        direction: DiagnosticSynchronizationDirection? = nil,
        source: DiagnosticSourceCategory? = nil,
        errorType: DiagnosticErrorType? = nil,
        errorCode: DiagnosticErrorCode? = nil,
        durationMilliseconds: UInt64? = nil,
        counts: DiagnosticCounts = DiagnosticCounts(),
        fileEvidence: DiagnosticFileEvidence? = nil
    ) {
        self.timestamp = timestamp
        self.level = level
        self.component = component
        self.stage = stage
        self.outcome = outcome
        self.direction = direction
        self.source = source
        self.errorType = errorType
        self.errorCode = errorCode
        self.durationMilliseconds = durationMilliseconds
        self.counts = counts
        self.fileEvidence = fileEvidence
    }
}

/// Privacy-safe diagnostic payload. User-authored descriptions belong in the
/// e-mail draft and are never inserted automatically into this model.
nonisolated struct DiagnosticReport: Hashable, Codable, Sendable {
    let id: DiagnosticReportID
    let createdAt: Date
    let origin: DiagnosticReportOrigin
    let application: DiagnosticApplicationInfo
    let system: DiagnosticSystemInfo
    let context: DiagnosticContext
    let journalStatus: DiagnosticJournalStatus
    let events: [DiagnosticEvent]

    init(
        id: DiagnosticReportID,
        createdAt: Date,
        origin: DiagnosticReportOrigin,
        application: DiagnosticApplicationInfo,
        system: DiagnosticSystemInfo,
        context: DiagnosticContext,
        journalStatus: DiagnosticJournalStatus = .available,
        events: [DiagnosticEvent]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.origin = origin
        self.application = application
        self.system = system
        self.context = context
        self.journalStatus = journalStatus
        self.events = events
    }
}

/// Generated report plus the private local text file prepared for sharing.
nonisolated struct DiagnosticReportArtifact: Hashable, Sendable {
    let report: DiagnosticReport
    let text: String
    let fileURL: URL

    init(report: DiagnosticReport, text: String, fileURL: URL) {
        self.report = report
        self.text = text
        self.fileURL = fileURL
    }
}
