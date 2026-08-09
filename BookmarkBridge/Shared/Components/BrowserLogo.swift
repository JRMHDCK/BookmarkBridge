//
//  BrowserLogo.swift
//  BookmarkBridge
//

import SwiftUI

/// Consistent Safari/Chrome artwork while preserving each official mark.
struct BrowserLogo: View {
    static let chromeAssetName = "ChromeHomeSynchronizationLogo"

    let browser: Browser
    let size: CGFloat

    init(
        browser: Browser,
        size: CGFloat
    ) {
        self.browser = browser
        self.size = size
    }

    var body: some View {
        Group {
            switch browser {
            case .safari:
                Image(systemName: "safari")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .padding(size * 0.12)
            case .chrome:
                Image(Self.chromeAssetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: size * 0.12,
                            style: .continuous
                        )
                    )
                    // The artwork occupies 441 of its 500 transparent pixels.
                    .scaleEffect(380.0 / 441.0)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
