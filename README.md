# 画像報告書メーカー

社内で日次業務報告メールに添付する「画像報告書」を生成するmacOSネイティブアプリ。
Illustrator + JSXスクリプトの置き換えが目的。

## 概要

- プラットフォーム：macOS 13+
- 言語：Swift 5.9+ / SwiftUI
- ビルド：SPM (`Core/`) + xcodegen (`project.yml`)
- バンドルID：`com.tyamabe.imagereportmaker`

詳細仕様は Obsidian 保管庫内の
`画像報告書アプリを作ろう/00_プロジェクト概要.md` を参照。

## セットアップ

### 必要なツール

- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### プロジェクト生成

```sh
xcodegen generate
open ImageReportMaker.xcodeproj
```

### `/Applications/` にインストール

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
├── cli/                        # 将来用
├── docs/                       # 設計ドキュメント
├── scripts/                    # ビルド・配置スクリプト
├── project.yml                 # xcodegen設定
└── 改修ログ.md                  # 作業ログ
```

## ライセンス

個人利用のみ。配布・商用利用なし。
