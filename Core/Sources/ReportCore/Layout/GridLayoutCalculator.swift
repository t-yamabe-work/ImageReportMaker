import Foundation

public struct ImageSize: Equatable, Sendable {
    public let widthMm: Double
    public let heightMm: Double

    public init(widthMm: Double, heightMm: Double) {
        self.widthMm = widthMm
        self.heightMm = heightMm
    }
}

public struct GridLayoutResult: Equatable, Sendable {
    public let columns: Int
    public let columnWidthMm: Double
    public let rowHeightsMm: [Double]
    public let totalGridHeightMm: Double
    public let totalBlockHeightMm: Double
}

public enum GridLayoutCalculator {
    public static func calculate(
        imageSizes: [ImageSize],
        contentWidthMm: Double = LayoutConstants.a4WidthMm - LayoutConstants.contentMarginXMm * 2,
        gapMm: Double = LayoutConstants.gapMm,
        grayMarginYMm: Double = LayoutConstants.grayMarginYMm,
        maxBlockHeightMm: Double = LayoutConstants.maxBlockHeightMm,
        minColumns: Int = LayoutConstants.minColumns,
        maxColumns: Int = LayoutConstants.maxColumns
    ) -> GridLayoutResult {
        // TODO: worker1 で実装
        // JSX `simulateGridLayout` を移植し、minColumns..maxColumns の範囲で
        // 全高が maxBlockHeightMm 以下になる最小列数を選ぶ。
        // 満たせない場合は maxColumns を使う。
        fatalError("GridLayoutCalculator.calculate: not implemented yet")
    }
}
