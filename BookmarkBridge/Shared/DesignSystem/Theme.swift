//
//  Theme.swift
//  BookmarkBridge
//
//  Design-system foundations: the single source of truth for the app's colors,
//  spacing, corner radii and typography. Views must read these tokens rather
//  than hard-coding values, so the look stays consistent and adapts to light /
//  dark automatically (color tokens are backed by Asset Catalog color sets).
//

import SwiftUI

/// Namespace for the design-system tokens. `nonisolated` so the tokens can be
/// read from any context (views, previews, tests) without actor hops.
nonisolated enum Theme {

    // MARK: Colors

    /// Brand palette. Blue carries identity and interaction; green signals the
    /// read-only / healthy status; the gradient is reserved for brand moments.
    nonisolated enum Palette {
        static let blue = Color("BrandBlue")
        static let blueSubtle = Color("BrandBlueSubtle")
        static let green = Color("BrandGreen")
        static let greenSubtle = Color("BrandGreenSubtle")
        static let warning = Color("BrandWarning")
        static let error = Color("BrandError")
        /// Opaque surface used by cards, distinct from the window background.
        static let cardSurface = Color("SurfaceCard")

        /// Blue → green diagonal, reserved for brand moments (logo, app icon,
        /// header) — never for ordinary UI accents.
        static var brandGradient: LinearGradient {
            LinearGradient(
                colors: [blue, green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: Spacing

    /// 4-based spacing scale. Use these exclusively for padding and gaps.
    nonisolated enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Radius

    /// Corner-radius tokens. Controls use `control`; cards use `card`; badges
    /// use a full `Capsule`.
    nonisolated enum Radius {
        static let control: CGFloat = 6
        static let card: CGFloat = 12
    }

    // MARK: Typography

    /// Semantic fonts (Dynamic Type). Titles and figures use the rounded SF Pro
    /// variant for a friendlier, modern feel; body text stays default SF Pro.
    nonisolated enum Typography {
        /// App / hero title.
        static var appTitle: Font { .system(.title, design: .rounded).weight(.semibold) }
        /// Card and section headers.
        static var cardTitle: Font { .system(.headline, design: .rounded) }
        /// Numeric statistics — rounded, semibold, monospaced digits so figures
        /// stay aligned as they change.
        static var statNumber: Font { .system(.title2, design: .rounded).weight(.semibold).monospacedDigit() }
    }
}
