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
            cases: [ReportCase(title: "案件A", detail: "作業内容A")],
            imagePaths: []
        )
        XCTAssertEqual(model.authorName, "山田 太郎")
        XCTAssertEqual(model.cases.count, 1)
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
            cases: [ReportCase(title: "案件A", detail: "詳細A")],
            imagePaths: []
        )
        let data = try ReportRenderer.render(model: model, options: RenderOptions(format: .svg))
        let svg = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(svg.hasPrefix("<?xml"))
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("山田 太郎"))
    }

    func testJPGRenderReturnsBytes() throws {
        let model = ReportModel(
            authorName: "山田 太郎",
            date: Date(timeIntervalSince1970: 0),
            cases: [ReportCase(title: "案件A", detail: "詳細A")],
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
