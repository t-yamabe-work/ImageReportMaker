import Foundation

public enum SVGExporter {
    public static func export(model: ReportModel) throws -> String {
        // TODO: worker1 で実装
        // - ヘッダー／本文／画像グリッドを SVG 要素として組み立てる
        // - Hiragino Sans を @font-face で Base64 埋め込み
        // - 画像は <image xlink:href="data:..."> で Base64 インライン埋め込み
        fatalError("SVGExporter.export: not implemented yet")
    }
}
