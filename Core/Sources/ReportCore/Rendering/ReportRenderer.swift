import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

public enum ExportFormat: String, Sendable {
    case jpg
    case png
    case svg
}

public struct RenderOptions: Sendable {
    public let format: ExportFormat
    public let dpi: Double
    public let jpegQuality: Double

    public init(format: ExportFormat, dpi: Double = 150.0, jpegQuality: Double = 0.92) {
        self.format = format
        self.dpi = dpi
        self.jpegQuality = jpegQuality
    }

    /// 書き出し用プリセット（150dpi、高品質）。
    public static func export(format: ExportFormat, jpegQuality: Double = 0.92) -> RenderOptions {
        RenderOptions(format: format, dpi: 150.0, jpegQuality: jpegQuality)
    }

    /// プレビュー用プリセット（72dpi、ウィンドウ内表示用）。
    public static func preview(format: ExportFormat = .jpg) -> RenderOptions {
        RenderOptions(format: format, dpi: 72.0, jpegQuality: 0.85)
    }
}

public enum ReportRenderError: Error, Sendable {
    case imageLoadFailed(URL)
    case contextCreationFailed
    case encodingFailed(ExportFormat)
}

public enum ReportRenderer {
    public static func render(
        model: ReportModel,
        options: RenderOptions
    ) throws -> Data {
        if options.format == .svg {
            let svg = try SVGExporter.export(model: model)
            guard let data = svg.data(using: .utf8) else {
                throw ReportRenderError.encodingFailed(.svg)
            }
            return data
        }

        let layout = try prepareLayout(model: model)
        let scale = max(1.0, options.dpi / 72.0)

        let pixelWidth = Int((layout.pageWidthPt * scale).rounded())
        let pixelHeight = Int((layout.pageHeightPt * scale).rounded())

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ReportRenderError.contextCreationFailed
        }

        context.scaleBy(x: scale, y: scale)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: layout.pageWidthPt, height: layout.pageHeightPt))

        draw(layout: layout, in: context)

        guard let cgImage = context.makeImage() else {
            throw ReportRenderError.contextCreationFailed
        }

        return try encode(cgImage: cgImage, format: options.format, quality: options.jpegQuality)
    }

    // MARK: - Layout types

    struct WrappedLine: Sendable {
        let text: String
        let indentPt: Double
    }

    struct DetailSegment: Sendable {
        let lines: [WrappedLine]
        let baselineYPt: Double
    }

    struct CaseBlock: Sendable {
        let titleString: String
        let detailSegments: [DetailSegment]
        let topYPt: Double
        let titleBaselineYPt: Double
        let detailLineHeightPt: Double
        let totalHeightPt: Double
    }

    struct PreparedLayout {
        let model: ReportModel
        let pageWidthPt: Double
        let pageHeightPt: Double
        let headerBaselineYPt: Double
        let solidRuleYPt: Double
        let dashedTopYPt: Double
        let dashedBottomYPt: Double
        let bodyStartYPt: Double
        let cases: [CaseBlock]
        let grayTopYPt: Double
        let grayHeightPt: Double
        let grid: GridLayoutResult
        let images: [LoadedImage]
        let dateFontSizePt: Double
        let dateText: String
    }

    struct LoadedImage {
        let image: CGImage
        let widthMm: Double
        let heightMm: Double
    }

    static func prepareLayout(model: ReportModel) throws -> PreparedLayout {
        let mm = LayoutConstants.mmPerPoint
        let pageWidthPt = LayoutConstants.a4WidthMm * mm

        var images: [LoadedImage] = []
        for url in model.imagePaths {
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateImageAtIndex(src, 0, nil)
            else {
                throw ReportRenderError.imageLoadFailed(url)
            }
            let widthPt = Double(cg.width)
            let heightPt = Double(cg.height)
            images.append(
                LoadedImage(
                    image: cg,
                    widthMm: widthPt / mm,
                    heightMm: heightPt / mm
                )
            )
        }

        let imageSizes = images.map { ImageSize(widthMm: $0.widthMm, heightMm: $0.heightMm) }
        let grid = GridLayoutCalculator.calculate(imageSizes: imageSizes)

        let headerBaselineYPt: Double = 40.0
        let solidRuleYPt: Double = 51.44

        let bodyStartYPt: Double = solidRuleYPt + 15.0
        let contentWidthPt = (LayoutConstants.a4WidthMm - LayoutConstants.contentMarginXMm * 2) * mm
        let detailLineHeightPt = LayoutConstants.caseDetailFontSizePt * LayoutConstants.caseDetailLineHeightMultiple
        let titleFontSize = LayoutConstants.caseTitleFontSizePt
        let detailFontSize = LayoutConstants.caseDetailFontSizePt
        let arrowWidthPt = measureLineWidth(text: "→", fontSize: detailFontSize, weight: .w3)

        let inputCases = model.cases.isEmpty ? [ReportCase(title: "", details: [""])] : model.cases
        var caseBlocks: [CaseBlock] = []
        var currentY = bodyStartYPt
        let caseBottomPaddingPt: Double = 10.0
        let detailGapPt = LayoutConstants.caseDetailFontSizePt * 0.35
        for c in inputCases {
            let titleString = "●" + c.title
            let titleBaselineYPt = currentY + titleFontSize * 0.8
            let detailsToRender = c.details.isEmpty ? [""] : c.details
            var segments: [DetailSegment] = []
            var segmentTopY = currentY + LayoutConstants.caseDetailOffsetPt
            for (idx, d) in detailsToRender.enumerated() {
                let detailSource = "→" + d
                let lines = wrapText(
                    detailSource,
                    fontSize: detailFontSize,
                    weight: .w3,
                    contentWidthPt: contentWidthPt,
                    firstLineIndentPt: 0,
                    continuedIndentPt: arrowWidthPt
                )
                let baselineY = segmentTopY + detailFontSize * 0.8
                let linesCount = max(lines.count, 1)
                let segmentBottomY = baselineY + Double(linesCount - 1) * detailLineHeightPt + detailFontSize * 0.2
                segments.append(DetailSegment(lines: lines, baselineYPt: baselineY))
                segmentTopY = segmentBottomY
                if idx < detailsToRender.count - 1 {
                    segmentTopY += detailGapPt
                }
            }
            let detailBottomYPt = segmentTopY
            let totalHeightPt = detailBottomYPt - currentY + caseBottomPaddingPt

            caseBlocks.append(
                CaseBlock(
                    titleString: titleString,
                    detailSegments: segments,
                    topYPt: currentY,
                    titleBaselineYPt: titleBaselineYPt,
                    detailLineHeightPt: detailLineHeightPt,
                    totalHeightPt: totalHeightPt
                )
            )
            currentY += totalHeightPt
        }

        let bodyBottomPt = currentY
        let grayTopYPt = bodyBottomPt + LayoutConstants.textToBlockGapMm * mm
        let grayHeightPt = grid.totalBlockHeightMm * mm
        let dashedTopYPt = grayTopYPt
        let dashedBottomYPt = grayTopYPt + grayHeightPt

        let bottomPaddingPt: Double = 30.0
        let pageHeightPt = grayTopYPt + grayHeightPt + bottomPaddingPt

        let dateText = formatHeaderDate(model.date)
        let dateXPt: Double = 295.1
        let rightPaddingPt: Double = 8.0
        let maxDateWidthPt = pageWidthPt - dateXPt - rightPaddingPt
        let dateFontSizePt = fittedFontSize(
            text: dateText,
            weight: .w3,
            baseSize: LayoutConstants.headerFontSizePt,
            maxWidth: maxDateWidthPt
        )

        return PreparedLayout(
            model: model,
            pageWidthPt: pageWidthPt,
            pageHeightPt: pageHeightPt,
            headerBaselineYPt: headerBaselineYPt,
            solidRuleYPt: solidRuleYPt,
            dashedTopYPt: dashedTopYPt,
            dashedBottomYPt: dashedBottomYPt,
            bodyStartYPt: bodyStartYPt,
            cases: caseBlocks,
            grayTopYPt: grayTopYPt,
            grayHeightPt: grayHeightPt,
            grid: grid,
            images: images,
            dateFontSizePt: dateFontSizePt,
            dateText: dateText
        )
    }

    // MARK: - Text metrics helpers

    static func measureLineWidth(text: String, fontSize: Double, weight: FontWeight) -> Double {
        guard !text.isEmpty else { return 0 }
        let font = CTFontCreateWithName(weight.postScriptName as CFString, CGFloat(fontSize), nil)
        let attrs: [CFString: Any] = [kCTFontAttributeName: font]
        guard let attr = CFAttributedStringCreate(kCFAllocatorDefault, text as CFString, attrs as CFDictionary) else {
            return 0
        }
        let line = CTLineCreateWithAttributedString(attr)
        return Double(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    static func fittedFontSize(text: String, weight: FontWeight, baseSize: Double, maxWidth: Double) -> Double {
        guard !text.isEmpty, maxWidth > 0 else { return baseSize }
        let w = measureLineWidth(text: text, fontSize: baseSize, weight: weight)
        if w <= maxWidth || w == 0 { return baseSize }
        return baseSize * maxWidth / w
    }

    /// 指定幅内で行送りする。1行目とそれ以降でインデントを変えられる（ハンギングインデント）。
    static func wrapText(
        _ text: String,
        fontSize: Double,
        weight: FontWeight,
        contentWidthPt: Double,
        firstLineIndentPt: Double,
        continuedIndentPt: Double
    ) -> [WrappedLine] {
        guard !text.isEmpty else { return [] }
        let font = CTFontCreateWithName(weight.postScriptName as CFString, CGFloat(fontSize), nil)
        let attrs: [CFString: Any] = [kCTFontAttributeName: font]
        guard let attr = CFAttributedStringCreate(kCFAllocatorDefault, text as CFString, attrs as CFDictionary) else {
            return [WrappedLine(text: text, indentPt: firstLineIndentPt)]
        }
        let typesetter = CTTypesetterCreateWithAttributedString(attr)
        let ns = text as NSString
        let totalLength = ns.length
        var lines: [WrappedLine] = []
        var start = 0
        var isFirst = true
        while start < totalLength {
            let indent = isFirst ? firstLineIndentPt : continuedIndentPt
            let available = max(1.0, contentWidthPt - indent)
            let count = CTTypesetterSuggestLineBreak(typesetter, start, available)
            if count <= 0 { break }
            let range = NSRange(location: start, length: min(count, totalLength - start))
            let slice = ns.substring(with: range)
            lines.append(WrappedLine(text: slice, indentPt: indent))
            start += count
            isFirst = false
        }
        if lines.isEmpty {
            lines.append(WrappedLine(text: text, indentPt: firstLineIndentPt))
        }
        return lines
    }

    // MARK: - Drawing

    private static func draw(layout: PreparedLayout, in context: CGContext) {
        let pageH = layout.pageHeightPt
        drawHeader(layout: layout, in: context, pageHeight: pageH)
        drawRules(layout: layout, in: context, pageHeight: pageH)
        drawBody(layout: layout, in: context, pageHeight: pageH)
        drawImageBlock(layout: layout, in: context, pageHeight: pageH)
        drawOuterBorder(layout: layout, in: context, pageHeight: pageH)
    }

    private static func drawHeader(layout: PreparedLayout, in context: CGContext, pageHeight: Double) {
        let y = CGFloat(pageHeight - layout.headerBaselineYPt)

        drawText(
            "名前",
            at: CGPoint(x: 22.19, y: y),
            fontSize: LayoutConstants.headerNameLabelFontSizePt,
            weight: .w3,
            context: context
        )
        drawText(
            layout.model.authorName,
            at: CGPoint(x: 75.65, y: y),
            fontSize: LayoutConstants.headerFontSizePt,
            weight: .w3,
            context: context
        )
        drawText(
            layout.dateText,
            at: CGPoint(x: 295.1, y: y),
            fontSize: layout.dateFontSizePt,
            weight: .w3,
            context: context
        )
    }

    private static func drawRules(layout: PreparedLayout, in context: CGContext, pageHeight: Double) {
        context.saveGState()
        context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(1.32)
        let solidY = CGFloat(pageHeight - layout.solidRuleYPt)
        context.move(to: CGPoint(x: 0, y: solidY))
        context.addLine(to: CGPoint(x: CGFloat(layout.pageWidthPt), y: solidY))
        context.strokePath()

        context.setLineDash(phase: 0, lengths: [3.75, 3.75])
        let dashedTop = CGFloat(pageHeight - layout.dashedTopYPt)
        context.move(to: CGPoint(x: 0, y: dashedTop))
        context.addLine(to: CGPoint(x: CGFloat(layout.pageWidthPt), y: dashedTop))
        context.strokePath()

        let dashedBottom = CGFloat(pageHeight - layout.dashedBottomYPt)
        context.move(to: CGPoint(x: 0, y: dashedBottom))
        context.addLine(to: CGPoint(x: CGFloat(layout.pageWidthPt), y: dashedBottom))
        context.strokePath()
        context.restoreGState()
    }

    private static func drawBody(layout: PreparedLayout, in context: CGContext, pageHeight: Double) {
        let leftPt = LayoutConstants.contentMarginXMm * LayoutConstants.mmPerPoint

        for block in layout.cases {
            drawText(
                block.titleString,
                at: CGPoint(x: leftPt, y: CGFloat(pageHeight - block.titleBaselineYPt)),
                fontSize: LayoutConstants.caseTitleFontSizePt,
                weight: .w3,
                context: context
            )
            for segment in block.detailSegments {
                for (i, wl) in segment.lines.enumerated() {
                    let baselineY = segment.baselineYPt + Double(i) * block.detailLineHeightPt
                    drawText(
                        wl.text,
                        at: CGPoint(x: leftPt + wl.indentPt, y: CGFloat(pageHeight - baselineY)),
                        fontSize: LayoutConstants.caseDetailFontSizePt,
                        weight: .w3,
                        context: context
                    )
                }
            }
        }
    }

    private static func drawImageBlock(layout: PreparedLayout, in context: CGContext, pageHeight: Double) {
        let mm = LayoutConstants.mmPerPoint
        let grayTop = pageHeight - layout.grayTopYPt
        let grayHeight = layout.grayHeightPt
        let grayRect = CGRect(
            x: 0,
            y: grayTop - grayHeight,
            width: layout.pageWidthPt,
            height: grayHeight
        )
        context.saveGState()
        context.setFillColor(CGColor(red: 0xef / 255.0, green: 0xef / 255.0, blue: 0xef / 255.0, alpha: 1))
        context.fill(grayRect)
        context.restoreGState()

        let grid = layout.grid
        guard !layout.images.isEmpty else { return }

        let contentLeftPt = LayoutConstants.contentMarginXMm * mm
        let colWidthPt = grid.columnWidthMm * mm
        let gapPt = LayoutConstants.gapMm * mm
        let grayMarginTopPt = LayoutConstants.grayMarginYMm * mm

        var currentRowTopY = layout.grayTopYPt + grayMarginTopPt
        var imageIndex = 0
        for (rowIdx, rowHeightMm) in grid.rowHeightsMm.enumerated() {
            let rowHeightPt = rowHeightMm * mm
            for col in 0..<grid.columns {
                if imageIndex >= layout.images.count { break }
                let img = layout.images[imageIndex]
                let leftPt = contentLeftPt + (colWidthPt + gapPt) * Double(col)
                let widthPt = colWidthPt
                let scale = img.widthMm > 0 ? (grid.columnWidthMm / img.widthMm) : 0
                let heightPt = img.heightMm * scale * mm

                let rect = CGRect(
                    x: leftPt,
                    y: pageHeight - currentRowTopY - heightPt,
                    width: widthPt,
                    height: heightPt
                )
                context.draw(img.image, in: rect)
                imageIndex += 1
            }
            currentRowTopY += rowHeightPt
            if rowIdx < grid.rowHeightsMm.count - 1 {
                currentRowTopY += gapPt
            }
        }
    }

    private static func drawOuterBorder(layout: PreparedLayout, in context: CGContext, pageHeight: Double) {
        context.saveGState()
        context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(LayoutConstants.outerStrokeWidthPt)
        let inset = LayoutConstants.outerStrokeWidthPt / 2
        let rect = CGRect(
            x: inset,
            y: inset,
            width: layout.pageWidthPt - inset * 2,
            height: pageHeight - inset * 2
        )
        let radius = CGFloat(LayoutConstants.outerCornerRadiusPt)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }

    // MARK: - Text drawing (CoreText)

    enum FontWeight {
        case w3, w6

        var postScriptName: String {
            switch self {
            case .w3: return "HiraginoSans-W3"
            case .w6: return "HiraginoSans-W6"
            }
        }
    }

    private static func drawText(
        _ text: String,
        at point: CGPoint,
        fontSize: Double,
        weight: FontWeight,
        context: CGContext
    ) {
        guard !text.isEmpty else { return }
        let ctFont = CTFontCreateWithName(weight.postScriptName as CFString, CGFloat(fontSize), nil)
        let color = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        let attrs: [CFString: Any] = [
            kCTFontAttributeName: ctFont,
            kCTForegroundColorAttributeName: color
        ]
        let attr = CFAttributedStringCreate(kCFAllocatorDefault, text as CFString, attrs as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attr)
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = point
        CTLineDraw(line, context)
        context.restoreGState()
    }

    static func formatHeaderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "M/d'（'EEEEE'）　画像報告'"
        return formatter.string(from: date)
    }

    // MARK: - Encoding

    private static func encode(cgImage: CGImage, format: ExportFormat, quality: Double) throws -> Data {
        let typeId: CFString
        switch format {
        case .jpg: typeId = UTType.jpeg.identifier as CFString
        case .png: typeId = UTType.png.identifier as CFString
        case .svg: throw ReportRenderError.encodingFailed(format)
        }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, typeId, 1, nil) else {
            throw ReportRenderError.encodingFailed(format)
        }
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw ReportRenderError.encodingFailed(format)
        }
        return data as Data
    }
}
