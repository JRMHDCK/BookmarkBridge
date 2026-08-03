//
//  BrowserLogo.swift
//  BookmarkBridge
//

import SwiftUI

enum ChromeLogoArtwork {
    case standard
    case homeAndSynchronization

    var assetName: String {
        switch self {
        case .standard:
            "ChromeLogo"
        case .homeAndSynchronization:
            "ChromeHomeSynchronizationLogo"
        }
    }

    var displayScale: CGFloat {
        switch self {
        case .standard:
            1
        case .homeAndSynchronization:
            // The source artwork occupies 441 of its 500 transparent pixels.
            // Match Safari's existing 76% visible diameter without altering it.
            380.0 / 441.0
        }
    }
}

/// Consistent Safari/Chrome artwork while preserving each official mark.
struct BrowserLogo: View {
    let browser: Browser
    let size: CGFloat
    let chromeArtwork: ChromeLogoArtwork

    init(
        browser: Browser,
        size: CGFloat,
        chromeArtwork: ChromeLogoArtwork = .standard
    ) {
        self.browser = browser
        self.size = size
        self.chromeArtwork = chromeArtwork
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
                Image(chromeArtwork.assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: size * 0.12,
                            style: .continuous
                        )
                    )
                    .scaleEffect(chromeArtwork.displayScale)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
