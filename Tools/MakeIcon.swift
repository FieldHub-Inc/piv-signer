#!/usr/bin/env swift
import AppKit
import CoreGraphics

// PIV Signer app icon: round seal with calligraphic "P" and chip-contact dots.
// Renders directly via Core Graphics — pixel-perfect at every macOS icon size.

func drawIcon(size s: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    defer { img.unlockFocus() }
    guard let ctx = NSGraphicsContext.current?.cgContext else { return img }

    let center = CGPoint(x: s / 2, y: s / 2)

    // 1. Background squircle with deep navy gradient
    let cornerR = s * 0.2237
    let bgPath = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
        cornerWidth: cornerR, cornerHeight: cornerR, transform: nil
    )
    ctx.saveGState()
    ctx.addPath(bgPath); ctx.clip()
    drawLinearGradient(
        ctx, from: CGPoint(x: 0, y: s), to: .zero,
        stops: [
            (0.0, color(0x2A3A5F)),
            (0.55, color(0x182648)),
            (1.0, color(0x0E1830)),
        ]
    )
    drawLinearGradient(
        ctx, from: CGPoint(x: 0, y: s), to: CGPoint(x: 0, y: s * 0.45),
        stops: [
            (0.0, color(0xFFFFFF, alpha: 0.08)),
            (1.0, color(0xFFFFFF, alpha: 0.0)),
        ]
    )
    ctx.restoreGState()

    // 2. Gold seal ring with contact dots
    let ringR = s * 0.34
    let ringW = s * 0.045
    let goldLight = color(0xE9C76A)
    let goldDeep = color(0x8C6B1A)
    let goldDarker = color(0x4D3A0A)

    // soft outer shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.006), blur: s * 0.02,
                  color: color(0x000000, alpha: 0.45))
    strokeRing(ctx, center: center, radius: ringR, lineWidth: ringW, color: goldDeep)
    ctx.restoreGState()

    // gold ring with vertical metallic gradient
    ctx.saveGState()
    let ringRect = CGRect(
        x: center.x - ringR - ringW, y: center.y - ringR - ringW,
        width: (ringR + ringW) * 2, height: (ringR + ringW) * 2
    )
    let ringPath = CGMutablePath()
    ringPath.addArc(center: center, radius: ringR + ringW / 2, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ringPath.addArc(center: center, radius: ringR - ringW / 2, startAngle: 0, endAngle: .pi * 2, clockwise: true)
    ctx.addPath(ringPath); ctx.clip()
    drawLinearGradient(
        ctx, from: CGPoint(x: 0, y: ringRect.maxY), to: CGPoint(x: 0, y: ringRect.minY),
        stops: [
            (0.0, color(0xF6DA8E)),
            (0.45, goldLight),
            (0.55, color(0xC59A3A)),
            (1.0, goldDeep),
        ]
    )
    ctx.restoreGState()

    // contact dots embedded on the ring (12 dots)
    let dotCount = 12
    let dotR = s * 0.022
    for i in 0..<dotCount {
        let angle = (CGFloat(i) / CGFloat(dotCount)) * .pi * 2 - .pi / 2
        let p = CGPoint(
            x: center.x + cos(angle) * ringR,
            y: center.y + sin(angle) * ringR
        )
        ctx.addArc(center: p, radius: dotR, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.setFillColor(goldDarker); ctx.fillPath()
        ctx.addArc(center: p, radius: dotR * 0.55, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.setFillColor(color(0xF8E9B0)); ctx.fillPath()
    }

    // 3. Inner disc behind the P (slightly darker than background — gives depth)
    let discR = ringR - ringW * 1.4
    ctx.saveGState()
    ctx.addArc(center: center, radius: discR, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.clip()
    drawRadialGradient(
        ctx, center: center, innerRadius: 0, outerRadius: discR,
        stops: [
            (0.0, color(0x1F2C50)),
            (1.0, color(0x0B1326)),
        ]
    )
    ctx.restoreGState()
    // subtle inner ring shadow on the disc
    ctx.saveGState()
    ctx.addArc(center: center, radius: discR, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.setStrokeColor(color(0x000000, alpha: 0.5))
    ctx.setLineWidth(s * 0.006)
    ctx.strokePath()
    ctx.restoreGState()

    // 4. Calligraphic "P"
    let pColor = color(0xF6E6C0)
    drawGlyphP(ctx, center: center, size: s, color: pColor)

    return img
}

// MARK: - P glyph

private func drawGlyphP(_ ctx: CGContext, center: CGPoint, size s: CGFloat, color: CGColor) {
    let font = NSFont(name: "SnellRoundhand-Black", size: s * 0.56)
        ?? NSFont(name: "SnellRoundhand-Bold", size: s * 0.56)
        ?? NSFont(name: "Apple Chancery", size: s * 0.5)
        ?? NSFont.systemFont(ofSize: s * 0.5, weight: .heavy)

    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: color) ?? .white,
    ]
    let str = NSAttributedString(string: "P", attributes: attrs)

    // measure tightly via CTLine
    let line = CTLineCreateWithAttributedString(str)
    let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])

    let drawX = center.x - bounds.midX
    let drawY = center.y - bounds.midY - s * 0.015

    // soft drop shadow under the glyph
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.008), blur: s * 0.025,
                  color: NSColor.black.withAlphaComponent(0.55).cgColor)
    ctx.textPosition = CGPoint(x: drawX, y: drawY)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

// MARK: - Helpers

private func color(_ hex: UInt32, alpha: CGFloat = 1.0) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    return CGColor(red: r, green: g, blue: b, alpha: alpha)
}

private func drawLinearGradient(
    _ ctx: CGContext, from: CGPoint, to: CGPoint,
    stops: [(CGFloat, CGColor)]
) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let colors = stops.map { $0.1 } as CFArray
    let locs = stops.map { $0.0 }
    let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: locs)!
    ctx.drawLinearGradient(gradient, start: from, end: to, options: [])
}

private func drawRadialGradient(
    _ ctx: CGContext, center: CGPoint,
    innerRadius: CGFloat, outerRadius: CGFloat,
    stops: [(CGFloat, CGColor)]
) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let colors = stops.map { $0.1 } as CFArray
    let locs = stops.map { $0.0 }
    let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: locs)!
    ctx.drawRadialGradient(
        gradient,
        startCenter: center, startRadius: innerRadius,
        endCenter: center, endRadius: outerRadius,
        options: []
    )
}

private func strokeRing(_ ctx: CGContext, center: CGPoint, radius: CGFloat, lineWidth: CGFloat, color: CGColor) {
    ctx.saveGState()
    ctx.setStrokeColor(color)
    ctx.setLineWidth(lineWidth)
    ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - PNG output

private func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "MakeIcon", code: 1)
    }
    try png.write(to: url)
}

// MARK: - Entry

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for entry in sizes {
    let img = drawIcon(size: CGFloat(entry.px))
    let url = outDir.appendingPathComponent(entry.name)
    do {
        try savePNG(img, to: url)
        FileHandle.standardOutput.write(Data("✓ \(entry.name) (\(entry.px)px)\n".utf8))
    } catch {
        FileHandle.standardError.write(Data("✗ \(entry.name): \(error)\n".utf8))
        exit(1)
    }
}
