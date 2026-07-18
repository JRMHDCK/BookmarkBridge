//
//  BSEAdapterStatus.swift
//  BookmarkBridge
//

/// Stable permission states that callers can branch on without parsing text.
nonisolated enum BSEAdapterPermissionState: String, Hashable, Codable, Sendable {
    case granted
    case denied
    case notDetermined
    case unavailable
}

/// Generic reason accompanying a permission observation.
nonisolated enum BSEAdapterPermissionDetailCode: String, Hashable, Codable, Sendable {
    case authorized
    case accessDenied
    case authorizationRequired
    case sourceUnavailable
}

/// Optional diagnostic context; `code` remains the machine-readable value.
nonisolated struct BSEAdapterPermissionDetail: Hashable, Codable, Sendable {
    let code: BSEAdapterPermissionDetailCode
    let explanation: String?

    init(code: BSEAdapterPermissionDetailCode, explanation: String? = nil) {
        self.code = code
        self.explanation = explanation
    }
}

/// Current permission observation. Checking it must never request permission.
nonisolated struct BSEAdapterPermissionStatus: Hashable, Codable, Sendable {
    let state: BSEAdapterPermissionState
    let detail: BSEAdapterPermissionDetail?

    init(state: BSEAdapterPermissionState, detail: BSEAdapterPermissionDetail? = nil) {
        self.state = state
        self.detail = detail
    }
}

/// Opaque version value reported by any kind of bookmark source.
nonisolated struct BSEAdapterSourceVersion: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    var description: String { rawValue }
}

/// Stable compatibility states independent of any concrete browser.
nonisolated enum BSEAdapterCompatibilityState: String, Hashable, Codable, Sendable {
    case supported
    case unsupported
    case untested
    case unavailable
}

/// Generic reason accompanying a compatibility observation.
nonisolated enum BSEAdapterCompatibilityDetailCode: String, Hashable, Codable, Sendable {
    case versionInSupportedRange
    case versionOutsideSupportedRange
    case versionNotValidated
    case sourceUnavailable
}

/// Structured compatibility evidence retained for diagnostics and reporting.
nonisolated struct BSEAdapterCompatibilityDetail: Hashable, Codable, Sendable {
    let code: BSEAdapterCompatibilityDetailCode
    let sourceVersion: BSEAdapterSourceVersion?
    let explanation: String?

    init(
        code: BSEAdapterCompatibilityDetailCode,
        sourceVersion: BSEAdapterSourceVersion? = nil,
        explanation: String? = nil
    ) {
        self.code = code
        self.sourceVersion = sourceVersion
        self.explanation = explanation
    }
}

/// Current source-version compatibility observation.
nonisolated struct BSEAdapterCompatibility: Hashable, Codable, Sendable {
    let state: BSEAdapterCompatibilityState
    let detail: BSEAdapterCompatibilityDetail?

    init(state: BSEAdapterCompatibilityState, detail: BSEAdapterCompatibilityDetail? = nil) {
        self.state = state
        self.detail = detail
    }
}
