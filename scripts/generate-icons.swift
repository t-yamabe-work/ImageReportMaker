#!/usr/bin/env swift
// =========================================================
// 画像報告書メーカー — 仮アイコン生成
// 青背景に白文字「画報」を描画した PNG を AppIcon.appiconset に出力する
// 本格アイコンは v1.0.0 で差し替え予定
// =========================================================
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let fm = FileManager.default
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let iconSetDir = repoRoot
    .appendingPathComponent("Apps/ImageReportMaker/Resources/Assets.xcassets/AppIcon.appiconset")

try? fm.createDirectory(at: iconSetDir, withIntermediateDirectories: true)

struct IconSpec {
    let size: Int       // 実ピクセルサイズ
    let fileName: String
}

// Xcode macOS AppIcon が要求する10バリエーション
let specs: [IconSpec] = [
    .init(size: 16,   fileName: "icon_16x16.png"),
    .init(size: 32,   fileName: "icon_16x16@2x.png"),
    .init(size: 32,   fileName: "icon_32x32.png"),
    .init(size: 64,   fileName: "icon_32x32@2x.png"),
    .init(size: 128,  fileName: "icon_128x128.png"),
    .init(size: 256,  fileName: "icon_128x128@2x.png"),
    .init(size: 256,  fileName: "icon_256x256.png"),
    .init(size: 512,  fileName: "icon_256x256@2x.png"),
    .init(size: 512,  fileName: "icon_512x512.png"),
    .init(size: 1024, fileName: "icon_512x512@2x.png"),
]

func renderIcon(size: Int) -> CGImage? {
    let px = size
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: px, height: px,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let rect = CGRect(x: 0, y: 0, width: px, height: px)

    // 背景：角丸矩形 濃紺→青のグラデ
    let cornerRadius = CGFloat(px) * 0.2237 // macOS squircle比
    let clipPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(clipPath)
    ctx.clip()

    let colors = [
        CGColor(red: 0.12, green: 0.28, blue: 0.58, alpha: 1.0),
        CGColor(red: 0.22, green: 0.52, blue: 0.85, alpha: 1.0)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: CGFloat(px)),
            end: CGPoint(x: CGFloat(px), y: 0),
            options: []
        )
    }

    // テキスト「画報」
    let text = "画報"
    let fontSize = CGFloat(px) * 0.46
    let font = NSFont(name: "HiraginoSans-W6", size: fontSize)
        ?? NSFont.boldSystemFont(ofSize: fontSize)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
        .kern: -fontSize * 0.05
    ]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let textSize = attributed.size()
    let textRect = CGRect(
        x: (CGFloat(px) - textSize.width) / 2,
        y: (CGFloat(px) - textSize.height) / 2 - CGFloat(px) * 0.02,
        width: textSize.width,
        height: textSize.height
    )

    let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsContext
    attributed.draw(in: textRect)
    NSGraphicsContext.restoreGraphicsState()

    ctx.restoreGState()

    // うっすら縁
    ctx.addPath(clipPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
    ctx.setLineWidth(CGFloat(px) * 0.01)
    ctx.strokePath()

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        throw NSError(domain: "icon", code: 1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        throw NSError(domain: "icon", code: 2)
    }
}

var generated: [String] = []
for spec in specs {
    guard let image = renderIcon(size: spec.size) else {
        FileHandle.standardError.write("failed to render \(spec.fileName)\n".data(using: .utf8)!)
        exit(1)
    }
    let out = iconSetDir.appendingPathComponent(spec.fileName)
    try writePNG(image, to: out)
    generated.append(spec.fileName)
}

print("generated \(generated.count) icons at \(iconSetDir.path)")
