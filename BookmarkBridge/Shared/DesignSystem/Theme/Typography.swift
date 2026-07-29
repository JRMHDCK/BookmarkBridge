//
//  Typography.swift
//  BookmarkBridge
//

import SwiftUI

extension Theme {
    /// Text styles remain semantic so Dynamic Type can scale them.
    nonisolated enum Typography {
        static var appTitle: Font {
            .system(.title, design: .rounded).weight(.semibold)
        }

        static var screenTitle: Font {
            .system(.title2, design: .rounded).weight(.semibold)
        }

        static var cardTitle: Font {
            .system(.headline, design: .rounded)
        }

        static var statNumber: Font {
            .system(.title2, design: .rounded)
                .weight(.semibold)
                .monospacedDigit()
        }
    }
}
