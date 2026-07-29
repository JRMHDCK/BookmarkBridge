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
        #expect(Theme.Size.sidebarIdealWidth > 0)
        #expect(
            Theme.Size.contentMaxWidth
                > Theme.Size.sidebarIdealWidth
        )
    }

    #if canImport(AppKit)
    @Test("Every brand color token resolves to an Asset Catalog color")
    @MainActor
    func brandColorAssetsExist() {
        let names = [
            "BrandBlue",
            "BrandBlueSubtle",
            "BrandGreen",
            "BrandGreenSubtle",
            "BrandWarning",
            "BrandError",
            "SurfaceCard",
            "AccentColor",
        ]
        for name in names {
            #expect(NSColor(named: name) != nil, "Missing color asset: \(name)")
        }
    }
    #endif
}
