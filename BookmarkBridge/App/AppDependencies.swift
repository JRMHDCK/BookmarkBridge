//
//  AppDependencies.swift
//  BookmarkBridge
//

import Foundation

/// The composition root's dependency graph.
///
/// Holds the concrete services the app runs against, all behind `Core`
/// abstractions so that features depend on protocols, never implementations. It
/// is assembled once and injected downward.
///
/// Safari and Chrome are wired to their real read and BSE synchronization chains
/// via
/// `BrowserSourceProviding`. Before the user authorizes access, sources surface
/// `authorizationRequired`; the authorization actions are wired at the app layer
/// (macOS).
nonisolated struct AppDependencies {
    let providers: [any BrowserSourceProviding]
    let differ: BookmarkDiffing
    let backup: BookmarkBackup
    let synchronizationPreviewService: any SynchronizationPreviewProviding
    let synchronizationPreviewRequestProvider:
        any SynchronizationPreviewRequestProviding
    let synchronizationExecutionService:
        any SynchronizationProductionExecuting
    let diagnosticEventStore:
        any DiagnosticEventRecording & DiagnosticEventReading
    let diagnosticReportBuilder: any DiagnosticReportBuilding
    let bugReportEmailComposer: any BugReportEmailComposing

    /// Shared store for the persisted security-scoped bookmarks. Exposed so the
    /// app-layer authorization flow persists to the same location the providers
    /// resolve from.
    let bookmarkStore: BookmarkStore

    /// Shared bookmark creator, exposed for the app-layer authorization flow.
    let bookmarkCreator: SecurityScopedBookmarkCreating

    init(
        providers: [any BrowserSourceProviding],
        differ: BookmarkDiffing,
        backup: BookmarkBackup,
        synchronizationPreviewService: any SynchronizationPreviewProviding,
        synchronizationPreviewRequestProvider:
            any SynchronizationPreviewRequestProviding,
        synchronizationExecutionService:
            any SynchronizationProductionExecuting,
        diagnosticEventStore:
            any DiagnosticEventRecording & DiagnosticEventReading,
        diagnosticReportBuilder: any DiagnosticReportBuilding,
        bugReportEmailComposer: any BugReportEmailComposing,
        bookmarkStore: BookmarkStore,
        bookmarkCreator: SecurityScopedBookmarkCreating
    ) {
        self.providers = providers
        self.differ = differ
        self.backup = backup
        self.synchronizationPreviewService = synchronizationPreviewService
        self.synchronizationPreviewRequestProvider =
            synchronizationPreviewRequestProvider
        self.synchronizationExecutionService =
            synchronizationExecutionService
        self.diagnosticEventStore = diagnosticEventStore
        self.diagnosticReportBuilder = diagnosticReportBuilder
        self.bugReportEmailComposer = bugReportEmailComposer
        self.bookmarkStore = bookmarkStore
        self.bookmarkCreator = bookmarkCreator
    }
}

extension AppDependencies {
    /// The production graph: real Safari and Chrome providers plus shared BSE
    /// preview and execution services, wired through persisted security-scoped
    /// bookmarks.
    static func bootstrap() -> AppDependencies {
        let store = ApplicationSupportBookmarkStore.inApplicationSupport()
        let diagnosticEventStore =
            FileDiagnosticEventStore.inApplicationSupport()
        let diagnosticReportBuilder = DefaultDiagnosticReportBuilder(
            eventReader: diagnosticEventStore,
            application: DiagnosticEnvironment.applicationInfo(),
            system: DiagnosticEnvironment.systemInfo()
        )
        let creator = SystemSecurityScopedBookmarkCreator()
        let resolver = SystemSecurityScopedBookmarkResolver()
        let safariLocator = AuthorizedBookmarkSourceLocator(
            browser: .safari,
            store: store,
            resolver: resolver,
            creator: creator
        )
        let chromeLocator = AuthorizedBookmarkSourceLocator(
            browser: .chrome,
            store: store,
            resolver: resolver,
            creator: creator
        )

        let backupsRoot = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("BookmarkBridge/Backups", isDirectory: true)

        let safariReader = SafariBookmarkReader(
            locator: safariLocator,
            fileAccess: SandboxFileAccessProvider(),
            decoder: SafariBookmarkDecoder()
        )
        let safariProvider = SafariSourceProvider(reader: safariReader)

        let chromeProvider = ChromeSourceProvider(
            directoryLocator: chromeLocator,
            fileAccess: SandboxFileAccessProvider(),
            profileLocator: DefaultChromeProfileLocator(),
            decoder: ChromeBookmarkDecoder()
        )

        let synchronizationPreviewService:
            any SynchronizationPreviewProviding
        let synchronizationExecutionService:
            any SynchronizationProductionExecuting
        do {
            let baseline = try Baseline.empty(
                baselineID: BaselineID(UUID())
            )
            let baselineRepository = BaselineRepository(
                store: InMemoryBaselineStore(baseline: baseline)
            )
            let identityProvider = UUIDLogicalIdentityProvider()
            let nativeIdentityRepository =
                InMemoryNativeIdentityRepository()
            synchronizationPreviewService = SynchronizationPreviewService(
                baselineRepository: baselineRepository,
                identityProvider: identityProvider,
                nativeIdentityRepository: nativeIdentityRepository
            )
            let productionService = ProductionSynchronizationService(
                baselineRepository: baselineRepository,
                identityProvider: identityProvider,
                nativeIdentityRepository: nativeIdentityRepository,
                safariAdapterIdentifier: WriteAdapterIdentifier(UUID()),
                chromeAdapterIdentifier: WriteAdapterIdentifier(UUID())
            )
            synchronizationExecutionService =
                SynchronizationExecutionCoordinator(
                    productionService: productionService,
                    safariBackupDirectoryURL: backupsRoot.appendingPathComponent(
                        "Safari",
                        isDirectory: true
                    ),
                    chromeBackupDirectoryURL: backupsRoot.appendingPathComponent(
                        "Chrome",
                        isDirectory: true
                    )
                )
        } catch {
            synchronizationPreviewService =
                UnavailableSynchronizationPreviewService()
            synchronizationExecutionService =
                UnavailableSynchronizationExecutionCoordinator()
        }

        return AppDependencies(
            providers: [safariProvider, chromeProvider],
            differ: AdditiveBookmarkDiffer(),
            backup: FileBookmarkBackup(rootDirectory: backupsRoot),
            synchronizationPreviewService: synchronizationPreviewService,
            synchronizationPreviewRequestProvider:
                DashboardSynchronizationPreviewRequestProvider(
                    safariLocator: safariLocator,
                    chromeLocator: chromeLocator
                ),
            synchronizationExecutionService:
                synchronizationExecutionService,
            diagnosticEventStore: diagnosticEventStore,
            diagnosticReportBuilder: diagnosticReportBuilder,
            bugReportEmailComposer: DefaultBugReportEmailComposer.systemDefault(),
            bookmarkStore: store,
            bookmarkCreator: creator
        )
    }
}
