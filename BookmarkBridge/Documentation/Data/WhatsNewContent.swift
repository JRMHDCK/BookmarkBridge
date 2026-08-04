//
//  WhatsNewContent.swift
//  BookmarkBridge
//

enum WhatsNewContent {
    static let current = WhatsNewRelease(
        version: "0.9.1",
        build: "1",
        sections: [
            WhatsNewSection(
                id: "features",
                titleKey: "whatsNew.features.title",
                systemImage: "sparkles",
                itemKeys: [
                    "whatsNew.features.sync",
                    "whatsNew.features.explorer",
                    "whatsNew.features.help",
                ]
            ),
            WhatsNewSection(
                id: "fixes",
                titleKey: "whatsNew.fixes.title",
                systemImage: "checkmark.seal",
                itemKeys: [
                    "whatsNew.fixes.idempotence",
                    "whatsNew.fixes.restore",
                    "whatsNew.fixes.permissions",
                ]
            ),
            WhatsNewSection(
                id: "improvements",
                titleKey: "whatsNew.improvements.title",
                systemImage: "wand.and.stars",
                itemKeys: [
                    "whatsNew.improvements.native",
                    "whatsNew.improvements.qa",
                    "whatsNew.improvements.packaging",
                ]
            ),
        ]
    )
}
