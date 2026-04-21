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

    public init(
        columns: Int,
        columnWidthMm: Double,
        rowHeightsMm: [Double],
        totalGridHeightMm: Double,
        totalBlockHeightMm: Double
    ) {
        self.columns = columns
        self.columnWidthMm = columnWidthMm
        self.rowHeightsMm = rowHeightsMm
        self.totalGridHeightMm = totalGridHeightMm
        self.totalBlockHeightMm = totalBlockHeightMm
    }
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
        let lo = max(1, minColumns)
        let hi = max(lo, maxColumns)

        guard !imageSizes.isEmpty else {
            let colWidth = columnWidth(contentWidthMm: contentWidthMm, gapMm: gapMm, cols: lo)
            return GridLayoutResult(
                columns: lo,
                columnWidthMm: colWidth,
                rowHeightsMm: [],
                totalGridHeightMm: 0,
                totalBlockHeightMm: grayMarginYMm * 2
            )
        }

        var chosenCols = hi
        var chosenRows: [Double] = []
        var chosenTotal: Double = 0
        var matched = false

        for cols in lo...hi {
            let sim = simulate(imageSizes: imageSizes, cols: cols, contentWidthMm: contentWidthMm, gapMm: gapMm)
            let blockHeight = sim.total + grayMarginYMm * 2
            if blockHeight <= maxBlockHeightMm {
                chosenCols = cols
                chosenRows = sim.rowHeights
                chosenTotal = sim.total
                matched = true
                break
            }
        }

        if !matched {
            let sim = simulate(imageSizes: imageSizes, cols: hi, contentWidthMm: contentWidthMm, gapMm: gapMm)
            chosenCols = hi
            chosenRows = sim.rowHeights
            chosenTotal = sim.total
        }

        let colWidth = columnWidth(contentWidthMm: contentWidthMm, gapMm: gapMm, cols: chosenCols)
        return GridLayoutResult(
            columns: chosenCols,
            columnWidthMm: colWidth,
            rowHeightsMm: chosenRows,
            totalGridHeightMm: chosenTotal,
            totalBlockHeightMm: chosenTotal + grayMarginYMm * 2
        )
    }

    private static func columnWidth(contentWidthMm: Double, gapMm: Double, cols: Int) -> Double {
        let c = max(1, cols)
        return (contentWidthMm - gapMm * Double(c - 1)) / Double(c)
    }

    private static func simulate(
        imageSizes: [ImageSize],
        cols: Int,
        contentWidthMm: Double,
        gapMm: Double
    ) -> (rowHeights: [Double], total: Double) {
        let c = max(1, cols)
        let colWidth = columnWidth(contentWidthMm: contentWidthMm, gapMm: gapMm, cols: c)
        var rowHeights: [Double] = []
        for (i, img) in imageSizes.enumerated() {
            let scale = img.widthMm > 0 ? colWidth / img.widthMm : 0
            let hScaled = img.heightMm * scale
            let rowIdx = i / c
            if rowIdx >= rowHeights.count {
                rowHeights.append(hScaled)
            } else {
                rowHeights[rowIdx] = max(rowHeights[rowIdx], hScaled)
            }
        }
        var total = rowHeights.reduce(0, +)
        if rowHeights.count > 1 {
            total += gapMm * Double(rowHeights.count - 1)
        }
        return (rowHeights, total)
    }
}
