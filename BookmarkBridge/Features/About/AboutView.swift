//
//  AboutView.swift
//  BookmarkBridge
//

import AppKit
import SwiftUI

struct AboutView: View {
    @Environment(DocumentationRouter.self) private var documentationRouter
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 76, height: 76)
                        .accessibilityLabel(
                            DocumentationText.value("about.logo")
                        )
                    Text(DocumentationText.value("about.name"))
                        .font(Theme.Typography.screenTitle)
                    Text(versionDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Label(
                        DocumentationText.value("about.promise.title"),
                        systemImage: "checkmark.shield"
                    )
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)
                    Text(
                        DocumentationText.value("about.promise.body")
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    LabeledContent(
                        DocumentationText.value("about.developer.label"),
                        value: DocumentationText.value(
                            "about.developer.value"
                        )
                    )
                    LabeledContent(
                        DocumentationText.value("about.engine.label"),
                        value: DocumentationText.value(
                            "about.engine.value"
                        )
                    )
                    LabeledContent(
                        DocumentationText.value("about.license.label"),
                        value: DocumentationText.value(
                            "about.license.value"
                        )
                    )
                    Text(DocumentationText.value("about.copyright"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 460)

                GroupBox {
                    Text(
                        DocumentationText.value(
                            "about.acknowledgements.body"
                        )
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.xs)
                } label: {
                    Label(
                        DocumentationText.value(
                            "about.acknowledgements.title"
                        ),
                        systemImage: "heart"
                    )
                }

                HStack(spacing: Theme.Spacing.m) {
                    Button(
                        DocumentationText.value(
                            "about.whatsNew.button"
                        )
                    ) {
                        documentationRouter.showWhatsNew()
                    }
                    .buttonStyle(.borderedProminent)
                    .help(
                        DocumentationText.value(
                            "about.whatsNew.tooltip"
                        )
                    )

                    Button(
                        DocumentationText.value(
                            "about.userGuide.button"
                        )
                    ) {
                        openUserGuide()
                    }
                    .buttonStyle(.bordered)
                    .help(
                        DocumentationText.value(
                            "about.userGuide.tooltip"
                        )
                    )
                }
            }
            .frame(
                maxWidth: Theme.Size.contentMaxWidth,
                alignment: .leading
            )
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle(
            DocumentationText.value("about.window.title")
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ContextualHelpButton(pageID: .introduction)
            }
        }
    }

    private var versionDescription: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String

        guard let version else {
            return DocumentationText.value("about.version.fallback")
        }
        guard let build else {
            return DocumentationText.formatted(
                "about.version.withoutBuild",
                version
            )
        }
        return DocumentationText.formatted(
            "about.version",
            version,
            build
        )
    }

    private func openUserGuide() {
        guard let url = Bundle.main.url(
            forResource: "BookmarkBridge-User-Guide",
            withExtension: "pdf"
        ) else { return }
        openURL(url)
    }
}
