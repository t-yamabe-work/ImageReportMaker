import XCTest
@testable import ReportCore

final class ReportCoreTests: XCTestCase {
    func testLayoutConstantsMmConversion() {
        XCTAssertEqual(LayoutConstants.mmToPt(25.4), 72.0, accuracy: 0.0001)
        XCTAssertEqual(LayoutConstants.ptToMm(72.0), 25.4, accuracy: 0.0001)
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
