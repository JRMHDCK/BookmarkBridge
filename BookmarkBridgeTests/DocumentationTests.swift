//
//  DocumentationTests.swift
//  BookmarkBridgeTests
//

import Foundation
import PDFKit
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
        let backupResults = HelpCatalog.search(
            "sauvegarde",
            language: .french
        )
        let permissionResults = HelpCatalog.search(
            "autorisation",
            language: .french
        )

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
                DocumentationText.value($0.titleKey, language: .french)
                    != $0.titleKey
                    && DocumentationText.value(
                        $0.bodyKey,
                        language: .french
                    )
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
        for language in AppLanguage.localizedLanguages {
            let guide = Bundle.main.url(
                forResource: "BookmarkBridge-User-Guide-\(language.rawValue)",
                withExtension: "pdf"
            )
            #expect(guide != nil)
        }
    }

    @Test("Integrated guidance describes bidirectional synchronization")
    func guidanceIsBidirectional() throws {
        let keys = HelpCatalog.pages.flatMap(\.searchableKeys)
            + OnboardingContent.steps.flatMap { [$0.titleKey, $0.bodyKey] }
        let text = keys.map {
            DocumentationText.value($0, language: .french)
        }.joined(separator: "\n")
        let obsoleteClaims = [
            "Safari reste en lecture seule",
            "Safari strictement en lecture seule",
            "n’écrit jamais",
            "ne modifie pas Safari",
            "ajoute à Chrome uniquement",
            "n’applique pas les suppressions",
        ]

        #expect(text.contains("Safari vers Chrome"))
        #expect(text.contains("Chrome vers Safari"))
        #expect(text.contains("sauvegarde"))
        #expect(text.contains("profils Chrome"))
        #expect(obsoleteClaims.allSatisfy { !text.contains($0) })
        #expect(BrowserLogo.chromeAssetName == "ChromeHomeSynchronizationLogo")
    }

    @Test("The bundled PDF documents both synchronization directions")
    func userGuideIsCurrent() throws {
        let url = try #require(Bundle.main.url(
            forResource: "BookmarkBridge-User-Guide-fr",
            withExtension: "pdf"
        ))
        let document = try #require(PDFDocument(url: url))
        let text = try #require(document.string)

        #expect(text.contains("Safari vers Chrome"))
        #expect(text.contains("Chrome vers Safari"))
        #expect(text.contains("sauvegarde"))
        #expect(text.contains("Plusieurs profils Chrome"))
        #expect(!text.contains("Safari reste en lecture seule"))
        #expect(!text.contains("ne modifie pas Safari"))
        #expect(!text.contains("n’applique pas les suppressions"))
    }

    @Test("The bundled manual matches each selected language")
    func userGuideLanguagesMatchSelection() throws {
        let expectedTitles: [AppLanguage: String] = [
            .english: "User Guide",
            .french: "Guide de l’utilisateur",
            .spanish: "Guía del usuario",
            .german: "Benutzerhandbuch",
            .italian: "Guida per l'utente",
            .portuguese: "Guia do usuário",
            .dutch: "Gebruikershandleiding",
            .polish: "Podręcznik użytkownika",
        ]

        for (language, expectedTitle) in expectedTitles {
            let url = try #require(Bundle.main.url(
                forResource:
                    "BookmarkBridge-User-Guide-\(language.rawValue)",
                withExtension: "pdf"
            ))
            let document = try #require(PDFDocument(url: url))
            let text = try #require(document.string)
            #expect(text.contains(expectedTitle))
            #expect(document.pageCount == 14)
        }
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
