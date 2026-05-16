import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func drawIcon(size: CGFloat, dark: Bool, tinted: Bool) -> NSImage {
    let image = NSImage(size: CGSize(width: size, height: size))
    image.lockFocus()

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let base = tinted
        ? NSColor(calibratedRed: 0.92, green: 0.98, blue: 0.97, alpha: 1)
        : dark
            ? NSColor(calibratedRed: 0.035, green: 0.039, blue: 0.055, alpha: 1)
            : NSColor(calibratedRed: 0.043, green: 0.049, blue: 0.071, alpha: 1)
    base.setFill()
    rect.fill()

    let glow = NSGradient(colors: [
        NSColor(calibratedRed: 0.09, green: 0.74, blue: 0.72, alpha: tinted ? 0.45 : 0.82),
        NSColor(calibratedRed: 0.45, green: 0.35, blue: 0.95, alpha: tinted ? 0.24 : 0.58),
        NSColor(calibratedRed: 0.96, green: 0.25, blue: 0.58, alpha: tinted ? 0.20 : 0.46)
    ])
    glow?.draw(in: rect, angle: 42)

    let auraRect = rect.insetBy(dx: size * 0.135, dy: size * 0.135)
    let auraPath = NSBezierPath(ovalIn: auraRect)
    NSColor.white.withAlphaComponent(tinted ? 0.45 : 0.15).setStroke()
    auraPath.lineWidth = size * 0.03
    auraPath.stroke()

    let coreRect = rect.insetBy(dx: size * 0.22, dy: size * 0.22)
    let corePath = NSBezierPath(ovalIn: coreRect)
    NSColor(calibratedRed: 0.035, green: 0.039, blue: 0.055, alpha: tinted ? 0.10 : 0.78).setFill()
    corePath.fill()

    let letterColor = tinted
        ? NSColor(calibratedRed: 0.04, green: 0.18, blue: 0.18, alpha: 1)
        : NSColor.white
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.47, weight: .black),
        .foregroundColor: letterColor,
        .paragraphStyle: paragraph,
        .kern: -size * 0.018
    ]

    let textRect = CGRect(x: 0, y: size * 0.255, width: size, height: size * 0.52)
    NSString(string: "A").draw(in: textRect, withAttributes: attributes)

    let sparkRect = CGRect(x: size * 0.66, y: size * 0.66, width: size * 0.115, height: size * 0.115)
    let sparkPath = NSBezierPath(ovalIn: sparkRect)
    NSColor.white.withAlphaComponent(tinted ? 0.72 : 0.95).setFill()
    sparkPath.fill()

    image.unlockFocus()
    return image
}

func write(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let source = NSBitmapImageRep(data: tiff),
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1024,
            pixelsHigh: 1024,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else {
        throw CocoaError(.fileWriteUnknown)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    source.draw(in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }

    try png.write(to: url)
}

try write(drawIcon(size: 1024, dark: false, tinted: false), to: output.appendingPathComponent("AppIcon.png"))
try write(drawIcon(size: 1024, dark: true, tinted: false), to: output.appendingPathComponent("AppIcon-Dark.png"))
try write(drawIcon(size: 1024, dark: false, tinted: true), to: output.appendingPathComponent("AppIcon-Tinted.png"))
