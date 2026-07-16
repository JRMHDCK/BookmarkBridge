//
//  ReadOnlyBadge.swift
//  BookmarkBridge
//
//  The shared "Lecture seule" badge. BookmarkBridge only ever reads bookmarks,
//  so every source advertises its read-only nature with this green capsule.
//

import SwiftUI

/// A small green capsule reading "Lecture seule", used on source cards to make
/// the app's read-only guarantee visible.
struct ReadOnlyBadge: View {
    var body: some View {
        Label("Lecture seule", systemImage: "lock.fill")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(Theme.Palette.green)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Palette.greenSubtle, in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Accès en lecture seule")
    }
}

// MARK: - Preview

#Preview("Read-only badge") {
    VStack(spacing: Theme.Spacing.l) {
        ReadOnlyBadge()
        ReadOnlyBadge()
            .preferredColorScheme(.dark)
    }
    .padding(Theme.Spacing.xl)
}
