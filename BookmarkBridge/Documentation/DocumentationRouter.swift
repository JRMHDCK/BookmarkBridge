//
//  DocumentationRouter.swift
//  BookmarkBridge
//

import Observation

enum DocumentationDestination: Equatable {
    case application
    case helpCenter
    case whatsNew
    case about
}

@MainActor
@Observable
final class DocumentationRouter {
    private(set) var requestedPageID: HelpPageID = .introduction
    private(set) var destination: DocumentationDestination = .application

    func request(_ pageID: HelpPageID) {
        requestedPageID = pageID
        destination = .helpCenter
    }

    func showWhatsNew() {
        destination = .whatsNew
    }

    func showAbout() {
        destination = .about
    }

    func showApplication() {
        destination = .application
    }
}
