//
//  CardStyle.swift
//  BookmarkBridge
//
//  The shared surface for cards: an opaque, rounded panel that lifts off the
//  window background with a soft shadow (in light) and a hairline border. Apply
//  with `.cardStyle()` so every card shares one elevation and radius.
//

import SwiftUI

/// A rounded, opaque card surface (see the design system: "surface pleine +
/// ombre douce"). Content is padded, filled with the card surface color, given
/// the card corner radius, a hairline border, and a subtle drop shadow.
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
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
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
