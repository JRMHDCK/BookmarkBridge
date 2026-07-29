//
//  Animations.swift
//  BookmarkBridge
//

import SwiftUI

extension Theme {
    /// Centralized motion lets a future redesign change timing consistently.
    nonisolated enum Motion {
        static var quick: Animation {
            .easeOut(duration: 0.16)
        }

        static var stateChange: Animation {
            .easeInOut(duration: 0.2)
        }
    }
}
