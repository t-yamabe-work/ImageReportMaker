import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum SVGExporter {
    public static func export(model: ReportModel) throws -> String {
        let layout = try ReportRenderer.prepareLayout(model: model)
        let mm = LayoutConstants.mmPerPoint
        let pageH = layout.pageHeightPt
        let pageW = layout.pageWidthPt

        var svg = ""
        svg += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        svg += "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" "
        svg += "width=\"\(format(pageW))pt\" height=\"\(format(pageH))pt\" "
        svg += "viewBox=\"0 0 \(format(pageW)) \(format(pageH))\">\n"

        svg += "<defs>\n<style>\n"
        svg += fontFaceRules()
        svg += ".outer{fill:none;stroke:#000;stroke-width:\(format(LayoutConstants.outerStrokeWidthPt));}\n"
        svg += ".rule-solid{stroke:#000;stroke-width:1.32;fill:none;}\n"
        svg += ".rule-dashed{stroke:#000;stroke-width:0.75;fill:none;stroke-dasharray:3.75 3.75;}\n"
        svg += ".bg-gray{fill:#efefef;}\n"
        svg += ".t-w3{font-family:'Hiragino Sans','ヒラギノ角ゴシック',sans-serif;font-weight:300;fill:#000;}\n"
        svg += ".t-w6{font-family:'Hiragino Sans','ヒラギノ角ゴシック',sans-serif;font-weight:600;fill:#000;}\n"
        svg += "</style>\n</defs>\n"

        // Gray block
        if !layout.images.isEmpty || layout.grid.totalBlockHeightMm > 0 {
            let gx = 0.0
            let gy = layout.grayTopYPt
            svg += "<rect class=\"bg-gray\" x=\"\(format(gx))\" y=\"\(format(gy))\" "
            svg += "width=\"\(format(pageW))\" height=\"\(format(layout.grayHeightPt))\"/>\n"
        }

        // Header text
        svg += textElement("名前", x: 22.19, y: layout.headerBaselineYPt, size: LayoutConstants.headerNameLabelFontSizePt, cls: "t-w3")
        svg += textElement(layout.model.authorName, x: 75.65, y: layout.headerBaselineYPt, size: LayoutConstants.headerFontSizePt, cls: "t-w6")
        svg += textElement(layout.dateText, x: 295.1, y: layout.headerBaselineYPt, size: layout.dateFontSizePt, cls: "t-w3")

        // Rules
        svg += "<line class=\"rule-solid\" x1=\"0\" y1=\"\(format(layout.solidRuleYPt))\" "
        svg += "x2=\"\(format(pageW))\" y2=\"\(format(layout.solidRuleYPt))\"/>\n"
        svg += "<line class=\"rule-dashed\" x1=\"0\" y1=\"\(format(layout.dashedTopYPt))\" "
        svg += "x2=\"\(format(pageW))\" y2=\"\(format(layout.dashedTopYPt))\"/>\n"
        svg += "<line class=\"rule-dashed\" x1=\"0\" y1=\"\(format(layout.dashedBottomYPt))\" "
        svg += "x2=\"\(format(pageW))\" y2=\"\(format(layout.dashedBottomYPt))\"/>\n"

        // Body
        let leftPt = LayoutConstants.contentMarginXMm * mm
        let displayCases = layout.model.cases.isEmpty ? [ReportCase(title: "", detail: "")] : layout.model.cases
        for (idx, c) in displayCases.enumerated() {
            let top = layout.bodyStartYPt + Double(idx) * layout.caseLineHeightPt
            let titleY = top + LayoutConstants.caseTitleFontSizePt * 0.8
            let detailY = top + layout.caseDetailOffsetPt + LayoutConstants.caseDetailFontSizePt * 0.8
            svg += textElement("●" + c.title, x: leftPt, y: titleY, size: LayoutConstants.caseTitleFontSizePt, cls: "t-w6")
            svg += textElement("→" + c.detail, x: leftPt + 10, y: detailY, size: LayoutConstants.caseDetailFontSizePt, cls: "t-w3")
        }

        // Images
        let contentLeftPt = LayoutConstants.contentMarginXMm * mm
        let colWidthPt = layout.grid.columnWidthMm * mm
        let gapPt = LayoutConstants.gapMm * mm
        let grayMarginTopPt = LayoutConstants.grayMarginYMm * mm
        var currentRowTopY = layout.grayTopYPt + grayMarginTopPt
        var imageIndex = 0
        for (rowIdx, rowHeightMm) in layout.grid.rowHeightsMm.enumerated() {
            let rowHeightPt = rowHeightMm * mm
            for col in 0..<layout.grid.columns {
                if imageIndex >= layout.images.count { break }
                let img = layout.images[imageIndex]
                let leftX = contentLeftPt + (colWidthPt + gapPt) * Double(col)
                let scale = img.widthMm > 0 ? (layout.grid.columnWidthMm / img.widthMm) : 0
                let heightPt = img.heightMm * scale * mm
                if let href = imageDataURI(cgImage: img.image) {
                    svg += "<image x=\"\(format(leftX))\" y=\"\(format(currentRowTopY))\" "
                    svg += "width=\"\(format(colWidthPt))\" height=\"\(format(heightPt))\" "
                    svg += "preserveAspectRatio=\"none\" xlink:href=\"\(href)\"/>\n"
                }
                imageIndex += 1
            }
            currentRowTopY += rowHeightPt
            if rowIdx < layout.grid.rowHeightsMm.count - 1 {
                currentRowTopY += gapPt
            }
        }

        // Outer border
        let inset = LayoutConstants.outerStrokeWidthPt / 2
        let r = LayoutConstants.outerCornerRadiusPt
        svg += "<rect class=\"outer\" x=\"\(format(inset))\" y=\"\(format(inset))\" "
        svg += "width=\"\(format(pageW - inset * 2))\" height=\"\(format(pageH - inset * 2))\" "
        svg += "rx=\"\(format(r))\" ry=\"\(format(r))\"/>\n"

        svg += "</svg>\n"
        return svg
    }

    // MARK: - Helpers

    private static func fontFaceRules() -> String {
        var rules = ""
        let faces: [(name: String, weight: Int, file: String)] = [
            ("Hiragino Sans", 300, "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"),
            ("Hiragino Sans", 600, "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc")
        ]
        for face in faces {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: face.file)) {
                let b64 = data.base64EncodedString()
                rules += "@font-face{font-family:'\(face.name)';font-weight:\(face.weight);"
                rules += "src:url(data:font/collection;base64,\(b64)) format('collection'),"
                rules += "url(data:font/ttf;base64,\(b64)) format('truetype');}\n"
            }
        }
        return rules
    }

    private static func textElement(_ text: String, x: Double, y: Double, size: Double, cls: String) -> String {
        let escaped = xmlEscape(text)
        return "<text class=\"\(cls)\" x=\"\(format(x))\" y=\"\(format(y))\" font-size=\"\(format(size))\">\(escaped)</text>\n"
    }

    private static func imageDataURI(cgImage: CGImage) -> String? {
        let data = NSMutableData()
        let typeId = UTType.png.identifier as CFString
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, typeId, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        let b64 = (data as Data).base64EncodedString()
        return "data:image/png;base64,\(b64)"
    }

    private static func format(_ v: Double) -> String {
        if v == v.rounded() {
            return String(format: "%g", v)
        }
        return String(format: "%.3f", v)
    }

    private static func xmlEscape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default: out.append(ch)
            }
        }
        return out
    }
}
