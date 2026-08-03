//
//  BookmarkBridgeApp.swift
//  BookmarkBridge
//
//  Created by Jérôme Hudecek on 15/07/2026.
//

import AppKit
import SwiftUI

final class BookmarkBridgeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        true
    }
}

@main
struct BookmarkBridgeApp: App {
    @NSApplicationDelegateAdaptor(BookmarkBridgeAppDelegate.self)
    private var appDelegate
    private let applicationViewModel: ApplicationViewModel
    private let documentationRouter = DocumentationRouter()

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
        let profileSelectionStore =
            UserDefaultsChromeProfileSelectionStore()
        let bookmarkAccessService = BookmarkAccessService(
            store: dependencies.bookmarkStore,
            resolver: resolver,
            fileController: fileController,
            requester: requester
        )
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
                selectionStore: profileSelectionStore
            ),
            synchronization: SynchronizationViewModel(
                previewService:
                    dependencies.synchronizationPreviewService,
                requestProvider:
                    dependencies.synchronizationPreviewRequestProvider,
                executionService:
                    dependencies.synchronizationExecutionService
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
                .onDisappear {
                    NSApp.terminate(nil)
                }
        }
        .defaultSize(
            width: Theme.Size.windowIdealWidth,
            height: Theme.Size.windowIdealHeight
        )
        .windowResizability(.contentMinSize)
        .commands {
            DocumentationCommands(router: documentationRouter)
        }
    }
}
