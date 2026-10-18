// Renders the Susurramelo app icon (1024×1024 PNG).
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "icon.png"

// Draw into an explicit 1024 px bitmap so the output does not depend on the screen's scale.
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let context = NSGraphicsContext.current!.cgContext

// macOS icon grid: the shape sits inside a 824 pt square with ~22% corner radius.
let inset: CGFloat = 100
let shapeRect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let shape = NSBezierPath(roundedRect: shapeRect, xRadius: 185, yRadius: 185)

// Soft drop shadow under the tile.
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.black.setFill()
shape.fill()
context.restoreGState()

// Background gradient: indigo → violet → warm pink.
NSGraphicsContext.saveGraphicsState()
shape.addClip()
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.23, green: 0.24, blue: 0.78, alpha: 1),
    NSColor(srgbRed: 0.52, green: 0.27, blue: 0.86, alpha: 1),
    NSColor(srgbRed: 0.93, green: 0.42, blue: 0.62, alpha: 1),
])!
gradient.draw(in: shapeRect, angle: -55)

// Subtle top highlight for depth.
let highlight = NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
highlight.draw(in: CGRect(x: shapeRect.minX, y: shapeRect.midY, width: shapeRect.width, height: shapeRect.height / 2), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// Voice waveform: symmetric rounded bars, tallest in the middle.
let heights: [CGFloat] = [0.20, 0.38, 0.62, 0.86, 0.62, 0.38, 0.20]
let barWidth: CGFloat = 58
let gap: CGFloat = 34
let maxHeight: CGFloat = 470
let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
var x = (size - totalWidth) / 2
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: NSColor.black.withAlphaComponent(0.25).cgColor)
NSColor.white.setFill()
for h in heights {
    let barHeight = maxHeight * h
    let bar = NSBezierPath(
        roundedRect: CGRect(x: x, y: (size - barHeight) / 2, width: barWidth, height: barHeight),
        xRadius: barWidth / 2,
        yRadius: barWidth / 2
    )
    bar.fill()
    x += barWidth + gap
}
context.restoreGState()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
