//
//  SafariAccessValidationView.swift
//  BookmarkBridge
//
//  Temporary, diagnostic-only harness for the manual end-to-end validation of
//  the real Safari access chain (NSOpenPanel + real ~/Library/Safari/Bookmarks
//  .plist). It is shown only when the app is launched with the argument
//  `--validate-safari-access`; it is NOT the definitive app wiring.
//
//  It performs read-only access only: authorize (create + persist a read-only
//  security-scoped bookmark), then read/decode via the persisted bookmark. It
//  never writes to Safari, syncs, diffs, or backs up.
//

#if os(macOS)
import SwiftUI

/// Assembles the real access chain and runs it. A fresh store is created per
/// operation, so "read via persisted bookmark" genuinely re-reads from disk —
/// exactly what a real app relaunch would do.
@MainActor
struct SafariAccessValidator {

    func authorize() async throws {
        let store = try ApplicationSupportBookmarkStore.inApplicationSupport()
        let coordinator = SafariAccessCoordinator(
            authorizer: OpenPanelSafariAccessAuthorizer(),
            creator: SystemSecurityScopedBookmarkCreator(),
            store: store
        )
        _ = try await coordinator.authorize()
    }

    func validate() async throws -> SafariAccessValidationReport {
        let store = try ApplicationSupportBookmarkStore.inApplicationSupport()
        let locator = AuthorizedSafariSourceLocator(
            store: store,
            resolver: SystemSecurityScopedBookmarkResolver(),
            creator: SystemSecurityScopedBookmarkCreator()
        )
        let fileAccess = SandboxFileAccessProvider()
        let reader = SafariBookmarkReader(
            locator: locator,
            fileAccess: fileAccess,
            decoder: SafariBookmarkDecoder()
        )

        let location = try locator.locate(.safari)
        let modifiedBefore = try modificationDate(at: location, via: fileAccess)
        let tree = try await reader.readBookmarkTree()
        let modifiedAfter = try modificationDate(at: location, via: fileAccess)

        return .make(from: tree, isReadOnly: modifiedBefore == modifiedAfter)
    }

    private func modificationDate(at location: BrowserLocation, via fileAccess: FileAccessProviding) throws -> Date? {
        try fileAccess.withReadOnlyAccess(to: location) { url in
            try FileManager.default
                .attributesOfItem(atPath: url.path(percentEncoded: false))[.modificationDate] as? Date
        }
    }
}

@MainActor
@Observable
final class SafariAccessValidationModel {
    enum Status: Equatable {
        case idle
        case working
        case message(String)
        case report(SafariAccessValidationReport)
    }

    private(set) var status: Status = .idle
    private let validator = SafariAccessValidator()

    func authorize() async {
        status = .working
        do {
            try await validator.authorize()
            status = .message("Autorisation réussie. Le security-scoped bookmark a été créé et persisté.")
        } catch {
            status = .message("Autorisation impossible : \(error)")
        }
    }

    func validate() async {
        status = .working
        do {
            status = .report(try await validator.validate())
        } catch {
            status = .message("Lecture impossible : \(error)")
        }
    }
}

struct SafariAccessValidationView: View {
    @State private var model = SafariAccessValidationModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Validation technique — Accès Safari (lecture seule)")
                .font(.headline)
            Text("Étape 1 : autoriser (choisir ~/Library/Safari/Bookmarks.plist). "
                 + "Étape 2 : lire via le bookmark persistant (relançable après un redémarrage de l'app).")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button("1. Autoriser (NSOpenPanel)") { Task { await model.authorize() } }
                Button("2. Lire via bookmark persistant") { Task { await model.validate() } }
            }

            Divider()
            content
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 340)
    }

    @ViewBuilder
    private var content: some View {
        switch model.status {
        case .idle:
            Text("Prêt.").foregroundStyle(.secondary)
        case .working:
            ProgressView()
        case .message(let message):
            Text(message).textSelection(.enabled)
        case .report(let report):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(report.summaryLines, id: \.self) { Text($0) }
            }
            .textSelection(.enabled)
        }
    }
}
#endif
