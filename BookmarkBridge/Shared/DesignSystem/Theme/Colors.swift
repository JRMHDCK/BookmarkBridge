//
//  Colors.swift
//  BookmarkBridge
//

import SwiftUI

extension Theme {
    /// Semantic palette built from system colors so the app follows the active
    /// macOS appearance, contrast and accent-color settings automatically.
    nonisolated enum Palette {
        static let green = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let cardSurface = Color(nsColor: .controlBackgroundColor)
    }

    nonisolated enum Materials {
        static let bar: Material = .bar
    }
}
