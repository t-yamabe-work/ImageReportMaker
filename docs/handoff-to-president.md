# 社長AI向け引き渡し指示書

## プロジェクト概要
- **名称**：画像報告書メーカー
- **目的**：社内で日次業務報告メールに添付する「画像報告書」をIllustrator+JSX運用から置き換えるmacOSネイティブアプリ
- **配置**：`~/Developer/画像報告書メーカー/`
- **現状**：骨組み生成済み、ビルド通過（Debug）、初回コミット `45270aa` 完了
- **要件定義書**：Obsidian保管庫内 `画像報告書アプリを作ろう/00_プロジェクト概要.md`
- **リポジトリ内ドキュメント**：
  - `docs/layout-spec.md` — JSXから抽出した数値仕様テーブル
  - `docs/jsx-reference.md` — 移植メモと座標系変換の注意点
  - `docs/block_grid_a4_v1.0.1.jsx` — 元JSXコピー
  - `改修ログ.md` — リポジトリ内作業ログ

## 技術スタック
- Swift 6.0 / SwiftUI（macOS 13+）
- SPM：`Core/Package.swift`（モジュール名 `ReportCore`）
- xcodegen：`project.yml`（`.xcodeproj` は生成物）
- バンドルID：`com.tyamabe.imagereportmaker`
- 表示名：画像報告書メーカー
- 厳密並行性：`SWIFT_STRICT_CONCURRENCY: complete`

## v0.1.0 MVP ゴール
空アプリに機能を積んで、以下ができる状態にする：
1. 氏名・日付・単一案件の入力
2. 画像D&D（並び替えは v0.2.0 でOK、MVP は D&D順のみ）
3. JSX互換のグリッドレイアウト計算（1〜5列自動選択）
4. JPG書き出し（ファイル名 `YYMMDD.jpg`、保存先デスクトップ）
5. プレビュー表示（実寸不要、ウィンドウ内縮小）

## worker 分担（KAKUSU互換の境界）

### worker1 — Core実装
**担当ファイル範囲**：`Core/Sources/ReportCore/` 配下のみ
**タスク**：
1. `Layout/GridLayoutCalculator.swift` の TODO を実装
   - JSX `simulateGridLayout` を Swift に移植
   - `minColumns`〜`maxColumns` の範囲で全高 ≤ `maxBlockHeightMm` になる最小列数を選ぶ
   - 満たせない場合は `maxColumns` を使う
2. `Rendering/ReportRenderer.swift` の TODO を実装
   - `CGContext` または `NSGraphicsContext` で A4ページをオフスクリーン描画
   - ヘッダー／本文／画像グリッド／外枠を配置
   - JPG/PNG は `ImageIO` でエンコード
   - SVG は `SVGExporter` に委譲
3. `Rendering/SVGExporter.swift` の TODO を実装
   - SVG文字列を組み立てる
   - Hiragino Sans TTF を Base64 エンコードし、@font-face で埋め込み
   - 画像は `data:image/png;base64,...` 形式でインライン埋め込み
4. `Core/Tests/ReportCoreTests/` にユニットテスト追加
   - 列数決定ロジックのエッジケース（画像0枚、超大量、超ワイド画像 等）
   - 座標変換の往復（mm ↔ pt）
**参照**：`docs/layout-spec.md`, `docs/jsx-reference.md`

### worker2 — プロジェクト設定・アイコン
**担当ファイル範囲**：`project.yml`、`Apps/ImageReportMaker/Info.plist`、`Apps/ImageReportMaker/Resources/`、`scripts/` 配下のみ
**タスク**：
1. `Apps/ImageReportMaker/Resources/Assets.xcassets/AppIcon.appiconset/` を作成
   - 仮アイコン（シンプルな色ブロックにテキスト「画報」 等でOK、本格アイコンは v1.0.0 で差し替え）
   - 16/32/128/256/512 の各サイズ、@2x含む
2. `project.yml` の sources に Resources を追加
3. `Info.plist` の細部調整（CFBundleIconName 等）
4. `scripts/build-and-install.sh` の動作確認（`/Applications/画像報告書メーカー.app` が生成されるか）

### worker3 — UI実装
**担当ファイル範囲**：`Apps/ImageReportMaker/Views/`、`Apps/ImageReportMaker/ViewModels/`、`Apps/ImageReportMaker/ContentView.swift` のみ
**タスク**：
1. `Views/HeaderFormView.swift` を新規作成
   - 氏名テキストフィールド（onChange で `preferences.authorName` に保存）
   - 日付 DatePicker（デフォルト今日、手動変更可）
   - 曜日は日付から自動表示
2. `Views/CaseListView.swift` を新規作成
   - 案件（●タイトル + →詳細）のリスト
   - 追加／削除／並び替え（`.onMove`）
   - 各項目はインデント表示
   - v0.1.0 MVP は単一案件でもOK、複数対応は v0.2.0
3. `Views/ImageDropZoneView.swift` を新規作成
   - NSItemProvider でのD&D受入（png/jpg）
   - 受け入れた画像を `viewModel.imageURLs` に追加
   - サムネイル表示
   - MVPは並び替えなし、削除のみ
4. `Views/PreviewView.swift` を新規作成
   - `ReportRenderer.render(model:options:)` の結果を NSImage で表示
   - `.scaleToFit` でウィンドウ内縮小
5. `Views/ExportPanel.swift` を新規作成
   - 形式セレクト（JPG/PNG/SVG）
   - ファイル名入力（デフォルト `YYMMDD.jpg`、前回名を記憶＝A案）
   - 保存先（初回デスクトップ、2回目以降前回）
   - 書き出しボタン
6. `ContentView.swift` を書き換え
   - 左：フォーム（HeaderForm + CaseList + ImageDropZone + ExportPanel）
   - 右：PreviewView
7. `ViewModels/ReportViewModel.swift` を実装拡充
   - 各操作メソッド（addCase, removeCase, addImages, removeImage, export）
   - `ReportCore.ReportRenderer` 呼び出し

## 作業ルール（全worker共通）
- 担当ファイル範囲**外**には触れない（コンフリクト防止）
- 変更は小刻みにコミット
- コミットメッセージは日本語可
- 各commit末尾に担当を明記：`[worker1]` / `[worker2]` / `[worker3]`
- TODO/FIXME を残す場合は、誰の担当かを明記
- ビルドが通らない変更はコミットしない
- `ReportCore.*` の API を変更したい場合は必ず全worker合意（boss経由で調整）

## 完了基準（v0.1.0 MVP）
- [ ] `xcodebuild Debug build` 成功
- [ ] `xcodebuild test` で `ReportCoreTests` 全部緑
- [ ] アプリ起動→氏名・日付・案件入力→画像D&D→プレビュー表示→JPG書き出し（`~/Desktop/YYMMDD.jpg`）が一連で動く
- [ ] JSX の出力と視覚的に近い（多少のズレはOK、v0.1.5で調整可能）

## 注意事項
- フォントは **macOS標準の Hiragino Sans のみ使用**。存在しないフォント指定は絶対にしない（エラー回避最優先）
- 社内機密画像を扱うため、外部送信ロジック・ネットワークアクセスは**一切入れない**
- サンドボックスは未設定（entitlements空）、ファイルアクセスは自由
- Developer Program 非加入、コード署名はad-hoc（`CODE_SIGN_IDENTITY="-"`）
- macOSフォルダ名に日本語を含む（`~/Developer/画像報告書メーカー/`）。Swift識別子・ターゲット名・スキーム名はASCII固定のため問題なし

## 完了報告
全worker完了後、社長AIは人間（運用者）に以下を報告：
- ビルド・テスト結果
- アプリの実動作確認結果（起動＋1回JPG書き出し）
- 改修ログ.md への追記完了
