#!/usr/bin/env swift

import AppKit
import Foundation

private enum Background {
    static let size = NSSize(width: 660, height: 420)
    static let logoRect = NSRect(x: 296, y: 310, width: 68, height: 68)
    static let titleRect = NSRect(x: 80, y: 267, width: 500, height: 34)
    static let instructionRect = NSRect(x: 80, y: 240, width: 500, height: 24)
}

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(
        Data("Usage: generate-background.swift ICON OUTPUT\n".utf8)
    )
    exit(64)
}

let iconURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let icon = NSImage(contentsOf: iconURL) else {
    FileHandle.standardError.write(
        Data("Unable to load official icon at \(iconURL.path)\n".utf8)
    )
    exit(66)
}

let image = NSImage(size: Background.size)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    FileHandle.standardError.write(
        Data("Unable to create drawing context\n".utf8)
    )
    exit(70)
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
    ?? CGColorSpaceCreateDeviceRGB()
let colors = [
    NSColor(
        calibratedRed: 0.975,
        green: 0.982,
        blue: 0.992,
        alpha: 1
    ).cgColor,
    NSColor(
        calibratedRed: 0.925,
        green: 0.945,
        blue: 0.970,
        alpha: 1
    ).cgColor,
] as CFArray
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: colors,
    locations: [0, 1]
)
if let gradient {
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: Background.size.height),
        end: CGPoint(x: Background.size.width, y: 0),
        options: []
    )
}

context.saveGState()
context.setFillColor(
    NSColor(
        calibratedRed: 0.05,
        green: 0.45,
        blue: 0.95,
        alpha: 0.10
    ).cgColor
)
context.fillEllipse(
    in: CGRect(x: 45, y: 50, width: 290, height: 290)
)
context.setFillColor(
    NSColor(
        calibratedRed: 0.18,
        green: 0.78,
        blue: 0.30,
        alpha: 0.09
    ).cgColor
)
context.fillEllipse(
    in: CGRect(x: 340, y: 35, width: 285, height: 285)
)
context.restoreGState()

NSGraphicsContext.current?.imageInterpolation = .high
context.saveGState()
let iconMask = NSBezierPath(
    roundedRect: Background.logoRect,
    xRadius: 15,
    yRadius: 15
)
iconMask.addClip()
icon.draw(
    in: Background.logoRect,
    from: .zero,
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
)
context.restoreGState()

let centeredParagraph = NSMutableParagraphStyle()
centeredParagraph.alignment = .center

NSAttributedString(
    string: "BookmarkBridge",
    attributes: [
        .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
        .foregroundColor: NSColor(
            calibratedWhite: 0.10,
            alpha: 1
        ),
        .paragraphStyle: centeredParagraph,
    ]
).draw(in: Background.titleRect)

NSAttributedString(
    string: "Glissez BookmarkBridge dans Applications",
    attributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .regular),
        .foregroundColor: NSColor(
            calibratedWhite: 0.24,
            alpha: 0.78
        ),
        .paragraphStyle: centeredParagraph,
    ]
).draw(in: Background.instructionRect)

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 285, y: 142))
arrowPath.line(to: NSPoint(x: 375, y: 142))
arrowPath.move(to: NSPoint(x: 358, y: 157))
arrowPath.line(to: NSPoint(x: 375, y: 142))
arrowPath.line(to: NSPoint(x: 358, y: 127))
arrowPath.lineWidth = 2.5
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
NSColor(calibratedWhite: 0.24, alpha: 0.48).setStroke()
arrowPath.stroke()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(
        using: .png,
        properties: [.compressionFactor: 0.9]
    )
else {
    FileHandle.standardError.write(
        Data("Unable to encode background as PNG\n".utf8)
    )
    exit(74)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL, options: .atomic)
