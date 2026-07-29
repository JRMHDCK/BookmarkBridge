//
//  StatisticCard.swift
//  BookmarkBridge
//

import SwiftUI

struct StatisticCard: View {
    let value: Int
    let label: String
    var systemImage: String? = nil
    var prominent = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(value, format: .number)
                .font(prominent ? Theme.Typography.statNumber : .callout.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
            if let systemImage {
                Label(label, systemImage: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
                    .lineLimit(1)
            } else {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(
            .vertical,
            prominent ? Theme.Spacing.s : Theme.Spacing.zero
        )
        .padding(
            .horizontal,
            prominent ? Theme.Spacing.m : Theme.Spacing.zero
        )
        .background {
            if prominent {
                RoundedRectangle(
                    cornerRadius: Theme.Radius.control,
                    style: .continuous
                )
                .fill(Color.primary.opacity(0.04))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) : \(value)")
    }
}
