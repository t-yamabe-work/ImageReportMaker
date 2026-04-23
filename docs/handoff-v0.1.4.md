# v0.1.4 引き渡し指示書

## プロジェクト状況
- **リポジトリ**: `~/Developer/画像報告書メーカー/`
- **カレントブランチ**: `develop`（作業はすべてここにコミット、main には触らない）
- **タグ打ち／リリース**: 人間が後で実施、worker は不要
- **β並行インストール**: 完了済み。`scripts/build-and-install-beta.sh` で β版を `/Applications/画像報告書メーカーβ.app` に配置できる（安定版と独立、UserDefaults も別）

## v0.1.4 で対応する修正点

人間運用者確定済の3仕様＋2修正（改修ログ.md の F-1〜F-5）:

### F-1. 案件の明示的な削除ボタン（worker3）
- 各案件カードの右上に × ボタン
- 押下で `ViewModel.removeCase(at:)` を即実行（確認ダイアログなし）
- cases が1件のみの時は × を無効化（非表示 or .disabled）
- スワイプ削除 / .onDelete も互換のため残してOK

### F-2. 詳細文の複数対応 — **仕様A採用**（worker1 + worker3）
- `ReportCase` モデルを変更: `detail: String` → `details: [String]`
- 1案件 = ●タイトル + →詳細1 + →詳細2 + …（任意個数）
- **新 public API**（worker1 が定義、worker3 が呼び出し側を合わせる）:

```swift
public struct ReportCase: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var details: [String]

    public init(id: UUID = UUID(), title: String, details: [String]) {
        self.id = id
        self.title = title
        self.details = details
    }
}
```

- 旧 `detail: String` は完全撤去。`init(title:detail:)` も削除（互換シムは作らない、develop ブランチなのでOK）
- ViewModel 側の永続化（AppPreferences.topCaseDetail）のマイグレーション:
  - 旧キー `topCaseDetail: String?` → 新キー `topCaseDetails: [String]?`（JSON保存）
  - 旧データがあれば `[oldString]` に変換して新キーへ書き戻し、旧キーは削除
  - defaultCaseDetail も `"を進行いたしました。"`（単要素配列）でOK
- **レンダリング**（worker1）:
  - `ReportRenderer.prepareLayout`: 案件ごとに `details` を全部レンダリング対象にする
  - 各 `→詳細i` は別々に wrapText して縦に積む
  - 案件内の詳細間ギャップは `caseDetailFontSizePt * 0.35` 程度
  - `CaseBlock` に `detailLines` を `[[WrappedLine]]` の配列として保持、または `detailSegments: [(lines: [WrappedLine], baselineYPt: Double)]` 形式に
  - SVGExporter も同構造で出力
- **UI**（worker3）:
  - 各案件カード内に「＋詳細を追加」ボタン（`details.append("")`）
  - 各詳細行に × 削除ボタン（`details.remove(at:)`、ただし `details.count >= 2` の時のみ有効、最後の1つは削除不可）
  - 各詳細はテキストフィールドで編集可能
  - タイトル行と詳細行は視覚的にインデント（既存の見た目を維持）

### F-3. 画像並び替えUI — **仕様B採用**（worker3）
- ImageDropZoneView のサムネ一覧を LazyVGrid + `.onDrag` / `.onDrop` で並び替え可能に
- 各サムネを掴んで別の位置にドロップすると配列が入れ替わる
- `ViewModel.imageURLs` を直接 `move(fromOffsets:toOffset:)` で更新
- ドラッグ中のプレビューは SwiftUI の `NSItemProvider` 標準で十分（派手なカスタムは不要）
- 既存の外部からの D&D 追加機能（ファイルドロップで画像追加）は維持。並び替えと競合しないよう NSItemProvider の種別で区別:
  - 外部ファイル: `UTType.fileURL` / `UTType.image` → `addImages`
  - 内部並び替え: カスタム UTI (例: `"com.tyamabe.imagereportmaker.image-index"`) または `Text` で index 文字列 → `moveImage(from:to:)`

### F-4. 太字（Bold）の撤去（worker1）
- `ReportRenderer.swift` の drawHeader: 氏名 `weight: .w6` → `.w3`
- `ReportRenderer.swift` の drawBody: 案件タイトル `weight: .w6` → `.w3`
- `SVGExporter.swift` の textElement 呼び出し: 氏名・タイトルの `cls: "t-w6"` → `"t-w3"`
- `.t-w6` クラス自体は SVG CSS に残しても使われていない。削除してもOK（worker1 の判断）

### F-5. 案件・詳細フォントサイズ（worker1）
- `LayoutConstants.swift`:
  - `caseTitleFontSizePt: 22.30` → **`17.0`**
  - `caseDetailFontSizePt: 21.29` → **`17.0`**
- `caseDetailLineHeightMultiple: 1.25` は維持
- `caseDetailOffsetPt: 38.13` は caseTitleFontSize が小さくなった分、相対的に広すぎる可能性あり。`caseTitleFontSizePt * 1.6` 程度に見直すか、固定値のまま実機確認してから調整

## 担当分担

### worker1（Core、Core/Sources/ReportCore/ 配下のみ）
- W1-F2: `ReportCase` モデル変更（`details: [String]`）
- W1-F4: 太字撤去（Renderer / SVGExporter の weight指定）
- W1-F5: LayoutConstants のフォントサイズ変更
- W1-F2-render: Renderer/SVGExporter の複数詳細レンダリング対応
- テスト更新・追加（複数詳細、フォントサイズ、太字除去の検証）

### worker3（UI、Apps/ImageReportMaker/ 配下のみ）
- W3-F1: CaseListView に × 削除ボタン（1件時は無効）
- W3-F2-UI: 各案件内に「＋詳細を追加」ボタン、各詳細行に × 削除ボタン、editable TextField
- W3-F2-VM: ReportViewModel / AppPreferences の `topCaseDetail: String?` → `topCaseDetails: [String]?` 移行（旧データ変換含む）
- W3-F3: ImageDropZoneView の並び替え（LazyVGrid + onDrag/onDrop）

### worker2（待機）
- 今回の範囲には担当タスクなし
- β版も `project.yml` 既定義済み、新規設定変更なし

## 作業ルール（再掲）
- **ブランチは develop 固定**。main には触らない
- 担当ファイル範囲**外**には触れない
- 小刻みコミット、メッセージ末尾 `[worker1]` / `[worker3]`
- ビルドが通らない変更はコミットしない
- 新 API 互換性：worker1 が `ReportCase.details: [String]` を push したら、worker3 はすぐそれに追従。並行作業の場合は両者で新 API 合意済みの前提で各々実装

## 完了基準
- [ ] `cd Core && swift test` 全緑（新テスト含む）
- [ ] `xcodebuild -scheme ImageReportMaker -configuration Debug build` 成功（安定版ターゲット）
- [ ] `xcodebuild -scheme ImageReportMakerBeta -configuration Debug build` 成功（β版ターゲット）
- [ ] `scripts/build-and-install-beta.sh` 実行で `/Applications/画像報告書メーカーβ.app` 更新
- [ ] 改修ログ.md に v0.1.4 セクション追記

**完了後、人間が実機確認 → OK なら develop → main マージ → v0.1.4 タグ → GitHub Release を人間が実施**。worker は `/Applications/画像報告書メーカー.app`（安定版）には一切触らない。
