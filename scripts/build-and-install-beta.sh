#!/usr/bin/env bash
# =========================================================
# 画像報告書メーカー β — ビルド＆ローカルインストール
# 開発者本人がβ版を /Applications/画像報告書メーカーβ.app として
# 配置する。GitHub Releases への公開はしない。
# 安定版 (/Applications/画像報告書メーカー.app) とは別 Bundle ID
# (com.tyamabe.imagereportmaker.beta) のため並行インストール可能。
# =========================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$REPO_ROOT/ImageReportMaker.xcodeproj"
SCHEME="ImageReportMakerBeta"
CONFIGURATION="Release"
BUILD_DIR="$REPO_ROOT/build"
DISPLAY_NAME="画像報告書メーカーβ"
DEST_DIR="/Applications"

if [ ! -d "$PROJECT" ]; then
    echo "→ Xcodeプロジェクトが存在しないため xcodegen を実行します"
    (cd "$REPO_ROOT" && xcodegen generate)
fi

echo "→ β Release ビルド開始"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

BUILT_APP="$BUILD_DIR/Build/Products/$CONFIGURATION/$SCHEME.app"
if [ ! -d "$BUILT_APP" ]; then
    echo "❌ ビルド成果物が見つかりません: $BUILT_APP" >&2
    exit 1
fi

DEST_APP="$DEST_DIR/$DISPLAY_NAME.app"

if [ -d "$DEST_APP" ]; then
    echo "→ 既存の β アプリを削除: $DEST_APP"
    rm -rf "$DEST_APP"
fi

echo "→ /Applications/ にコピー（β版）: $DEST_APP"
cp -R "$BUILT_APP" "$DEST_APP"

echo "✅ β版インストール完了: $DEST_APP"
echo "   起動: open \"$DEST_APP\""
echo ""
echo "ℹ️ 安定版 (/Applications/画像報告書メーカー.app) は上書きされていません"
