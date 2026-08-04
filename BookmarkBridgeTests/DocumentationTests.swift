//
//  DocumentationTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Integrated documentation")
@MainActor
struct DocumentationTests {
    @Test("The help catalog covers every declared section")
    func helpCatalogIsComplete() {
        #expect(HelpCatalog.pages.count == 13)
        #expect(
            HelpCatalog.pages.map(\.id)
                == HelpPageID.allCases
        )
        #expect(
            Set(HelpCatalog.pages.map(\.id)).count
                == HelpCatalog.pages.count
        )
        #expect(
            HelpCatalog.pages.allSatisfy {
                !$0.blocks.isEmpty
            }
        )
    }

    @Test("Every help string resolves from the local catalog")
    func helpStringsResolve() {
        let keys = HelpCatalog.pages.flatMap(\.searchableKeys)

        #expect(
            keys.allSatisfy {
                DocumentationText.value($0) != $0
            }
        )
    }

    @Test("Help search indexes content and FAQ answers")
    func helpSearchIndexesContent() {
        let backupResults = HelpCatalog.search("sauvegarde")
        let permissionResults = HelpCatalog.search("autorisation")

        #expect(backupResults.contains { $0.id == .backups })
        #expect(backupResults.contains { $0.id == .faq })
        #expect(
            permissionResults.contains {
                $0.id == .configuration
            }
        )
    }

    @Test("Onboarding has the complete eight-step journey")
    func onboardingIsComplete() {
        #expect(OnboardingContent.steps.count == 8)
        #expect(OnboardingContent.steps.first?.id == "welcome")
        #expect(OnboardingContent.steps.last?.id == "finish")
        #expect(
            Set(OnboardingContent.steps.map(\.id)).count
                == OnboardingContent.steps.count
        )
        #expect(
            OnboardingContent.steps.allSatisfy {
                DocumentationText.value($0.titleKey)
                    != $0.titleKey
                    && DocumentationText.value($0.bodyKey)
                        != $0.bodyKey
            }
        )
    }

    @Test("What's New remains data-driven and complete")
    func whatsNewIsComplete() {
        let release = WhatsNewContent.current

        #expect(release.version == "0.9.1")
        #expect(release.build == "1")
        #expect(release.sections.count == 3)
        #expect(
            release.sections.allSatisfy {
                !$0.itemKeys.isEmpty
            }
        )
    }

    @Test("The offline user guide is bundled")
    func userGuideIsBundled() {
        let guide = Bundle.main.url(
            forResource: "BookmarkBridge-User-Guide",
            withExtension: "pdf"
        )

        #expect(guide != nil)
    }

    @Test("Technical failures receive user-facing guidance")
    func errorsReceiveGuidance() {
        let closedChrome =
            UserFacingErrorPresentation.presentation(
                for: "Safari et Chrome doivent être fermés."
            )
        let authorization =
            UserFacingErrorPresentation.presentation(
                for: "Accès refusé."
            )

        #expect(
            closedChrome.titleKey
                == "error.chromeRunning.title"
        )
        #expect(
            authorization.titleKey
                == "error.authorization.title"
        )
    }

    @Test("Documentation routes inside the main window")
    func documentationRoutesInsideMainWindow() {
        let router = DocumentationRouter()

        router.request(.backups)
        #expect(router.destination == .helpCenter)
        #expect(router.requestedPageID == .backups)

        router.showWhatsNew()
        #expect(router.destination == .whatsNew)

        router.showAbout()
        #expect(router.destination == .about)

        router.showApplication()
        #expect(router.destination == .application)
    }
}
