//
//  Metrics.swift
//  BookmarkBridge
//

import SwiftUI

extension Theme {
    nonisolated enum Spacing {
        static let zero: CGFloat = 0
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    nonisolated enum Radius {
        static let control: CGFloat = 6
        static let card: CGFloat = 10
    }

    nonisolated enum Size {
        /// A comfortable minimum target for pointer and accessibility use.
        static let minimumInteractive: CGFloat = 28
        static let sidebarMinimumWidth: CGFloat = 168
        static let sidebarIdealWidth: CGFloat = 184
        static let sidebarMaximumWidth: CGFloat = 220
        static let statisticMinimumWidth: CGFloat = 104
        static let contentMaxWidth: CGFloat = 780
    }
}
