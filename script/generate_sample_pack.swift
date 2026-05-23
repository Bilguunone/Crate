#!/usr/bin/env swift
//
//  generate_sample_pack.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let sampleRoot = root
    .appendingPathComponent("Samples", isDirectory: true)
    .appendingPathComponent("Crate Sample Paper Textures", isDirectory: true)

try FileManager.default.removeItemIfExists(at: sampleRoot)
try FileManager.default.createDirectory(at: sampleRoot, withIntermediateDirectories: true)

try drawPNG(
    at: sampleRoot.appendingPathComponent("paper-speckle.png"),
    size: CGSize(width: 360, height: 240),
    background: NSColor(calibratedRed: 0.94, green: 0.91, blue: 0.82, alpha: 1)
) { context, size in
    NSColor(calibratedRed: 0.35, green: 0.29, blue: 0.18, alpha: 0.25).setFill()
    for index in 0..<120 {
        let x = CGFloat((index * 37) % Int(size.width))
        let y = CGFloat((index * 61) % Int(size.height))
        let radius = CGFloat((index % 5) + 1)
        context.fillEllipse(in: CGRect(x: x, y: y, width: radius * 2, height: radius * 2))
    }

    NSColor(calibratedRed: 0.61, green: 0.47, blue: 0.25, alpha: 0.18).setStroke()
    let line = NSBezierPath()
    line.move(to: CGPoint(x: 28, y: 62))
    line.curve(to: CGPoint(x: 330, y: 156), controlPoint1: CGPoint(x: 105, y: 92), controlPoint2: CGPoint(x: 190, y: 22))
    line.lineWidth = 5
    line.stroke()
}

try drawPNG(
    at: sampleRoot.appendingPathComponent("paper-edge-alpha.png"),
    size: CGSize(width: 360, height: 240),
    background: .clear
) { context, size in
    NSColor(calibratedRed: 0.96, green: 0.92, blue: 0.83, alpha: 0.96).setFill()
    let paper = NSBezierPath()
    paper.move(to: CGPoint(x: 24, y: 58))
    paper.line(to: CGPoint(x: 95, y: 44))
    paper.line(to: CGPoint(x: 143, y: 72))
    paper.line(to: CGPoint(x: 218, y: 46))
    paper.line(to: CGPoint(x: 335, y: 82))
    paper.line(to: CGPoint(x: 319, y: 202))
    paper.line(to: CGPoint(x: 42, y: 190))
    paper.close()
    paper.fill()

    NSColor(calibratedRed: 0.32, green: 0.24, blue: 0.14, alpha: 0.34).setStroke()
    paper.lineWidth = 9
    paper.stroke()

    NSColor(calibratedRed: 0.78, green: 0.68, blue: 0.49, alpha: 0.28).setFill()
    context.fillEllipse(in: CGRect(x: 248, y: 118, width: 46, height: 19))
}

try drawPNG(
    at: sampleRoot.appendingPathComponent("fold-overlay.png"),
    size: CGSize(width: 360, height: 240),
    background: .clear
) { _, size in
    let highlight = NSGradient(colors: [
        NSColor(calibratedWhite: 1, alpha: 0),
        NSColor(calibratedWhite: 1, alpha: 0.82),
        NSColor(calibratedWhite: 0, alpha: 0.18),
        NSColor(calibratedWhite: 1, alpha: 0)
    ])!
    highlight.draw(in: NSRect(x: 30, y: 0, width: 95, height: size.height), angle: 15)
}

try drawJPG(
    at: sampleRoot.appendingPathComponent("fold-overlay.jpg"),
    size: CGSize(width: 360, height: 240),
    background: NSColor(calibratedWhite: 0.78, alpha: 1)
) { _, size in
    let highlight = NSGradient(colors: [
        NSColor(calibratedWhite: 0.55, alpha: 1),
        NSColor(calibratedWhite: 0.98, alpha: 1),
        NSColor(calibratedWhite: 0.42, alpha: 1)
    ])!
    highlight.draw(in: NSRect(x: 40, y: 0, width: 88, height: size.height), angle: 15)
}

try """
This is an intentionally ignored non-image file for Crate's sample import smoke test.
""".write(to: sampleRoot.appendingPathComponent("ignored-note.txt"), atomically: true, encoding: .utf8)

print("Generated sample pack at \(sampleRoot.path)")

func drawPNG(at url: URL, size: CGSize, background: NSColor, draw: (CGContext, CGSize) -> Void) throws {
    try drawBitmap(at: url, size: size, background: background, fileType: .png, properties: [:], draw: draw)
}

func drawJPG(at url: URL, size: CGSize, background: NSColor, draw: (CGContext, CGSize) -> Void) throws {
    try drawBitmap(
        at: url,
        size: size,
        background: background,
        fileType: .jpeg,
        properties: [.compressionFactor: 0.92],
        draw: draw
    )
}

func drawBitmap(
    at url: URL,
    size: CGSize,
    background: NSColor,
    fileType: NSBitmapImageRep.FileType,
    properties: [NSBitmapImageRep.PropertyKey: Any],
    draw: (CGContext, CGSize) -> Void
) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else {
        throw SampleGenerationError.bitmapCreationFailed
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    context.clear(CGRect(origin: .zero, size: size))
    background.setFill()
    context.fill(CGRect(origin: .zero, size: size))
    draw(context, size)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: fileType, properties: properties) else {
        throw SampleGenerationError.encodingFailed
    }
    try data.write(to: url, options: [.atomic])
}

enum SampleGenerationError: Error {
    case bitmapCreationFailed
    case encodingFailed
}

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
    }
}
