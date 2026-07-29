//
//  Typography.swift
//  BookmarkBridge
//

import SwiftUI

extension Theme {
    /// Text styles remain semantic so Dynamic Type can scale them.
    nonisolated enum Typography {
        static var appTitle: Font { .largeTitle }

        static var screenTitle: Font { .title2 }

        static var cardTitle: Font { .headline }

        static var statNumber: Font {
            Font.title2
                .weight(.semibold)
                .monospacedDigit()
        }
    }
}
