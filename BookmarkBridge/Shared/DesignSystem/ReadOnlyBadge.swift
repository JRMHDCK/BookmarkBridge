//
//  ReadOnlyBadge.swift
//  BookmarkBridge
//
//  The shared "Lecture seule" badge for browser sources that cannot be edited.
//

import SwiftUI

/// A neutral capsule used where a browser source remains read-only.
struct ReadOnlyBadge: View {
    var body: some View {
        Label("Lecture seule", systemImage: "lock")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Color.primary.opacity(0.05), in: Capsule())
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
