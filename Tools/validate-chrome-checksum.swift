#!/usr/bin/env swift
//
//  validate-chrome-checksum.swift
//  BookmarkBridge — sync validation tool
//
//  Verifies that our Chrome checksum algorithm matches the one a REAL Chrome
//  wrote into a Bookmarks file, and (optionally) produces a modified copy so you
//  can confirm Chrome accepts a written file.
//
//  SAFETY:
//  - Run it ONLY against a THROWAWAY test profile. Never your real favourites.
//  - "verify" mode is strictly READ-ONLY (opens the input for reading only).
//  - "--make-modified-copy" writes ONLY to the explicit output path you give,
//    never to the input. It refuses if output == input.
//
//  Usage:
//    swift Tools/validate-chrome-checksum.swift "<path-to-TEST-profile/Bookmarks>"
//    swift Tools/validate-chrome-checksum.swift "<path-to-TEST-profile/Bookmarks>" --make-modified-copy /tmp/Bookmarks.new
//
//  The checksum logic below mirrors Core/Services/Writing/ChromeChecksum.swift
//  exactly. If "verify" prints MATCH, the app's algorithm is correct.
//

import Foundation
import CryptoKit

// MARK: - Checksum (mirror of ChromeChecksum)

let rootOrder = ["bookmark_bar", "other", "synced"]

func updateChecksum(_ md5: inout Insecure.MD5, node: [String: Any]) {
    let id = node["id"] as? String ?? ""
    let title = node["name"] as? String ?? ""
    let type = node["type"] as? String ?? ""
    md5.update(data: Data(id.utf8))
    md5.update(data: title.data(using: .utf16LittleEndian) ?? Data())   // Chromium hashes UTF-16 bytes
    md5.update(data: Data(type.utf8))
    if type == "url" {
        md5.update(data: Data((node["url"] as? String ?? "").utf8))
    } else {
        for child in (node["children"] as? [[String: Any]]) ?? [] {
            updateChecksum(&md5, node: child)
        }
    }
}

func computeChecksum(roots: [String: Any]) -> String {
    var md5 = Insecure.MD5()
    for key in rootOrder {
        if let root = roots[key] as? [String: Any] { updateChecksum(&md5, node: root) }
    }
    return md5.finalize().map { String(format: "%02x", $0) }.joined()
}

// MARK: - Minimal writer (mirror of ChromeBookmarkWriter, for the optional copy)

func maxID(in roots: [String: Any]) -> Int64 {
    var maximum: Int64 = 0
    func visit(_ node: [String: Any]) {
        if let s = node["id"] as? String, let n = Int64(s) { maximum = max(maximum, n) }
        for child in (node["children"] as? [[String: Any]]) ?? [] { visit(child) }
    }
    for value in roots.values { if let node = value as? [String: Any] { visit(node) } }
    return maximum
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: swift Tools/validate-chrome-checksum.swift <Bookmarks path> [--make-modified-copy <output>]")
    exit(2)
}
let inputPath = args[1]
let inputURL = URL(fileURLWithPath: inputPath)

guard let data = try? Data(contentsOf: inputURL) else {
    print("❌ Cannot read: \(inputPath)")
    exit(1)
}
guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let roots = object["roots"] as? [String: Any] else {
    print("❌ Not a valid Chrome Bookmarks file (missing 'roots').")
    exit(1)
}

let stored = object["checksum"] as? String ?? "(none)"
let computed = computeChecksum(roots: roots)

print("File     : \(inputPath)")
print("Stored   : \(stored)")
print("Computed : \(computed)")
if stored.lowercased() == computed {
    print("✅ MATCH — our checksum algorithm reproduces Chrome's. Safe to write.")
} else {
    print("❌ MISMATCH — the algorithm does not match this Chrome file yet.")
}

// Optional: produce a modified copy (adds one dummy bookmark) to a NEW path only.
if let flagIndex = args.firstIndex(of: "--make-modified-copy") {
    guard flagIndex + 1 < args.count else {
        print("❌ --make-modified-copy requires an output path.")
        exit(2)
    }
    let outputPath = args[flagIndex + 1]
    guard URL(fileURLWithPath: outputPath).standardizedFileURL != inputURL.standardizedFileURL else {
        print("❌ Refusing: output path equals the input. Choose a different file.")
        exit(2)
    }

    var mutableObject = object
    var mutableRoots = roots
    guard var other = mutableRoots["other"] as? [String: Any] else {
        print("❌ No 'other' root to add into.")
        exit(1)
    }
    var children = (other["children"] as? [[String: Any]]) ?? []
    let newID = maxID(in: roots) + 1
    let microseconds = Int64((Date().timeIntervalSince1970 + 11_644_473_600) * 1_000_000)
    children.append([
        "type": "url",
        "id": String(newID),
        "guid": UUID().uuidString.lowercased(),
        "name": "BookmarkBridge test — safe to delete",
        "url": "https://example.com/bookmarkbridge-write-test",
        "date_added": String(microseconds),
    ])
    other["children"] = children
    mutableRoots["other"] = other
    mutableObject["roots"] = mutableRoots
    mutableObject["checksum"] = computeChecksum(roots: mutableRoots)

    let outData = try! JSONSerialization.data(withJSONObject: mutableObject, options: [.sortedKeys])
    try! outData.write(to: URL(fileURLWithPath: outputPath))
    print("")
    print("📝 Wrote a modified copy (one extra test bookmark) to: \(outputPath)")
    print("   To end-to-end test: QUIT Chrome, back up the TEST profile's Bookmarks,")
    print("   copy this file over it, reopen Chrome on the TEST profile, and check that")
    print("   all bookmarks + the test one appear with no 'reset' warning.")
}
