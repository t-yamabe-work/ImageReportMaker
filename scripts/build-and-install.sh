#!/usr/bin/env bash
# =========================================================
# 画像報告書メーカー — ビルド＆インストール
# Release構成でビルドし、/Applications/画像報告書メーカー.app として配置する
# =========================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$REPO_ROOT/ImageReportMaker.xcodeproj"
SCHEME="ImageReportMaker"
CONFIGURATION="Release"
BUILD_DIR="$REPO_ROOT/build"
DISPLAY_NAME="画像報告書メーカー"
DEST_DIR="/Applications"

if [ ! -d "$PROJECT" ]; then
    echo "→ Xcodeプロジェクトが存在しないため xcodegen を実行します"
    (cd "$REPO_ROOT" && xcodegen generate)
fi

echo "→ Release ビルド開始"
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
    echo "→ 既存のアプリを削除: $DEST_APP"
    rm -rf "$DEST_APP"
fi

echo "→ /Applications/ にコピー（日本語名）: $DEST_APP"
cp -R "$BUILT_APP" "$DEST_APP"

echo "✅ インストール完了: $DEST_APP"
echo "   起動: open \"$DEST_APP\""
