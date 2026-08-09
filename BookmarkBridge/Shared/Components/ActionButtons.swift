//
//  ActionButtons.swift
//  BookmarkBridge
//

import SwiftUI

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            buttonLabel
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.accentColor)
        .frame(minHeight: Theme.Size.minimumInteractive)
    }

    @ViewBuilder
    private var buttonLabel: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

struct SecondaryActionButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .frame(minHeight: Theme.Size.minimumInteractive)
    }
}
