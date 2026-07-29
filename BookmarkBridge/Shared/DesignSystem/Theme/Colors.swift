//
//  Colors.swift
//  BookmarkBridge
//

import SwiftUI

extension Theme {
    /// Semantic palette backed by adaptive Asset Catalog colors.
    nonisolated enum Palette {
        static let blue = Color("BrandBlue")
        static let blueSubtle = Color("BrandBlueSubtle")
        static let green = Color("BrandGreen")
        static let greenSubtle = Color("BrandGreenSubtle")
        static let warning = Color("BrandWarning")
        static let error = Color("BrandError")
        static let cardSurface = Color("SurfaceCard")

        static var brandGradient: LinearGradient {
            LinearGradient(
                colors: [blue, green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
