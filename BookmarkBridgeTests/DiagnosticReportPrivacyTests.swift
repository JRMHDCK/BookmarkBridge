//
//  DiagnosticReportPrivacyTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Diagnostic report privacy contract")
struct DiagnosticReportPrivacyTests {
    @Test("Accepts only short version-safe values")
    func versionValuesRejectUntrustedText() {
        #expect(DiagnosticVersionValue("0.9.2-beta")?.rawValue == "0.9.2-beta")
        #expect(DiagnosticVersionValue("26.5.1")?.rawValue == "26.5.1")
        #expect(DiagnosticVersionValue("/Users/jerome/Library/Safari") == nil)
        #expect(DiagnosticVersionValue("https://private.example/favorite") == nil)
        #expect(DiagnosticVersionValue("Titre personnel") == nil)
        #expect(DiagnosticVersionValue(String(repeating: "A", count: 65)) == nil)
    }

    @Test("Accepts only public BB identifiers")
    func reportIDValidation() {
        #expect(DiagnosticReportID("BB-A73F29")?.rawValue == "BB-A73F29")
        #expect(DiagnosticReportID("bb-a73f29") == nil)
        #expect(DiagnosticReportID("BB-/Users/jerome") == nil)
        #expect(DiagnosticReportID("BB-PRIVATE-TITLE") == nil)
    }

    @Test("Rejects unsafe values while decoding persisted data")
    func decodingCannotBypassValidation() {
        let unsafeVersion = Data(
            #""/Users/jerome/Library/Safari""#.utf8
        )
        let unsafeIdentifier = Data(#""BB-/USER""#.utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                DiagnosticVersionValue.self,
                from: unsafeVersion
            )
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                DiagnosticReportID.self,
                from: unsafeIdentifier
            )
        }
    }

    @Test("Serializes only allow-listed technical fields")
    func encodedReportContainsNoPersonalData() throws {
        let report = try makeReport()
        let data = try JSONEncoder().encode(report)
        let encoded = try #require(String(data: data, encoding: .utf8))

        let forbiddenValues = [
            "https://private.example/favorite",
            "Titre favori privé",
            "Dossier personnel",
            "BRICKS PRO",
            "jerome",
            "/Users/jerome/Library/Safari/Bookmarks.plist",
            "security-scoped-bookmark-secret",
        ]
        for value in forbiddenValues {
            #expect(!encoded.localizedCaseInsensitiveContains(value))
        }

        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(Set(object.keys) == [
            "application", "context", "createdAt", "events", "id", "origin",
            "journalStatus", "system",
        ])
    }

    @Test("Uses typed categories instead of profile names and paths")
    func eventUsesNonIdentifyingSourceCategory() throws {
        let report = try makeReport()
        let event = try #require(report.events.first)

        #expect(event.source == .chromeAccount)
        #expect(event.component == .chromeReader)
        #expect(event.errorCode == .accessDenied)
    }

    @Test("Normalizes invalid aggregate counts without bookmark content")
    func aggregateCountsAreNonNegative() {
        let counts = DiagnosticCounts(
            bookmarks: -4,
            folders: 2,
            matches: -1,
            changes: 3
        )

        #expect(counts.bookmarks == 0)
        #expect(counts.folders == 2)
        #expect(counts.matches == 0)
        #expect(counts.changes == 3)
    }

    @Test("Round trip preserves the privacy-safe report")
    func codableRoundTrip() throws {
        let report = try makeReport()
        let encoded = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(
            DiagnosticReport.self,
            from: encoded
        )

        #expect(decoded == report)
    }

    private func makeReport() throws -> DiagnosticReport {
        let identifier = try #require(DiagnosticReportID("BB-A73F29"))
        let appVersion = try #require(DiagnosticVersionValue("0.9.2"))
        let build = try #require(DiagnosticVersionValue("1"))
        let systemVersion = try #require(DiagnosticVersionValue("26.5.1"))
        let timestamp = Date(timeIntervalSince1970: 1_786_460_252)
        let counts = DiagnosticCounts(
            bookmarks: 120,
            folders: 18,
            matches: 95,
            changes: 7
        )
        let event = DiagnosticEvent(
            timestamp: timestamp,
            level: .error,
            component: .chromeReader,
            stage: .sourceRead,
            outcome: .failed,
            direction: .chromeToSafari,
            source: .chromeAccount,
            errorType: .authorization,
            errorCode: .accessDenied,
            durationMilliseconds: 184,
            counts: counts
        )

        return DiagnosticReport(
            id: identifier,
            createdAt: timestamp,
            origin: .contextualError,
            application: DiagnosticApplicationInfo(
                version: appVersion,
                build: build
            ),
            system: DiagnosticSystemInfo(
                macOSVersion: systemVersion,
                architecture: .arm64
            ),
            context: DiagnosticContext(
                direction: .chromeToSafari,
                stage: .sourceRead,
                errorType: .authorization,
                errorCode: .accessDenied,
                durationMilliseconds: 184,
                counts: counts,
                safariAuthorization: .granted,
                chromeAuthorization: .denied
            ),
            events: [event]
        )
    }
}
