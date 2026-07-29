//
//  ThemeTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

#if canImport(AppKit)
import AppKit
#endif

@Suite("Theme")
struct ThemeTests {

    @Test("The spacing scale is strictly increasing")
    func spacingScaleIsIncreasing() {
        let scale = [
            Theme.Spacing.xs,
            Theme.Spacing.s,
            Theme.Spacing.m,
            Theme.Spacing.l,
            Theme.Spacing.xl,
            Theme.Spacing.xxl,
        ]
        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count)   // no duplicates
        #expect(Theme.Spacing.xs > 0)
    }

    @Test("Radii are positive and the card is rounder than a control")
    func radiiAreOrdered() {
        #expect(Theme.Radius.control > 0)
        #expect(Theme.Radius.card > Theme.Radius.control)
    }

    @Test("Interactive and layout metrics remain usable")
    func layoutMetricsAreUsable() {
        #expect(Theme.Size.minimumInteractive >= 28)
        #expect(
            Theme.Size.sidebarMinimumWidth
                < Theme.Size.sidebarIdealWidth
        )
        #expect(
            Theme.Size.sidebarIdealWidth
                < Theme.Size.sidebarMaximumWidth
        )
        #expect(Theme.Size.statisticMinimumWidth > 0)
        #expect(
            Theme.Size.contentMaxWidth
                > Theme.Size.sidebarIdealWidth
        )
        #expect(
            Theme.Size.windowMinimumWidth
                > Theme.Size.sidebarMaximumWidth
        )
        #expect(
            Theme.Size.windowIdealWidth
                > Theme.Size.windowMinimumWidth
        )
        #expect(
            Theme.Size.windowIdealHeight
                > Theme.Size.windowMinimumHeight
        )
        #expect(
            Theme.Size.explorerRowMinimumHeight
                >= Theme.Size.minimumInteractive
        )
        #expect(
            Theme.Size.breadcrumbItemMaximumWidth
                <= Theme.Size.contentMaxWidth
        )
    }

    #if canImport(AppKit)
    @Test("The application accent color resolves from the Asset Catalog")
    @MainActor
    func accentColorAssetExists() {
        #expect(NSColor(named: "AccentColor") != nil)
    }
    #endif
}
