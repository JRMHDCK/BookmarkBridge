//
//  ChromeNativeIdentifierResolver.swift
//  BookmarkBridge
//

import Foundation

/// Single source of truth for Chrome native identity selection and canonical
/// representation. It never normalizes or invents a browser identifier.
nonisolated struct ChromeNativeIdentifierResolver: Sendable {
    func resolve(
        chromeID: String?,
        chromeGUID: String?
    ) throws -> ChromeNativeIdentifier {
        let validID = chromeID.flatMap(Self.validChromeID)
        if let validGUID = chromeGUID.flatMap(Self.validChromeGUID) {
            return ChromeNativeIdentifier(
                nativeIdentifier: Self.canonicalGUID(validGUID),
                kind: .chromeGUID,
                continuityIdentifier: validID.map(Self.canonicalID),
                continuityKind: validID == nil ? nil : .chromeIDFallback,
                chromeID: chromeID,
                chromeGUID: chromeGUID
            )
        }
        if let validID {
            return ChromeNativeIdentifier(
                nativeIdentifier: Self.canonicalID(validID),
                kind: .chromeIDFallback,
                continuityIdentifier: nil,
                continuityKind: nil,
                chromeID: chromeID,
                chromeGUID: chromeGUID
            )
        }
        throw ChromeNativeIdentifierError.noValidIdentifier(
            chromeID: chromeID,
            chromeGUID: chromeGUID
        )
    }

    private static func validChromeID(_ value: String) -> String? {
        guard !value.isEmpty,
              value.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }),
              UInt64(value) != nil else {
            return nil
        }
        return value
    }

    private static func validChromeGUID(_ value: String) -> String? {
        guard !value.isEmpty,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.contains(":"),
              value.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            return nil
        }
        return value
    }

    private static func canonicalID(_ value: String) -> NativeNodeIdentifier {
        NativeNodeIdentifier("id:\(value)")
    }

    private static func canonicalGUID(_ value: String) -> NativeNodeIdentifier {
        NativeNodeIdentifier("guid:\(value)")
    }
}
