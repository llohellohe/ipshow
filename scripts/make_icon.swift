#!/usr/bin/env swift
//
// IPShow App Icon generator
// Usage:  swift scripts/make_icon.swift <output_dir>
//
// 设计：
//   - 蓝色径向渐变方形（macOS squircle 风格圆角）
//   - 中央白色地球（圆 + 经纬线）
//   - 三个对应通道颜色的发光定位点（青/紫/橙 = App/Shell/Direct）
//
import AppKit
import CoreGraphics
import Foundation

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath

// MARK: - Palette
let bgTop = NSColor(red: 0.23, green: 0.51, blue: 1.00, alpha: 1.0)   // #3B82FF
let bgBot = NSColor(red: 0.04, green: 0.20, blue: 0.62, alpha: 1.0)   // #0A339F
let earthFill   = NSColor(white: 1.0, alpha: 0.08)
let earthStroke = NSColor(white: 1.0, alpha: 0.95)
let pinColors: [NSColor] = [
    NSColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1.0),  // #5AC8FA App   (上)
    NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0),  // #AF52DE Shell (左下)
    NSColor(red: 1.00, green: 0.58, blue: 0.00, alpha: 1.0),  // #FF9500 Direct(右下)
]

// MARK: - Render

func renderIcon(pixelSize: Int) -> Data {
    let size = CGFloat(pixelSize)

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gc
    let ctx = gc.cgContext

    // 1. squircle 圆角 + 渐变
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.225
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    bgPath.addClip()
    let gradient = NSGradient(colors: [bgTop, bgBot])!
    gradient.draw(in: rect, angle: -90)

    // 顶部高光（提升立体感）
    let glossRect = CGRect(x: 0, y: size * 0.55, width: size, height: size * 0.45)
    let gloss = NSGradient(colors: [
        NSColor(white: 1.0, alpha: 0.18),
        NSColor(white: 1.0, alpha: 0.0)
    ])!
    gloss.draw(in: glossRect, angle: -90)

    // 2. 地球
    let center = CGPoint(x: size / 2, y: size / 2)
    let er = size * 0.30
    let lineWide = max(1.0, size * 0.018)
    let lineThin = max(0.6, size * 0.011)

    // 半透明地球底
    ctx.setFillColor(earthFill.cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - er, y: center.y - er, width: er * 2, height: er * 2))

    // 外圈
    ctx.setStrokeColor(earthStroke.cgColor)
    ctx.setLineWidth(lineWide)
    ctx.strokeEllipse(in: CGRect(x: center.x - er, y: center.y - er, width: er * 2, height: er * 2))

    // 经线：3 条不同弧度椭圆
    ctx.setLineWidth(lineThin)
    for ratio in [0.32, 0.66, 1.0] as [CGFloat] {
        let w = er * 2 * ratio
        ctx.strokeEllipse(in: CGRect(x: center.x - w / 2, y: center.y - er, width: w, height: er * 2))
    }

    // 赤道
    ctx.setLineWidth(lineWide)
    ctx.move(to: CGPoint(x: center.x - er, y: center.y))
    ctx.addLine(to: CGPoint(x: center.x + er, y: center.y))
    ctx.strokePath()

    // 一条额外纬线
    ctx.setLineWidth(lineThin)
    let arcOffset = er * 0.45
    let arcW = er * 0.88
    ctx.move(to: CGPoint(x: center.x - arcW, y: center.y + arcOffset))
    ctx.addCurve(
        to: CGPoint(x: center.x + arcW, y: center.y + arcOffset),
        control1: CGPoint(x: center.x - arcW * 0.4, y: center.y + arcOffset * 0.55),
        control2: CGPoint(x: center.x + arcW * 0.4, y: center.y + arcOffset * 0.55)
    )
    ctx.strokePath()

    // 3. 三个定位点
    let pinDist = er * 1.08
    let pinR = size * 0.062
    let angles: [Double] = [90, 210, 330]

    for (i, deg) in angles.enumerated() {
        let rad = deg * .pi / 180
        let px = center.x + CGFloat(cos(rad)) * pinDist
        let py = center.y + CGFloat(sin(rad)) * pinDist

        // 外光晕（柔化）
        let haloColor = pinColors[i].withAlphaComponent(0.28).cgColor
        ctx.setFillColor(haloColor)
        ctx.fillEllipse(in: CGRect(
            x: px - pinR * 1.8, y: py - pinR * 1.8,
            width: pinR * 3.6, height: pinR * 3.6
        ))

        // 中层
        ctx.setFillColor(pinColors[i].withAlphaComponent(0.55).cgColor)
        ctx.fillEllipse(in: CGRect(
            x: px - pinR * 1.25, y: py - pinR * 1.25,
            width: pinR * 2.5, height: pinR * 2.5
        ))

        // 实心
        ctx.setFillColor(pinColors[i].cgColor)
        ctx.fillEllipse(in: CGRect(
            x: px - pinR, y: py - pinR,
            width: pinR * 2, height: pinR * 2
        ))

        // 高光小圆
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
        let hr = pinR * 0.32
        ctx.fillEllipse(in: CGRect(
            x: px - hr - pinR * 0.18, y: py + pinR * 0.18 - hr,
            width: hr * 2, height: hr * 2
        ))
    }

    return rep.representation(using: .png, properties: [:])!
}

// MARK: - Output specs

let specs: [(String, Int)] = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024),
]

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for (name, size) in specs {
    let data = renderIcon(pixelSize: size)
    let path = "\(outputDir)/\(name)"
    try? data.write(to: URL(fileURLWithPath: path))
    print("✓ \(name)  (\(size)x\(size), \(data.count) bytes)")
}
print("Done.")
