//
//  HelpPageView.swift
//  BookmarkBridge
//

import SwiftUI

struct HelpPageView: View {
    let page: HelpPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                pageHeader
                ForEach(Array(page.blocks.enumerated()), id: \.offset) {
                    _, block in
                    blockView(block)
                }
            }
            .frame(
                maxWidth: Theme.Size.contentMaxWidth,
                alignment: .leading
            )
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle(DocumentationText.value(page.id.titleKey))
    }

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.l) {
            Group {
                switch page.id.icon {
                case .browser(let browser):
                    BrowserLogo(browser: browser, size: 44)
                case .system(let name):
                    Image(systemName: name)
                        .font(.system(size: 30))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                }
            }
                .frame(width: 52, height: 52)
                .background(
                    Color.accentColor.opacity(0.10),
                    in: RoundedRectangle(
                        cornerRadius: Theme.Radius.card,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(DocumentationText.value(page.id.titleKey))
                    .font(Theme.Typography.screenTitle)
                Text(DocumentationText.value(page.id.subtitleKey))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func blockView(_ block: HelpBlock) -> some View {
        switch block {
        case .heading(let key):
            Text(DocumentationText.value(key))
                .font(Theme.Typography.cardTitle)
                .padding(.top, Theme.Spacing.s)
        case .paragraph(let key):
            Text(DocumentationText.value(key))
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        case .bullets(let keys):
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                ForEach(keys, id: \.self) { key in
                    HStack(
                        alignment: .firstTextBaseline,
                        spacing: Theme.Spacing.s
                    ) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(DocumentationText.value(key))
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                    }
                }
            }
        case .steps(let keys):
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ForEach(Array(keys.enumerated()), id: \.offset) {
                    index, key in
                    HStack(alignment: .top, spacing: Theme.Spacing.m) {
                        Text(index + 1, format: .number)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .frame(width: 24, height: 24)
                            .background(
                                Color.accentColor.opacity(0.12),
                                in: Circle()
                            )
                            .accessibilityHidden(true)
                        Text(DocumentationText.value(key))
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        DocumentationText.formatted(
                            "help.accessibility.step",
                            index + 1,
                            DocumentationText.value(key)
                        )
                    )
                }
            }
        case .note(let titleKey, let bodyKey, let systemImage):
            GroupBox {
                Text(DocumentationText.value(bodyKey))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.xs)
            } label: {
                Label(
                    DocumentationText.value(titleKey),
                    systemImage: systemImage
                )
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
            }
        case .question(let questionKey, let answerKey):
            DisclosureGroup {
                Text(DocumentationText.value(answerKey))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Theme.Spacing.s)
            } label: {
                Text(DocumentationText.value(questionKey))
                    .font(.headline)
            }
            .accessibilityElement(children: .contain)
        }
    }
}
