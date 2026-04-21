# JSX参照＆Swift移植メモ

元ファイル：`docs/block_grid_a4_v1.0.1.jsx`（本リポジトリにコピー済み）

## JSXの処理フロー

1. アクティブドキュメント取得（A4縦想定）
2. 選択オブジェクトから TextFrame 1つ ＋ PlacedItem/RasterItem 複数を分離
3. 本文テキストフレームを左3mm・幅204mmに調整
4. 各画像の幅・高さを取得（mm単位）
5. 列数 1〜5 を順に試算し、ブロック全高が 1200mm 以下になる最小列数を採用
6. 画像を列幅に合わせてリサイズ（等倍スケール）
7. グリッドに並べる（テキスト下端から6mm下を基準）
8. グレー背景（10%K）をアートボード幅で描画、最背面へ
9. 画像＋背景をグループ化

## Swiftへの移植マッピング

| JSX | Swift移植先 |
|---|---|
| `MM` 換算定数 | `LayoutConstants.mmPerPoint` |
| `GAP_MM` 他の各マージン | `LayoutConstants.*Mm` |
| `simulateGridLayout(imgData, cols, …)` | `GridLayoutCalculator.calculate(...)` |
| テキストフレーム位置調整 | ヘッダー／本文の `CGContext` / SwiftUI Canvas 描画 |
| `doc.pathItems.rectangle(...)` グレー背景 | `CGContext.fill` / SwiftUI Path |
| `item.resize(...)` 画像リサイズ | `CGImage` 描画時の矩形指定 |
| `item.position = [...]` 画像配置 | `CGContext.draw(image, in: CGRect)` |

## 注意点

- JSXは Illustrator 座標系（左上原点、Y軸下向きが +）とは異なり、Y軸上向きが正（アートボードの top が大きい値）
- Swift `CGContext` は基本「左下原点」だが、macOS `NSGraphicsContext` は `isFlipped` でどちらにも切替可能
- 移植時は **座標系を先に決め打ち**（左上原点・Y軸下向き＝SwiftUI標準）にして統一するのが安全
- フォントは Hiragino Sans に置換、サイズは JSX の ptをそのまま引き継ぐ
- 複数案件対応のため、ヘッダー/本文の描画ロジックは JSX より拡張が必要（JSXは単一本文前提）

## 複数案件時のレイアウト（決定事項）

- 各案件の `●案件名` / `→詳細` を縦に列挙
- 画像ブロックは全体で1つ（最下部）
- 本文と画像ブロックの間隔は JSX 同様 6mm
