# 画像報告書メーカー

日次業務報告メールに添付する「画像報告書」を、ドラッグ＆ドロップで楽に作れるmacOSアプリ。

---

## 📥 ダウンロード

**[→ 最新版をダウンロード (.zip)](https://github.com/t-yamabe-work/ImageReportMaker/releases/latest)**

ページを開いたら、緑の「Assets」欄にある `ImageReportMaker-v◯.◯.◯.zip` をクリックすると ダウンロードが始まります。

## 🚀 はじめての使い方

### 1. インストール
1. ダウンロードした `.zip` をダブルクリックして解凍
2. 出てきた `画像報告書メーカー.app` を、**Finderの「アプリケーション」フォルダにドラッグ**

### 2. 初回起動（重要）
ダブルクリックで起動すると macOS が「開発元を確認できません」と警告します。以下のいずれかで回避：

- **右クリック→「開く」** をクリックし、出てきた警告で再度「開く」
- または**システム設定 → プライバシーとセキュリティ** の下の方に出てくる許可ボタンを押す

一度この手順で開けば、2回目以降はダブルクリックだけで起動できます。

### 3. 使い方
1. 氏名を入力（1回入れれば次回から自動入力）
2. 日付は自動。深夜作業で日付跨ぎの時は手動調整可
3. 案件名と詳細文を入力
4. スクショ画像を **画像エリアにドラッグ＆ドロップ**（複数OK）
5. 右側のプレビューで仕上がり確認
6. 「書き出し」ボタンで保存 → メールに添付

### 動作要件
- macOS 13 (Ventura) 以降
- Intel / Apple Silicon 両対応

---

## ライセンス

個人利用および組織内利用に限り、複製・改変・再配布を自由に行えます。
商用利用は禁止します。詳細は [LICENSE.md](LICENSE.md) を参照してください。

---

<details>
<summary><strong>🛠 開発者向け情報</strong>（クリックで展開）</summary>

## 技術概要

- プラットフォーム：macOS 13+
- 言語：Swift 6.0 / SwiftUI
- ビルド：SPM (`Core/`) + xcodegen (`project.yml`)
- バンドルID：`com.tyamabe.imagereportmaker`
- 設計：Illustrator + JSX `画像報告書 block_grid A4 対応 v1.0.1.jsx` の置き換え

## ソースからビルド

### 必要なツール

- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### プロジェクト生成

```sh
xcodegen generate
open ImageReportMaker.xcodeproj
```

### `/Applications/` へインストール

```sh
scripts/build-and-install.sh
```

## ディレクトリ構成

```
.
├── Apps/ImageReportMaker/      # SwiftUIアプリ本体
├── Core/                       # SPMパッケージ（ReportCore）
│   ├── Package.swift
│   ├── Sources/ReportCore/
│   └── Tests/ReportCoreTests/
├── docs/                       # 設計ドキュメント
│   ├── layout-spec.md          # レイアウト数値仕様
│   ├── jsx-reference.md        # JSX→Swift移植メモ
│   ├── block_grid_a4_v1.0.1.jsx # 元JSXコピー
│   └── handoff-to-president.md # 多エージェントAI開発フロー引き渡し書
├── scripts/                    # ビルド・配置スクリプト
├── project.yml                 # xcodegen設定
└── 改修ログ.md                  # 作業ログ
```

## Windows版等への移植

Coreレイアウトロジックは `Core/Sources/ReportCore/Layout/GridLayoutCalculator.swift` に集約されています。Swift以外の言語へのポートは、この Calculator と `ReportRenderer.prepareLayout` を起点に着手できます。数値仕様は `docs/layout-spec.md` に全テーブル化済み。

</details>
