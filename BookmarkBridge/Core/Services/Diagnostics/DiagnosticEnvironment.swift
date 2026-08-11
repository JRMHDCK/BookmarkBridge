//
//  DiagnosticEnvironment.swift
//  BookmarkBridge
//

import Foundation

/// Reads only allow-listed application and operating-system metadata.
nonisolated enum DiagnosticEnvironment {
    static func applicationInfo(
        bundle: Bundle = .main
    ) -> DiagnosticApplicationInfo {
        let version = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        let build = bundle.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String
        let safeVersion: DiagnosticVersionValue
        if let version, let validated = DiagnosticVersionValue(version) {
            safeVersion = validated
        } else {
            safeVersion = .unknown
        }
        let safeBuild: DiagnosticVersionValue
        if let build, let validated = DiagnosticVersionValue(build) {
            safeBuild = validated
        } else {
            safeBuild = .unknown
        }
        return DiagnosticApplicationInfo(
            version: safeVersion,
            build: safeBuild
        )
    }

    static func systemInfo(
        processInfo: ProcessInfo = .processInfo
    ) -> DiagnosticSystemInfo {
        let version = processInfo.operatingSystemVersion
        let value = [
            version.majorVersion,
            version.minorVersion,
            version.patchVersion,
        ].map(String.init).joined(separator: ".")
        return DiagnosticSystemInfo(
            macOSVersion: DiagnosticVersionValue(value) ?? .unknown,
            architecture: architecture
        )
    }

    private static var architecture: DiagnosticMachineArchitecture {
        #if arch(arm64)
        .arm64
        #elseif arch(x86_64)
        .x86_64
        #else
        .unknown
        #endif
    }
}
