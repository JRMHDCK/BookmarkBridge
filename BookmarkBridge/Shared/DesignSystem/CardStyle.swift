//
//  CardStyle.swift
//  BookmarkBridge
//
//  A restrained system surface for the few places that require a card.
//

import SwiftUI

/// Uses an opaque system control background. There is deliberately no shadow or
/// custom glass effect, so the surface follows macOS appearance changes.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.l)
            .background(
                Theme.Palette.cardSurface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }
}

extension View {
    /// Wraps the view in the shared card surface.
    func cardStyle() -> some View { modifier(CardStyle()) }
}

// MARK: - Preview

#Preview("Card surface") {
    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
        Text("Safari")
            .font(Theme.Typography.cardTitle)
        Text("Exemple de contenu de carte utilisant la surface partagée.")
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle()
    .padding(Theme.Spacing.xl)
    .frame(width: 420)
}
