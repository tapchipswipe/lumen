#!/usr/bin/env swift
import AppKit

let sizes: [(String, CGFloat, CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

let tempIconset = URL(fileURLWithPath: "/tmp/LumenIcon.iconset")
try? FileManager.default.removeItem(at: tempIconset)
try! FileManager.default.createDirectory(at: tempIconset, withIntermediateDirectories: true)

for (filename, ptSize, scale) in sizes {
    let pixelSize = ptSize * scale
    let img = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { continue }

    ctx.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))

    // Rounded rectangle squircle
    let margin = pixelSize * 0.08
    let iconRect = CGRect(x: margin, y: margin, width: pixelSize - 2*margin, height: pixelSize - 2*margin)
    let cornerRadius = iconRect.width * 0.224
    let path = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -pixelSize * 0.04), blur: pixelSize * 0.08, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
    ctx.addPath(path)
    ctx.setFillColor(CGColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // Background Gradient (Obsidian to Deep Cosmic Blue)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.12, green: 0.15, blue: 0.24, alpha: 1.0),
        CGColor(red: 0.06, green: 0.08, blue: 0.13, alpha: 1.0)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: iconRect.midX, y: iconRect.maxY), end: CGPoint(x: iconRect.midX, y: iconRect.minY), options: [])
    }

    // Border stroke
    ctx.setLineWidth(max(1.0, pixelSize * 0.015))
    ctx.setStrokeColor(CGColor(red: 0.35, green: 0.55, blue: 1.0, alpha: 0.35))
    ctx.addPath(path)
    ctx.strokePath()

    // Inner subtle glow
    let glowColors = [
        CGColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 0.25),
        CGColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 0.0)
    ] as CFArray
    if let radial = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(radial, startCenter: CGPoint(x: iconRect.midX, y: iconRect.midY), startRadius: 0, endCenter: CGPoint(x: iconRect.midX, y: iconRect.midY), endRadius: iconRect.width * 0.5, options: [])
    }
    ctx.restoreGState()

    // Bolt Icon (SF Symbol bolt.fill)
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: iconRect.width * 0.55, weight: .bold)
    if let sym = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?.withSymbolConfiguration(symbolConfig) {
        let symSize = sym.size
        let symRect = CGRect(
            x: iconRect.midX - symSize.width / 2,
            y: iconRect.midY - symSize.height / 2,
            width: symSize.width,
            height: symSize.height
        )

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -pixelSize * 0.02), blur: pixelSize * 0.06, color: CGColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 0.6))
        
        if let tintImg = NSImage(size: symSize, flipped: false, drawingHandler: { rect in
            sym.draw(in: rect)
            return true
        }).cgImage(forProposedRect: nil, context: nil, hints: nil) {
            ctx.saveGState()
            ctx.clip(to: symRect, mask: tintImg)
            let boltColors = [
                CGColor(red: 1.00, green: 0.84, blue: 0.25, alpha: 1.0), // Bright Gold
                CGColor(red: 0.96, green: 0.58, blue: 0.10, alpha: 1.0)  // Deep Amber
            ] as CFArray
            if let boltGrad = CGGradient(colorsSpace: colorSpace, colors: boltColors, locations: [0.0, 1.0]) {
                ctx.drawLinearGradient(boltGrad, start: CGPoint(x: symRect.midX, y: symRect.maxY), end: CGPoint(x: symRect.midX, y: symRect.minY), options: [])
            }
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    img.unlockFocus()

    if let tiff = img.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let pngData = bitmap.representation(using: .png, properties: [:]) {
        let fileURL = tempIconset.appendingPathComponent(filename)
        try! pngData.write(to: fileURL)
    }
}

let targetIcns = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", tempIconset.path, "-o", targetIcns.path]
try! process.run()
process.waitUntilExit()

print("Generated \(targetIcns.path)")
