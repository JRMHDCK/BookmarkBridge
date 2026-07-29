//
//  Colors.swift
//  BookmarkBridge
//

import SwiftUI

extension Theme {
    /// Semantic palette built from system colors so the app follows the active
    /// macOS appearance, contrast and accent-color settings automatically.
    nonisolated enum Palette {
        static let blue = Color.accentColor
        static let blueSubtle = Color.accentColor.opacity(0.1)
        static let green = Color.green
        static let greenSubtle = Color.green.opacity(0.1)
        static let warning = Color.orange
        static let error = Color.red
        static let cardSurface = Color(nsColor: .controlBackgroundColor)

        /// Retained for API compatibility. New interface surfaces use the
        /// system accent directly rather than decorative gradients.
        static var brandGradient: LinearGradient {
            LinearGradient(
                colors: [blue, green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    nonisolated enum Materials {
        static let bar: Material = .bar
    }
}
