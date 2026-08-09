//
//  BookmarkAccessView.swift
//  BookmarkBridge
//

import SwiftUI

struct BookmarkAccessView: View {
    @Bindable var model: BookmarkAccessViewModel
    let onLoad: () async -> Void
    let onTestAccess: (Browser) async -> Void
    let onReselect: (Browser) async -> Void
    let onChangeProfile: (String) async -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ScreenHeader(
                    DocumentationText.value("access.title"),
                    subtitle: DocumentationText.value("access.subtitle")
                )

                safariSection
                chromeSection
            }
            .frame(maxWidth: Theme.Size.contentMaxWidth, alignment: .leading)
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle(DocumentationText.value("access.title"))
        .task { await onLoad() }
    }

    private var safariSection: some View {
        GroupBox(DocumentationText.value("browser.safari.name")) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                pathRow(
                    title: DocumentationText.value("access.detectedPath"),
                    path: model.snapshot?.safari.detectedURL.path
                )
                pathRow(
                    title: DocumentationText.value("access.authorizedPath"),
                    path: model.snapshot?.safari.authorizedURL?.path
                )
                statusRow(model.snapshot?.safari.status)
                if let tested = model.safariTestStatus {
                    Text(
                        DocumentationText.formatted(
                            "access.testResult",
                            tested.label
                        )
                    )
                        .foregroundStyle(tested == .ok ? .green : .red)
                }
                HStack {
                    Button(DocumentationText.value("access.test")) {
                        Task { await onTestAccess(.safari) }
                    }
                    Button(DocumentationText.value("access.reselect")) {
                        Task { await onReselect(.safari) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.s)
        }
    }

    private var chromeSection: some View {
        GroupBox(DocumentationText.value("browser.chrome.name")) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                pathRow(
                    title: DocumentationText.value("access.authorizedFolder"),
                    path: model.snapshot?.chrome.authorizedDirectoryURL?.path
                )
                if let profile = model.selectedChromeProfile {
                    valueRow(
                        title: DocumentationText.value("access.profile"),
                        value: profile.profileName
                    )
                    valueRow(
                        title: DocumentationText.value("access.profileFolder"),
                        value: profile.directoryName
                    )
                    pathRow(
                        title: DocumentationText.value("access.bookmarksFile"),
                        path: profile.bookmarksURL.path
                    )
                } else {
                    Text(DocumentationText.value("access.noChromeProfile"))
                        .foregroundStyle(.secondary)
                }
                statusRow(model.snapshot?.chrome.status)
                if let tested = model.chromeTestStatus {
                    Text(
                        DocumentationText.formatted(
                            "access.testResult",
                            tested.label
                        )
                    )
                        .foregroundStyle(tested == .ok ? .green : .red)
                }
                HStack {
                    Button(DocumentationText.value("access.test")) {
                        Task { await onTestAccess(.chrome) }
                    }
                    Menu(DocumentationText.value("access.changeProfile")) {
                        ForEach(model.snapshot?.chrome.profiles ?? []) { profile in
                            Button(profile.profileName) {
                                Task { await onChangeProfile(profile.directoryName) }
                            }
                        }
                    }
                    .disabled(model.snapshot?.chrome.profiles.isEmpty != false)
                    Button(DocumentationText.value("access.reselect")) {
                        Task { await onReselect(.chrome) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.s)
        }
    }

    private func statusRow(_ status: BookmarkAccessStatus?) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Text(DocumentationText.value("common.status"))
                .fontWeight(.semibold)
            Text(
                status?.label
                    ?? DocumentationText.value("common.checking")
            )
                .foregroundStyle(status == .ok ? .green : .secondary)
        }
    }

    private func pathRow(title: String, path: String?) -> some View {
        valueRow(
            title: title,
            value: path ?? DocumentationText.value("access.notAuthorized")
        )
    }

    private func valueRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
