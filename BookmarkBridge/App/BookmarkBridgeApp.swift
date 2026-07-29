//
//  BookmarkBridgeApp.swift
//  BookmarkBridge
//
//  Created by Jérôme Hudecek on 15/07/2026.
//

import SwiftUI

@main
struct BookmarkBridgeApp: App {
    private let applicationViewModel: ApplicationViewModel

    init() {
        let dependencies = AppDependencies.bootstrap()

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
            resolver: SystemSecurityScopedBookmarkResolver(),
            creator: dependencies.bookmarkCreator,
            fileController: SystemSecurityScopedFileController(),
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
            synchronization: SynchronizationViewModel(
                previewService:
                    dependencies.synchronizationPreviewService,
                requestProvider:
                    dependencies.synchronizationPreviewRequestProvider,
                executionService:
                    dependencies.synchronizationExecutionService
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ApplicationNavigationView(model: applicationViewModel)
        }
        .defaultSize(
            width: Theme.Size.windowIdealWidth,
            height: Theme.Size.windowIdealHeight
        )
        .windowResizability(.contentMinSize)
    }
}
