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

    public init(format: ExportFormat, dpi: Double = 72.0, jpegQuality: Double = 0.92) {
        self.format = format
        self.dpi = dpi
        self.jpegQuality = jpegQuality
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
        // Fill white background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: layout.pageWidthPt, height: layout.pageHeightPt))

        draw(layout: layout, in: context)

        guard let cgImage = context.makeImage() else {
            throw ReportRenderError.contextCreationFailed
        }

        return try encode(cgImage: cgImage, format: options.format, quality: options.jpegQuality)
    }

    // MARK: - Layout preparation

    struct PreparedLayout {
        let model: ReportModel
        let pageWidthPt: Double
        let pageHeightPt: Double
        let headerBaselineYPt: Double
        let solidRuleYPt: Double
        let dashedRuleYPt: Double
        let bodyStartYPt: Double
        let caseLineHeightPt: Double
        let caseDetailOffsetPt: Double
        let grayTopYPt: Double
        let grayHeightPt: Double
        let grid: GridLayoutResult
        let images: [LoadedImage]
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
            // Treat 1 pixel = 1 pt (72 dpi convention) for aspect-ratio preservation.
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

        // Header geometry from layout-spec.md
        let headerBaselineYPt: Double = 40.0
        let solidRuleYPt: Double = 51.44
        let dashedRuleYPt: Double = 138.95

        let bodyStartYPt: Double = dashedRuleYPt + 20.0
        let caseDetailOffsetPt: Double = 38.13
        let caseBlockHeightPt: Double = caseDetailOffsetPt + LayoutConstants.caseDetailFontSizePt + 10.0

        let caseCount = max(model.cases.count, 1)
        let bodyBottomPt = bodyStartYPt + Double(caseCount) * caseBlockHeightPt

        let grayTopYPt = bodyBottomPt + LayoutConstants.textToBlockGapMm * mm
        let grayHeightPt = grid.totalBlockHeightMm * mm

        let bottomPaddingPt: Double = 30.0
        let pageHeightPt = grayTopYPt + grayHeightPt + bottomPaddingPt

        return PreparedLayout(
            model: model,
            pageWidthPt: pageWidthPt,
            pageHeightPt: pageHeightPt,
            headerBaselineYPt: headerBaselineYPt,
            solidRuleYPt: solidRuleYPt,
            dashedRuleYPt: dashedRuleYPt,
            bodyStartYPt: bodyStartYPt,
            caseLineHeightPt: caseBlockHeightPt,
            caseDetailOffsetPt: caseDetailOffsetPt,
            grayTopYPt: grayTopYPt,
            grayHeightPt: grayHeightPt,
            grid: grid,
            images: images
        )
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
        let dateText = formatHeaderDate(layout.model.date)

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
            weight: .w6,
            context: context
        )
        drawText(
            dateText,
            at: CGPoint(x: 295.1, y: y),
            fontSize: LayoutConstants.headerFontSizePt,
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

        context.setLineWidth(0.75)
        context.setLineDash(phase: 0, lengths: [3.75, 3.75])
        let dashedY = CGFloat(pageHeight - layout.dashedRuleYPt)
        context.move(to: CGPoint(x: 0, y: dashedY))
        context.addLine(to: CGPoint(x: CGFloat(layout.pageWidthPt), y: dashedY))
        context.strokePath()
        context.restoreGState()
    }

    private static func drawBody(layout: PreparedLayout, in context: CGContext, pageHeight: Double) {
        let leftPt = LayoutConstants.contentMarginXMm * LayoutConstants.mmPerPoint
        let cases = layout.model.cases
        let displayCases: [ReportCase]
        if cases.isEmpty {
            displayCases = [ReportCase(title: "", detail: "")]
        } else {
            displayCases = cases
        }

        for (idx, c) in displayCases.enumerated() {
            let top = layout.bodyStartYPt + Double(idx) * layout.caseLineHeightPt
            let titleY = CGFloat(pageHeight - top - LayoutConstants.caseTitleFontSizePt * 0.2)
            let detailY = CGFloat(pageHeight - (top + layout.caseDetailOffsetPt) - LayoutConstants.caseDetailFontSizePt * 0.2)

            drawText(
                "●" + c.title,
                at: CGPoint(x: leftPt, y: titleY),
                fontSize: LayoutConstants.caseTitleFontSizePt,
                weight: .w6,
                context: context
            )
            drawText(
                "→" + c.detail,
                at: CGPoint(x: leftPt + 10, y: detailY),
                fontSize: LayoutConstants.caseDetailFontSizePt,
                weight: .w3,
                context: context
            )
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
        formatter.dateFormat = "yyyy年M月d日(EEEEE) 画像報告"
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
