import Foundation
import CoreGraphics

public enum ExportFormat: String, Sendable {
    case jpg
    case png
    case svg
}

public struct RenderOptions: Sendable {
    public let format: ExportFormat
    public let dpi: Double

    public init(format: ExportFormat, dpi: Double = 72.0) {
        self.format = format
        self.dpi = dpi
    }
}

public enum ReportRenderer {
    public static func render(
        model: ReportModel,
        options: RenderOptions
    ) throws -> Data {
        // TODO: worker1 で実装
        // ヘッダー／本文／画像グリッド／外枠を描画し、指定形式でエンコードして返す。
        // SVG の場合は SVGExporter に委譲。
        fatalError("ReportRenderer.render: not implemented yet")
    }
}
