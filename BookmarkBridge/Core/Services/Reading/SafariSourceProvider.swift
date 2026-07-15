//
//  SafariSourceProvider.swift
//  BookmarkBridge
//

import Foundation

/// Provides Safari's single source. Discovery needs no authorization: it always
/// yields the one reader; that reader surfaces `authorizationRequired` itself
/// when it tries to read without a granted bookmark.
nonisolated struct SafariSourceProvider: BrowserSourceProviding {
    let browser: Browser = .safari

    private let reader: BookmarkReading

    init(reader: BookmarkReading) {
        self.reader = reader
    }

    func makeReaders() async throws -> [BookmarkReading] {
        [reader]
    }
}
