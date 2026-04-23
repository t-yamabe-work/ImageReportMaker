import XCTest
@testable import ReportCore

final class ReportCoreTests: XCTestCase {
    func testLayoutConstantsMmConversion() {
        XCTAssertEqual(LayoutConstants.mmToPt(25.4), 72.0, accuracy: 0.0001)
        XCTAssertEqual(LayoutConstants.ptToMm(72.0), 25.4, accuracy: 0.0001)
    }

    func testMmPtRoundTrip() {
        for mm in stride(from: 0.0, through: 500.0, by: 7.3) {
            let pt = LayoutConstants.mmToPt(mm)
            let back = LayoutConstants.ptToMm(pt)
            XCTAssertEqual(mm, back, accuracy: 1e-9)
        }
    }

    func testReportModelInitialization() {
        let model = ReportModel(
            authorName: "山田 太郎",
            date: Date(timeIntervalSince1970: 0),
            cases: [ReportCase(title: "案件A", details: ["作業内容A"])],
            imagePaths: []
        )
        XCTAssertEqual(model.authorName, "山田 太郎")
        XCTAssertEqual(model.cases.count, 1)
        XCTAssertEqual(model.cases[0].details, ["作業内容A"])
    }

    func testReportCaseSupportsMultipleDetails() {
        let c = ReportCase(title: "案件", details: ["詳細1", "詳細2", "詳細3"])
        XCTAssertEqual(c.details.count, 3)
        XCTAssertEqual(c.details[1], "詳細2")
    }

    func testFontSizesAreSeventeen() {
        XCTAssertEqual(LayoutConstants.caseTitleFontSizePt, 17.0, accuracy: 1e-9)
        XCTAssertEqual(LayoutConstants.caseDetailFontSizePt, 17.0, accuracy: 1e-9)
    }
}

// MARK: - GridLayoutCalculator

final class GridLayoutCalculatorTests: XCTestCase {
    func testEmptyReturnsZeroRows() {
        let result = GridLayoutCalculator.calculate(imageSizes: [])
        XCTAssertEqual(result.rowHeightsMm.count, 0)
        XCTAssertEqual(result.totalGridHeightMm, 0, accuracy: 1e-9)
        XCTAssertEqual(result.totalBlockHeightMm, LayoutConstants.grayMarginYMm * 2, accuracy: 1e-9)
    }

    func testSingleSquarePicksOneColumn() {
        let img = ImageSize(widthMm: 100, heightMm: 100)
        let result = GridLayoutCalculator.calculate(imageSizes: [img])
        XCTAssertEqual(result.columns, 1)
        XCTAssertEqual(result.rowHeightsMm.count, 1)
        // One image scaled to full content width (204mm) keeps its 1:1 ratio.
        XCTAssertEqual(result.rowHeightsMm[0], 204.0, accuracy: 1e-6)
    }

    func testSmallImagesPickMinimumColumns() {
        // Four small square images should still pick the smallest column count
        // whose resulting block height ≤ 1200mm. With 1 column, 4 rows of 204mm
        // = 816mm grid (+ 10mm margin) = 826mm ≤ 1200 → choose 1 column.
        let imgs = Array(repeating: ImageSize(widthMm: 100, heightMm: 100), count: 4)
        let result = GridLayoutCalculator.calculate(imageSizes: imgs)
        XCTAssertEqual(result.columns, 1)
        XCTAssertEqual(result.rowHeightsMm.count, 4)
    }

    func testManyImagesForceHigherColumns() {
        // 30 images at 2:3 portrait — 1-col would blow past 1200mm.
        // The algorithm picks the smallest column count whose block height ≤ 1200mm.
        let imgs = Array(repeating: ImageSize(widthMm: 100, heightMm: 150), count: 30)
        let result = GridLayoutCalculator.calculate(imageSizes: imgs)
        XCTAssertTrue(result.columns >= 2, "expected at least 2 columns, got \(result.columns)")
        XCTAssertTrue(result.columns <= 5)
        XCTAssertLessThanOrEqual(result.totalBlockHeightMm, LayoutConstants.maxBlockHeightMm)
    }

    func testOverflowClampsToMaxColumns() {
        // 500 images — even 5 cols won't fit in 1200mm. Expect 5 columns returned anyway.
        let imgs = Array(repeating: ImageSize(widthMm: 100, heightMm: 100), count: 500)
        let result = GridLayoutCalculator.calculate(imageSizes: imgs)
        XCTAssertEqual(result.columns, 5)
        XCTAssertGreaterThan(result.totalBlockHeightMm, LayoutConstants.maxBlockHeightMm)
    }

    func testSuperWideImagePicksOneColumn() {
        // Super wide single image: 2000mm wide × 10mm tall.
        // 1 col → 204mm wide, scale = 0.102, heightMm = 1.02mm → fits easily.
        let img = ImageSize(widthMm: 2000, heightMm: 10)
        let result = GridLayoutCalculator.calculate(imageSizes: [img])
        XCTAssertEqual(result.columns, 1)
        XCTAssertEqual(result.rowHeightsMm[0], 204.0 * 10.0 / 2000.0, accuracy: 1e-6)
    }

    func testColumnWidthFormula() {
        let img = ImageSize(widthMm: 50, heightMm: 50)
        // Make 3-col fit: 3 square images → 3 in one row, width=(204-6)/3=66mm, height=66mm.
        // 1-col would require 3 rows of 204mm = 612mm + 6mm gap + 10mm margin = 628mm (< 1200) → picks 1.
        // So to force 3 cols, use many images.
        let many = Array(repeating: img, count: 50)
        let result = GridLayoutCalculator.calculate(imageSizes: many)
        let expected = (204.0 - 3.0 * Double(result.columns - 1)) / Double(result.columns)
        XCTAssertEqual(result.columnWidthMm, expected, accuracy: 1e-9)
    }

    func testRowHeightUsesMaxInRow() {
        // Two images in a 2-col layout: tall one + short one → row height = tall scaled height
        let tall = ImageSize(widthMm: 100, heightMm: 200)
        let short = ImageSize(widthMm: 100, heightMm: 50)
        // Force 2 columns by adding many pairs so single-col exceeds 1200mm.
        var imgs: [ImageSize] = []
        for _ in 0..<10 {
            imgs.append(tall)
            imgs.append(short)
        }
        let result = GridLayoutCalculator.calculate(imageSizes: imgs)
        if result.columns == 2 {
            let colWidth = result.columnWidthMm
            let tallScaled = 200.0 * colWidth / 100.0
            XCTAssertEqual(result.rowHeightsMm.first ?? 0, tallScaled, accuracy: 1e-6)
        }
    }
}

// MARK: - Rendering smoke tests

final class ReportRendererTests: XCTestCase {
    func testSVGExportWithoutImages() throws {
        let model = ReportModel(
            authorName: "山田 太郎",
            date: Date(timeIntervalSince1970: 0),
            cases: [ReportCase(title: "案件A", details: ["詳細A"])],
            imagePaths: []
        )
        let data = try ReportRenderer.render(model: model, options: RenderOptions(format: .svg))
        let svg = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(svg.hasPrefix("<?xml"))
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("山田 太郎"))
    }

    func testSVGHasNoBoldClass() throws {
        let model = ReportModel(
            authorName: "山田 太郎",
            date: Date(timeIntervalSince1970: 0),
            cases: [ReportCase(title: "案件A", details: ["詳細A"])],
            imagePaths: []
        )
        let data = try ReportRenderer.render(model: model, options: RenderOptions(format: .svg))
        let svg = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(svg.contains("t-w6"), "太字クラス t-w6 は出力されないはず")
        XCTAssertFalse(svg.contains("font-weight:600"), "font-weight:600 は出力されないはず")
    }

    func testSVGRendersAllDetailsInOneCase() throws {
        let model = ReportModel(
            authorName: "山田 太郎",
            date: Date(timeIntervalSince1970: 0),
            cases: [ReportCase(title: "案件A", details: ["最初の詳細", "二番目の詳細", "三番目の詳細"])],
            imagePaths: []
        )
        let data = try ReportRenderer.render(model: model, options: RenderOptions(format: .svg))
        let svg = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(svg.contains("最初の詳細"))
        XCTAssertTrue(svg.contains("二番目の詳細"))
        XCTAssertTrue(svg.contains("三番目の詳細"))
    }

    func testJPGRenderReturnsBytes() throws {
        let model = ReportModel(
            authorName: "山田 太郎",
            date: Date(timeIntervalSince1970: 0),
            cases: [ReportCase(title: "案件A", details: ["詳細A"])],
            imagePaths: []
        )
        let data = try ReportRenderer.render(model: model, options: RenderOptions(format: .jpg))
        XCTAssertGreaterThan(data.count, 100)
        // JPEG SOI marker
        XCTAssertEqual(data[0], 0xFF)
        XCTAssertEqual(data[1], 0xD8)
    }

    func testPNGRenderReturnsBytes() throws {
        let model = ReportModel(
            authorName: "山田 太郎",
            date: Date(timeIntervalSince1970: 0),
            cases: [],
            imagePaths: []
        )
        let data = try ReportRenderer.render(model: model, options: RenderOptions(format: .png))
        XCTAssertGreaterThan(data.count, 100)
        // PNG signature
        XCTAssertEqual(data[0], 0x89)
        XCTAssertEqual(data[1], 0x50)
        XCTAssertEqual(data[2], 0x4E)
        XCTAssertEqual(data[3], 0x47)
    }

    func testRenderOptionsDefaultDpiIs150() {
        let opt = RenderOptions(format: .jpg)
        XCTAssertEqual(opt.dpi, 150.0, accuracy: 0.0001)
    }

    func testRenderOptionsExportPreset() {
        let opt = RenderOptions.export(format: .png)
        XCTAssertEqual(opt.dpi, 150.0, accuracy: 0.0001)
        XCTAssertEqual(opt.format, .png)
    }

    func testRenderOptionsPreviewPreset() {
        let opt = RenderOptions.preview()
        XCTAssertEqual(opt.dpi, 72.0, accuracy: 0.0001)
    }

    func testWrapTextLongDetailProducesMultipleLines() {
        let mm = LayoutConstants.mmPerPoint
        let contentWidthPt = (LayoutConstants.a4WidthMm - LayoutConstants.contentMarginXMm * 2) * mm
        // 長文（全角30文字×8行ぶん相当）
        let detail = String(repeating: "作業用データ作成と製版を進行致しました次の工程に入ります", count: 4)
        let source = "→" + detail
        let arrowWidth = ReportRenderer.measureLineWidth(
            text: "→",
            fontSize: LayoutConstants.caseDetailFontSizePt,
            weight: .w3
        )
        let lines = ReportRenderer.wrapText(
            source,
            fontSize: LayoutConstants.caseDetailFontSizePt,
            weight: .w3,
            contentWidthPt: contentWidthPt,
            firstLineIndentPt: 0,
            continuedIndentPt: arrowWidth
        )
        XCTAssertGreaterThan(lines.count, 1, "long detail should wrap to >1 lines")
        XCTAssertEqual(lines.first?.indentPt ?? -1, 0, accuracy: 1e-6)
        XCTAssertGreaterThan(lines[1].indentPt, 0, "continued lines should be indented")
    }

    func testCaseStackingHeightGrowsWithLongDetail() throws {
        let shortModel = ReportModel(
            authorName: "テスト",
            date: Date(timeIntervalSince1970: 0),
            cases: [
                ReportCase(title: "A", details: ["短い"]),
                ReportCase(title: "B", details: ["短い"])
            ],
            imagePaths: []
        )
        let longDetail = String(repeating: "非常に長い詳細テキスト", count: 10)
        let longModel = ReportModel(
            authorName: "テスト",
            date: Date(timeIntervalSince1970: 0),
            cases: [
                ReportCase(title: "A", details: [longDetail]),
                ReportCase(title: "B", details: ["短い"])
            ],
            imagePaths: []
        )
        let shortLayout = try ReportRenderer.prepareLayout(model: shortModel)
        let longLayout = try ReportRenderer.prepareLayout(model: longModel)
        XCTAssertGreaterThan(longLayout.pageHeightPt, shortLayout.pageHeightPt)
        XCTAssertGreaterThan(longLayout.cases[0].totalHeightPt, shortLayout.cases[0].totalHeightPt)
        XCTAssertGreaterThan(longLayout.cases[0].detailSegments[0].lines.count, 1)
        XCTAssertEqual(shortLayout.cases[0].detailSegments[0].lines.count, 1)
    }

    func testMultipleDetailsIncreaseCaseHeight() throws {
        let oneDetailModel = ReportModel(
            authorName: "テスト",
            date: Date(timeIntervalSince1970: 0),
            cases: [ReportCase(title: "A", details: ["詳細1"])],
            imagePaths: []
        )
        let threeDetailsModel = ReportModel(
            authorName: "テスト",
            date: Date(timeIntervalSince1970: 0),
            cases: [ReportCase(title: "A", details: ["詳細1", "詳細2", "詳細3"])],
            imagePaths: []
        )
        let oneLayout = try ReportRenderer.prepareLayout(model: oneDetailModel)
        let threeLayout = try ReportRenderer.prepareLayout(model: threeDetailsModel)
        XCTAssertEqual(oneLayout.cases[0].detailSegments.count, 1)
        XCTAssertEqual(threeLayout.cases[0].detailSegments.count, 3)
        XCTAssertGreaterThan(threeLayout.cases[0].totalHeightPt, oneLayout.cases[0].totalHeightPt)
        // 各 segment の baseline は単調増加
        let baselines = threeLayout.cases[0].detailSegments.map { $0.baselineYPt }
        XCTAssertLessThan(baselines[0], baselines[1])
        XCTAssertLessThan(baselines[1], baselines[2])
    }

    func testPreviewAndExportDpiProduceDifferentByteSizes() throws {
        let model = ReportModel(
            authorName: "テスト",
            date: Date(timeIntervalSince1970: 0),
            cases: [ReportCase(title: "A", details: ["テスト"])],
            imagePaths: []
        )
        let preview = try ReportRenderer.render(model: model, options: .preview(format: .png))
        let export = try ReportRenderer.render(model: model, options: .export(format: .png))
        XCTAssertGreaterThan(export.count, preview.count)
    }

    func testHeaderDateFormatShort() {
        // 2026-04-21 JST (Tue)
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 4
        comps.day = 21
        comps.hour = 12
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ja_JP")
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let date = cal.date(from: comps)!

        let s = ReportRenderer.formatHeaderDate(date)
        XCTAssertTrue(s.contains("画像報告"))
        XCTAssertTrue(s.contains("4/21"))
        XCTAssertTrue(s.contains("（"))
        XCTAssertTrue(s.contains("）"))
        XCTAssertFalse(s.contains("年"))
        XCTAssertFalse(s.contains("月"))
        // 曜日は単一文字漢字
        let weekdayChars: Set<Character> = ["月", "火", "水", "木", "金", "土", "日"]
        let weekdayPresent = s.contains { weekdayChars.contains($0) }
        XCTAssertTrue(weekdayPresent, "曜日1文字(月火水木金土日)が含まれるべき: \(s)")
        // 2026-04-21 は火曜日
        XCTAssertTrue(s.contains("火"))
    }
}
