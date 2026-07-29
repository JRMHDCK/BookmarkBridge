//
//  StatisticCard.swift
//  BookmarkBridge
//

import SwiftUI

struct StatisticCard: View {
    let value: Int
    let label: String
    var prominent = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(value, format: .number)
                .font(prominent ? Theme.Typography.statNumber : .callout.weight(.semibold))
                .foregroundStyle(Theme.Palette.blue)
            Text(label)
                .font(prominent ? .caption : .caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, prominent ? Theme.Spacing.s : 0)
        .padding(.horizontal, prominent ? Theme.Spacing.m : 0)
        .background {
            if prominent {
                RoundedRectangle(
                    cornerRadius: Theme.Radius.control,
                    style: .continuous
                )
                .fill(Theme.Palette.blueSubtle.opacity(0.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) : \(value)")
    }
}
