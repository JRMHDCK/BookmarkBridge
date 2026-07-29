//
//  Metrics.swift
//  BookmarkBridge
//

import SwiftUI

extension Theme {
    nonisolated enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    nonisolated enum Radius {
        static let control: CGFloat = 6
        static let card: CGFloat = 12
    }

    nonisolated enum Size {
        /// A comfortable minimum target for pointer and accessibility use.
        static let minimumInteractive: CGFloat = 28
        static let sidebarIdealWidth: CGFloat = 190
        static let contentMaxWidth: CGFloat = 860
    }
}
