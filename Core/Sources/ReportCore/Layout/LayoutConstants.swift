import Foundation

public enum LayoutConstants {
    public static let mmPerPoint: Double = 72.0 / 25.4

    public static let a4WidthMm: Double = 210.0

    public static let gapMm: Double = 3.0
    public static let maxBlockHeightMm: Double = 1200.0
    public static let contentMarginXMm: Double = 3.0
    public static let grayMarginYMm: Double = 5.0
    public static let textToBlockGapMm: Double = 3.0

    public static let minColumns: Int = 1
    public static let maxColumns: Int = 5

    public static let headerFontSizePt: Double = 23.95
    public static let headerNameLabelFontSizePt: Double = 11.43
    public static let caseTitleFontSizePt: Double = 22.30
    public static let caseDetailFontSizePt: Double = 21.29
    public static let caseDetailLineHeightMultiple: Double = 1.25
    public static let caseDetailOffsetPt: Double = 38.13

    public static let outerCornerRadiusPt: Double = 33.47
    public static let outerStrokeWidthPt: Double = 2.83

    public static let grayFillHex: String = "#efefef"
    public static let grayFillKPercent: Double = 10.0

    public static func mmToPt(_ mm: Double) -> Double { mm * mmPerPoint }
    public static func ptToMm(_ pt: Double) -> Double { pt / mmPerPoint }
}
