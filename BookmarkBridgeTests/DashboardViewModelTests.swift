//
//  DashboardViewModelTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("DashboardViewModel")
@MainActor
struct DashboardViewModelTests {

    @Test("Starts idle before any load")
    func startsIdle() {
        let viewModel = DashboardViewModel(readers: [])
        #expect(viewModel.state == .idle)
    }

    @Test("Loads one summary per reader, with correct counts")
    func loadsSummaries() async {
        let viewModel = DashboardViewModel(readers: [
            InMemoryBookmarkReader(browser: .safari, tree: .sample(for: .safari)),
            InMemoryBookmarkReader(browser: .chrome, tree: .sample(for: .chrome)),
        ])

        await viewModel.load()

        guard case .loaded(let summaries) = viewModel.state else {
            Issue.record("expected .loaded, got \(viewModel.state)")
            return
        }
        #expect(summaries.map(\.browser) == [.safari, .chrome])
        #expect(summaries.allSatisfy { $0.bookmarkCount == 3 })
    }

    @Test("With no readers, loads an empty summary list")
    func loadsEmptyWhenNoReaders() async {
        let viewModel = DashboardViewModel(readers: [])
        await viewModel.load()
        #expect(viewModel.state == .loaded([]))
    }

    @Test("Surfaces a failure when a reader throws")
    func surfacesFailure() async {
        let viewModel = DashboardViewModel(readers: [
            FailingBookmarkReader(browser: .safari, error: .sourceNotFound(.safari))
        ])

        await viewModel.load()

        guard case .failed = viewModel.state else {
            Issue.record("expected .failed, got \(viewModel.state)")
            return
        }
    }
}
