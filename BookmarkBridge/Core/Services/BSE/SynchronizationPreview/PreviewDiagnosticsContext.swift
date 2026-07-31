//
//  PreviewDiagnosticsContext.swift
//  BookmarkBridge
//

#if DEBUG
import Foundation

/// Correlates every Debug log emitted while one real preview attempt runs.
/// Task-local propagation keeps concurrent or replaced attempts distinguishable
/// without adding diagnostic state to production requests.
nonisolated enum PreviewDiagnosticsContext {
    @TaskLocal static var attemptID = "UNTRACKED"

    static var prefix: String {
        "[Preview \(attemptID)]"
    }

    static func errorDescription(_ error: any Error) -> String {
        let nsError = error as NSError
        return [
            "dynamicType=\(String(reflecting: type(of: error)))",
            "reflected=\(String(reflecting: error))",
            "domain=\(nsError.domain)",
            "code=\(nsError.code)",
            "userInfo=\(String(reflecting: nsError.userInfo))",
        ].joined(separator: " ")
    }
}
#endif
