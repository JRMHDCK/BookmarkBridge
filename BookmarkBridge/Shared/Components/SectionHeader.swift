//
//  SectionHeader.swift
//  BookmarkBridge
//

import SwiftUI

struct ScreenHeader: View {
    let title: String
    let subtitle: String

    init(_ title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.screenTitle)
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeader: View {
    let title: String
    let systemImage: String?
    let subtitle: String?

    init(
        _ title: String,
        systemImage: String? = nil,
        subtitle: String? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .font(Theme.Typography.cardTitle)
                    .symbolRenderingMode(.hierarchical)
            } else {
                Text(title)
                    .font(Theme.Typography.cardTitle)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
