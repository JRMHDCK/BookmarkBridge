//
//  DocumentationRouter.swift
//  BookmarkBridge
//

import Observation

@MainActor
@Observable
final class DocumentationRouter {
    private(set) var requestedPageID: HelpPageID = .introduction

    func request(_ pageID: HelpPageID) {
        requestedPageID = pageID
    }
}
