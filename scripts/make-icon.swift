import AppKit

// Small vector-drawn notebook icon; no external image or asset dependency.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels,
            pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.19, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904),
            xRadius: 204, yRadius: 204).fill()
        NSColor(calibratedRed: 0.45, green: 0.89, blue: 0.72, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 270, y: 224, width: 484, height: 576),
            xRadius: 48, yRadius: 48).fill()
        NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.21, alpha: 1).setStroke()
        for (y, width) in [(648.0, 280.0), (520.0, 280.0), (392.0, 184.0)] {
            let line = NSBezierPath()
            line.lineWidth = 36
            line.lineCapStyle = .round
            line.move(to: NSPoint(x: 364, y: y))
            line.line(to: NSPoint(x: 364 + width, y: y))
            line.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let data = bitmap.representation(using: .png, properties: [:])!
        try data.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
