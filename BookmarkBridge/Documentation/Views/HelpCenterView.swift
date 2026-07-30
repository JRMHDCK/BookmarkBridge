//
//  HelpCenterView.swift
//  BookmarkBridge
//

import SwiftUI

struct HelpCenterView: View {
    @Environment(DocumentationRouter.self) private var router

    @State private var selection: HelpPageID = .introduction
    @State private var query = ""
    @State private var history: [HelpPageID] = []
    @State private var columnVisibility:
        NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationTitle(
                    DocumentationText.value("help.window.title")
                )
                .navigationSplitViewColumnWidth(
                    min: Theme.Size.sidebarMinimumWidth,
                    ideal: Theme.Size.sidebarIdealWidth,
                    max: Theme.Size.sidebarMaximumWidth
                )
        } detail: {
            NavigationStack {
                HelpPageView(page: HelpCatalog.page(selection))
                    .toolbar { navigationToolbar }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(
            text: $query,
            placement: .sidebar,
            prompt: DocumentationText.value("help.search.prompt")
        )
        .onChange(
            of: router.requestedPageID,
            initial: true
        ) { _, pageID in
            navigate(to: pageID, recordingHistory: false)
        }
    }

    private var sidebar: some View {
        List {
            if filteredPages.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ForEach(filteredPages) { page in
                    Button {
                        navigate(to: page.id)
                    } label: {
                        Label(
                            DocumentationText.value(page.id.titleKey),
                            systemImage: page.id.systemImage
                        )
                        .symbolRenderingMode(.hierarchical)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        page.id == selection
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        page.id == selection ? .isSelected : []
                    )
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                goBack()
            } label: {
                Label(
                    DocumentationText.value("help.navigation.back"),
                    systemImage: "chevron.backward"
                )
            }
            .disabled(history.isEmpty)
            .help(
                DocumentationText.value(
                    "help.navigation.back.tooltip"
                )
            )

            Button {
                columnVisibility = .all
            } label: {
                Label(
                    DocumentationText.value("help.navigation.contents"),
                    systemImage: "sidebar.left"
                )
            }
            .help(
                DocumentationText.value(
                    "help.navigation.contents.tooltip"
                )
            )
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                if let page = HelpCatalog.page(before: selection) {
                    navigate(to: page.id)
                }
            } label: {
                Label(
                    DocumentationText.value("help.navigation.previous"),
                    systemImage: "chevron.up"
                )
            }
            .disabled(HelpCatalog.page(before: selection) == nil)
            .help(
                DocumentationText.value(
                    "help.navigation.previous.tooltip"
                )
            )

            Button {
                if let page = HelpCatalog.page(after: selection) {
                    navigate(to: page.id)
                }
            } label: {
                Label(
                    DocumentationText.value("help.navigation.next"),
                    systemImage: "chevron.down"
                )
            }
            .disabled(HelpCatalog.page(after: selection) == nil)
            .help(
                DocumentationText.value(
                    "help.navigation.next.tooltip"
                )
            )
        }
    }

    private var filteredPages: [HelpPage] {
        HelpCatalog.search(query)
    }

    private func navigate(
        to pageID: HelpPageID,
        recordingHistory: Bool = true
    ) {
        guard pageID != selection else { return }
        if recordingHistory {
            history.append(selection)
        }
        selection = pageID
    }

    private func goBack() {
        guard let pageID = history.popLast() else { return }
        navigate(to: pageID, recordingHistory: false)
    }
}
