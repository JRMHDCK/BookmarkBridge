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
                    "Accès aux favoris",
                    subtitle: "Vérifiez les fichiers autorisés et le profil Chrome utilisé."
                )

                safariSection
                chromeSection
            }
            .frame(maxWidth: Theme.Size.contentMaxWidth, alignment: .leading)
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("Accès aux favoris")
        .task { await onLoad() }
    }

    private var safariSection: some View {
        GroupBox("Safari") {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                pathRow(
                    title: "Chemin détecté",
                    path: model.snapshot?.safari.detectedURL.path
                )
                pathRow(
                    title: "Chemin autorisé",
                    path: model.snapshot?.safari.authorizedURL?.path
                )
                statusRow(model.snapshot?.safari.status)
                if let tested = model.safariTestStatus {
                    Text("Test : \(tested.label)")
                        .foregroundStyle(tested == .ok ? .green : .red)
                }
                HStack {
                    Button("Tester l’accès") {
                        Task { await onTestAccess(.safari) }
                    }
                    Button("Resélectionner…") {
                        Task { await onReselect(.safari) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.s)
        }
    }

    private var chromeSection: some View {
        GroupBox("Google Chrome") {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                pathRow(
                    title: "Dossier autorisé",
                    path: model.snapshot?.chrome.authorizedDirectoryURL?.path
                )
                if let profile = model.selectedChromeProfile {
                    valueRow(title: "Profil", value: profile.profileName)
                    valueRow(title: "Dossier du profil", value: profile.directoryName)
                    pathRow(title: "Fichier de favoris", path: profile.bookmarksURL.path)
                } else {
                    Text("Aucun profil Chrome disponible")
                        .foregroundStyle(.secondary)
                }
                statusRow(model.snapshot?.chrome.status)
                if let tested = model.chromeTestStatus {
                    Text("Test : \(tested.label)")
                        .foregroundStyle(tested == .ok ? .green : .red)
                }
                HStack {
                    Button("Tester l’accès") {
                        Task { await onTestAccess(.chrome) }
                    }
                    Menu("Changer de profil…") {
                        ForEach(model.snapshot?.chrome.profiles ?? []) { profile in
                            Button(profile.profileName) {
                                Task { await onChangeProfile(profile.directoryName) }
                            }
                        }
                    }
                    .disabled(model.snapshot?.chrome.profiles.isEmpty != false)
                    Button("Resélectionner…") {
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
            Text("État")
                .fontWeight(.semibold)
            Text(status?.label ?? "Vérification…")
                .foregroundStyle(status == .ok ? .green : .secondary)
        }
    }

    private func pathRow(title: String, path: String?) -> some View {
        valueRow(title: title, value: path ?? "Non autorisé")
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
