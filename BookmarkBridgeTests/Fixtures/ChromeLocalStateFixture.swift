//
//  ChromeLocalStateFixture.swift
//  BookmarkBridgeTests
//
//  Programmatically generated, anonymized Chrome `Local State` (JSON). It maps
//  profile directory names to user-facing names via `profile.info_cache`.
//  Profile names are neutral placeholders — no personal data.
//

import Foundation

enum ChromeLocalStateFixture {

    enum Expected {
        static let defaultDir = "Default"
        static let defaultName = "Personnel"
        static let secondDir = "Profile 1"
        static let secondName = "Travail"
    }

    static func propertyList() -> [String: Any] {
        [
            "profile": [
                "info_cache": [
                    Expected.defaultDir: [
                        "name": Expected.defaultName,
                        "is_using_default_name": false,
                    ],
                    Expected.secondDir: [
                        "name": Expected.secondName,
                        "is_using_default_name": false,
                    ],
                ],
                "last_used": Expected.defaultDir,
                "profiles_order": [Expected.defaultDir, Expected.secondDir],
            ],
        ]
    }

    static func data() throws -> Data {
        try JSONSerialization.data(fromPropertyListCompatible: propertyList())
    }
}
