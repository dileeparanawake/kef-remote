// Renders Design/AppIcon.svg into every macOS app icon size and writes the
// asset catalog's AppIcon.appiconset. Run with `make app-icon`.
//
// Each size is drawn from the vector source, not scaled down from 1024, so
// small sizes stay sharp. macOS's SVG renderer skips SVG filters, so the
// drop shadow in the source is drawn here with NSShadow instead.

import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("Usage: swift render-app-icon.swift <AppIcon.svg> <AppIcon.appiconset>")
    exit(1)
}
let sourceURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2], isDirectory: true)

guard let source = NSImage(contentsOf: sourceURL) else {
    print("Could not read \(sourceURL.path)")
    exit(1)
}

// The source's canvas, and its feDropShadow values, in that canvas's units.
let canvasSize: CGFloat = 1024
let shadowOffsetY: CGFloat = 12
let shadowStdDeviation: CGFloat = 14
let shadowOpacity: CGFloat = 0.28

// macOS icon slots: point size, at 1x and 2x.
let pointSizes = [16, 32, 128, 256, 512]
let scales = [1, 2]

func render(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { throw CocoaError(.fileWriteUnknown) }
    let side = CGFloat(pixels)
    let unit = side / canvasSize

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high

    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -shadowOffsetY * unit)
    // NSShadow's blur radius is about twice an SVG Gaussian's std deviation.
    shadow.shadowBlurRadius = 2 * shadowStdDeviation * unit
    shadow.shadowColor = NSColor.black.withAlphaComponent(shadowOpacity)
    shadow.set()
    source.draw(in: NSRect(x: 0, y: 0, width: side, height: side))

    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}

try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in pointSizes {
    for scale in scales {
        let suffix = scale == 1 ? "" : "@\(scale)x"
        let filename = "icon_\(points)x\(points)\(suffix).png"
        try render(pixels: points * scale).write(to: outputURL.appendingPathComponent(filename))
        images.append([
            "filename": filename,
            "idiom": "mac",
            "scale": "\(scale)x",
            "size": "\(points)x\(points)",
        ])
        print("Wrote \(filename)")
    }
}

let contents: [String: Any] = [
    "images": images,
    "info": ["author": "xcode", "version": 1],
]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputURL.appendingPathComponent("Contents.json"))
print("Wrote Contents.json")
