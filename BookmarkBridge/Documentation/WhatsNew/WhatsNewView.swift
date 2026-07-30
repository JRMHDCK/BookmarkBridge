//
//  WhatsNewView.swift
//  BookmarkBridge
//

import SwiftUI

struct WhatsNewView: View {
    let release: WhatsNewRelease

    init(release: WhatsNewRelease = WhatsNewContent.current) {
        self.release = release
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header
                ForEach(release.sections) { section in
                    sectionView(section)
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle(
            DocumentationText.value("whatsNew.window.title")
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Image(systemName: "gift")
                .font(.largeTitle)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(DocumentationText.value("whatsNew.title"))
                .font(Theme.Typography.screenTitle)
            Text(
                DocumentationText.formatted(
                    "whatsNew.version",
                    release.version,
                    release.build
                )
            )
            .font(.title3)
            .foregroundStyle(.secondary)
            Text(DocumentationText.value("whatsNew.introduction"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionView(_ section: WhatsNewSection) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ForEach(section.itemKeys, id: \.self) { key in
                    HStack(
                        alignment: .firstTextBaseline,
                        spacing: Theme.Spacing.s
                    ) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(Theme.Palette.green)
                            .accessibilityHidden(true)
                        Text(DocumentationText.value(key))
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Spacing.xs)
        } label: {
            Label(
                DocumentationText.value(section.titleKey),
                systemImage: section.systemImage
            )
            .font(.headline)
            .symbolRenderingMode(.hierarchical)
        }
    }
}
