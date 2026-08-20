//
//  BookmarkBridgeApp.swift
//  BookmarkBridge
//
//  Created by Jérôme Hudecek on 15/07/2026.
//

import AppKit
import SwiftUI

final class BookmarkBridgeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    private func mainWindowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        guard window.title == "BookmarkBridge" else { return }
        perform(#selector(terminateApplication), with: nil, afterDelay: 0)
    }

    @objc
    private func terminateApplication() {
        NSApp.terminate(nil)
    }
}

@main
struct BookmarkBridgeApp: App {
    @NSApplicationDelegateAdaptor(BookmarkBridgeAppDelegate.self)
    private var appDelegate
    private let applicationViewModel: ApplicationViewModel
    private let documentationRouter = DocumentationRouter()
    @State private var localization = LocalizationController()

    init() {
        let dependencies = AppDependencies.bootstrap()
        let resolver = SystemSecurityScopedBookmarkResolver()
        let fileController = SystemSecurityScopedFileController()

        let safariCoordinator = BrowserAccessCoordinator(
            browser: .safari,
            expectedPathSuffix: BrowserAccessCoordinator.safariPathSuffix,
            authorizer: OpenPanelFileAuthorizer(),
            creator: dependencies.bookmarkCreator,
            store: dependencies.bookmarkStore
        )
        let chromeCoordinator = BrowserAccessCoordinator(
            browser: .chrome,
            expectedPathSuffix: BrowserAccessCoordinator.chromeDirectorySuffix,
            authorizer: OpenPanelDirectoryAuthorizer(),
            creator: dependencies.bookmarkCreator,
            store: dependencies.bookmarkStore
        )
        let requester = CompositeAuthorizationRequester([
            .safari: BrowserAuthorizationRequester(
                browser: .safari,
                coordinator: safariCoordinator
            ),
            .chrome: BrowserAuthorizationRequester(
                browser: .chrome,
                coordinator: chromeCoordinator
            ),
        ])
        let authorizationService = ApplicationAuthorizationService(
            store: dependencies.bookmarkStore,
            resolver: resolver,
            creator: dependencies.bookmarkCreator,
            fileController: fileController,
            requester: requester
        )
        let preferencesStore =
            UserDefaultsSynchronizationPreferencesStore()
        let bookmarkAccessService = BookmarkAccessService(
            store: dependencies.bookmarkStore,
            resolver: resolver,
            fileController: fileController,
            requester: requester
        )
        let bugReportEmailComposer: any BugReportEmailComposing
        #if DEBUG
        if ProcessInfo.processInfo.environment[
            "BOOKMARKBRIDGE_UI_TEST_BUG_REPORT_COMPOSER"
        ] == "1" {
            bugReportEmailComposer = UITestBugReportEmailComposer()
        } else {
            bugReportEmailComposer = dependencies.bugReportEmailComposer
        }
        #else
        bugReportEmailComposer = dependencies.bugReportEmailComposer
        #endif
        let synchronizationViewModel = SynchronizationViewModel(
            previewService:
                dependencies.synchronizationPreviewService,
            requestProvider:
                dependencies.synchronizationPreviewRequestProvider,
            executionService:
                dependencies.synchronizationExecutionService,
            safariImportPresenter: SystemSafariImportPresenter(),
            preferencesStore: preferencesStore,
            diagnosticRecorder: dependencies.diagnosticEventStore
        )
        #if DEBUG
        if ProcessInfo.processInfo.environment[
            "BOOKMARKBRIDGE_UI_TEST_SYNC_FAILURE"
        ] == "1" {
            synchronizationViewModel.showFailureForUITesting()
        }
        #endif
        applicationViewModel = ApplicationViewModel(
            dashboard: DashboardViewModel(
                providers: dependencies.providers,
                authorizer: authorizationService
            ),
            authorization: ApplicationAuthorizationViewModel(
                service: authorizationService
            ),
            bookmarkAccess: BookmarkAccessViewModel(
                service: bookmarkAccessService,
                selectionStore: preferencesStore
            ),
            synchronization: synchronizationViewModel,
            bugReporting: BugReportViewModel(
                reportBuilder: dependencies.diagnosticReportBuilder,
                emailComposer: bugReportEmailComposer
            ),
            browserOperationGuard: BrowserOperationGuard(
                lifecycleController: SystemBrowserLifecycleController()
            )
        )
    }

    var body: some Scene {
        Window("BookmarkBridge", id: "main") {
            ApplicationNavigationView(model: applicationViewModel)
                .environment(documentationRouter)
                .environment(localization)
                .environment(\.locale, localization.locale)
                .id(localization.resolvedLanguage)
        }
        .defaultSize(
            width: Theme.Size.windowIdealWidth,
            height: Theme.Size.windowIdealHeight
        )
        .windowResizability(.contentMinSize)
        .commands {
            DocumentationCommands(
                router: documentationRouter,
                localization: localization
            )
        }
    }
}
