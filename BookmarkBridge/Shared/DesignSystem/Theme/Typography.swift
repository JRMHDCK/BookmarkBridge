//
//  Typography.swift
//  BookmarkBridge
//

import SwiftUI

extension Theme {
    /// Text styles remain semantic so Dynamic Type can scale them.
    nonisolated enum Typography {
        static var screenTitle: Font { .largeTitle }

        static var cardTitle: Font { .headline }

        static var metadata: Font { .caption }

        static var statNumber: Font {
            Font.title2
                .weight(.semibold)
                .monospacedDigit()
        }
    }
}
