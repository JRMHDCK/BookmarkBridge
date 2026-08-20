//
//  DiagnosticReportTextRenderer.swift
//  BookmarkBridge
//

import Foundation

nonisolated protocol DiagnosticReportTextRendering: Sendable {
    func render(_ report: DiagnosticReport) -> String
}

/// Stable line-oriented text intended for both humans and support tooling.
nonisolated struct DiagnosticReportTextRenderer:
    DiagnosticReportTextRendering
{
    func render(_ report: DiagnosticReport) -> String {
        let context = report.context
        var lines = [
            "BOOKMARKBRIDGE DIAGNOSTIC REPORT",
            "report_id=\(report.id.rawValue)",
            "created_at=\(dateString(report.createdAt))",
            "origin=\(report.origin.rawValue)",
            "app_version=\(report.application.version.rawValue)",
            "app_build=\(report.application.build.rawValue)",
            "macos_version=\(report.system.macOSVersion.rawValue)",
            "architecture=\(report.system.architecture.rawValue)",
            "direction=\(value(context.direction))",
            "stage=\(context.stage.rawValue)",
            "error_type=\(value(context.errorType))",
            "error_code=\(value(context.errorCode))",
            "duration_ms=\(value(context.durationMilliseconds))",
            "bookmarks=\(value(context.counts.bookmarks))",
            "folders=\(value(context.counts.folders))",
            "matches=\(value(context.counts.matches))",
            "changes=\(value(context.counts.changes))",
            "safari_authorization=\(context.safariAuthorization.rawValue)",
            "chrome_authorization=\(context.chromeAuthorization.rawValue)",
            "journal_status=\(report.journalStatus.rawValue)",
            "events_count=\(report.events.count)",
            "",
            "RECENT EVENTS",
        ]
        lines.append(contentsOf: report.events.map(eventLine))
        return lines.joined(separator: "\n") + "\n"
    }

    private func eventLine(_ event: DiagnosticEvent) -> String {
        [
            "timestamp=\(dateString(event.timestamp))",
            "level=\(event.level.rawValue)",
            "component=\(event.component.rawValue)",
            "stage=\(event.stage.rawValue)",
            "outcome=\(event.outcome.rawValue)",
            "direction=\(value(event.direction))",
            "source=\(value(event.source))",
            "error_type=\(value(event.errorType))",
            "error_code=\(value(event.errorCode))",
            "duration_ms=\(value(event.durationMilliseconds))",
            "bookmarks=\(value(event.counts.bookmarks))",
            "folders=\(value(event.counts.folders))",
            "matches=\(value(event.counts.matches))",
            "changes=\(value(event.counts.changes))",
            "safari_file_location=\(value(event.fileEvidence?.location))",
            "safari_file_size=\(value(event.fileEvidence?.fileSize))",
            "safari_file_modified_at=\(dateValue(event.fileEvidence?.modificationDate))",
            "safari_file_sha256=\(digestValue(event.fileEvidence?.sha256))",
            "safari_file_system=\(value(event.fileEvidence?.fileSystemNumber))",
            "safari_file_inode=\(value(event.fileEvidence?.inode))",
        ].joined(separator: " | ")
    }

    private func dateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private func value<Value: RawRepresentable>(_ value: Value?) -> String
    where Value.RawValue == String {
        value?.rawValue ?? "not-available"
    }

    private func value<Value: BinaryInteger>(_ value: Value?) -> String {
        guard let value else { return "not-available" }
        return String(value)
    }

    private func dateValue(_ value: Date?) -> String {
        value.map(dateString) ?? "not-available"
    }

    private func digestValue(_ value: Data?) -> String {
        guard let value else { return "not-available" }
        return value.map { String(format: "%02x", $0) }.joined()
    }
}
