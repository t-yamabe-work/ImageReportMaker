/**
 * 画像報告書 block_grid A4 対応 v1.0.1
 *
 * 概要：
 *  - 選択されたオブジェクトから、
 *      ・本文テキストフレーム 1つ
 *      ・画像（PlacedItem / RasterItem）複数
 *    を探し、
 *    「テキストの左揃え＋下 6mm」に A4 幅グレー背景＋画像グリッドを自動レイアウトする。
 *
 * 前提：
 *  - A4 縦のドキュメントを想定（幅 210mm）。
 *  - 単位は Illustrator 側が pt でも mm でも問題なし（内部で mm に換算）。
 */

(function () {
    // ---- 定数 ----
    var MM = 72 / 25.4; // 1mm -> pt 換算
    var GAP_MM = 3;     // 画像間のギャップ（縦・横）mm
    var MAX_HEIGHT_MM = 1200; // ブロック全体の高さ上限 mm
    var CONTENT_MARGIN_X_MM = 3; // グレー背景左右からコンテンツまでのマージン mm
    var GRAY_MARGIN_Y_MM = 5;    // グレー背景の上下マージン mm
    var TEXT_TO_BLOCK_GAP_MM = 6;// テキスト bottom から画像ブロック top まで mm

    // ---- ドキュメント取得 ----
    if (app.documents.length === 0) {
        alert("ドキュメントが開かれていません。");
        return;
    }
    var doc = app.activeDocument;

    // ---- アートボード情報 ----
    var abIndex = doc.artboards.getActiveArtboardIndex();
    var ab = doc.artboards[abIndex].artboardRect; // [left, top, right, bottom]
    var abLeft = ab[0];
    var abTop = ab[1];
    var abRight = ab[2];
    var abBottom = ab[3];

    var abWidthPt = abRight - abLeft;
    var abWidthMm = abWidthPt / MM;

    // グレー背景はアートボード幅いっぱい
    var grayWidthMm = abWidthMm;
    var contentWidthMm = grayWidthMm - CONTENT_MARGIN_X_MM * 2;
    var contentLeftMm = CONTENT_MARGIN_X_MM;

    // ---- 選択オブジェクトからテキストと画像を抽出 ----
    if (!doc.selection || doc.selection.length === 0) {
        alert("本文テキストと画像を選択してから実行してください。");
        return;
    }

    var sel = doc.selection;
    var textFrame = null;
    var imageItems = [];

    for (var i = 0; i < sel.length; i++) {
        var it = sel[i];
        if (it.typename === "TextFrame") {
            if (textFrame === null) {
                textFrame = it;
            } else {
                alert("テキストフレームが複数選択されています。本文テキストは 1つだけ選択してください。");
                return;
            }
        } else if (it.typename === "PlacedItem" || it.typename === "RasterItem") {
            imageItems.push(it);
        } else if (it.typename === "GroupItem") {
            collectImagesFromGroup(it, imageItems);
        }
    }

    if (textFrame === null) {
        alert("本文テキストフレームが選択されていません。");
        return;
    }
    if (imageItems.length === 0) {
        alert("画像（PlacedItem / RasterItem）が選択されていません。");
        return;
    }

    // ---- テキストフレームの位置とサイズを調整（左 3mm／幅 contentWidthMm） ----
    var tfBounds = textFrame.geometricBounds.slice(0); // [left, top, right, bottom]
    var tfLeft = tfBounds[0];
    var tfTop = tfBounds[1];
    var tfRight = tfBounds[2];
    var tfBottom = tfBounds[3];

    var targetLeftPt = abLeft + contentLeftMm * MM;
    var dxText = targetLeftPt - tfLeft;

    textFrame.translate(dxText, 0);

    // 幅を contentWidthMm に変更
    tfBounds = textFrame.geometricBounds.slice(0);
    tfLeft = tfBounds[0];
    tfTop = tfBounds[1];
    tfRight = tfBounds[2];
    tfBottom = tfBounds[3];

    var targetRightPt = tfLeft + contentWidthMm * MM;
    textFrame.geometricBounds = [tfTop, tfLeft, targetRightPt, tfBottom];

    tfBounds = textFrame.geometricBounds.slice(0);
    tfBottom = tfBounds[3];
    var textBottomPt = tfBottom;

    // ---- 画像サイズの収集（mm 単位） ----
    var imgData = [];
    for (var j = 0; j < imageItems.length; j++) {
        var item = imageItems[j];
        var gb = item.geometricBounds; // [L, T, R, B]
        var wPt = gb[2] - gb[0];
        var hPt = gb[1] - gb[3];
        var wMm = wPt / MM;
        var hMm = hPt / MM;

        imgData.push({
            item: item,
            wMm: wMm,
            hMm: hMm
        });
    }

    // ---- 列数 1〜5 を試算して最適列数を決定 ----
    var bestCols = 5;
    var bestHeightMm = null;

    for (var cols = 1; cols <= 5; cols++) {
        var layoutInfo = simulateGridLayout(imgData, cols, contentWidthMm, GAP_MM);
        var gridHeightMm = layoutInfo.totalHeightMm;
        var blockHeightMm = gridHeightMm + GRAY_MARGIN_Y_MM * 2;

        if (blockHeightMm <= MAX_HEIGHT_MM) {
            bestCols = cols;
            bestHeightMm = blockHeightMm;
            break;
        }
    }

    if (bestHeightMm === null) {
        var layoutInfo5 = simulateGridLayout(imgData, 5, contentWidthMm, GAP_MM);
        bestCols = 5;
        bestHeightMm = layoutInfo5.totalHeightMm + GRAY_MARGIN_Y_MM * 2;
    }

    // ---- 最適列数でレイアウト情報を再計算 ----
    var layout = simulateGridLayout(imgData, bestCols, contentWidthMm, GAP_MM);
    var rowHeights = layout.rowHeights;
    var totalGridHeightMm = layout.totalHeightMm;
    var rows = rowHeights.length;

    var colWidthMm = (contentWidthMm - GAP_MM * (bestCols - 1)) / bestCols;

    // ---- 画像をリサイズ（幅 = colWidthMm） ----
    for (var k = 0; k < imgData.length; k++) {
        var d = imgData[k];
        var item2 = d.item;

        var gb2 = item2.geometricBounds;
        var wPt2 = gb2[2] - gb2[0];
        var currentWidthMm = wPt2 / MM;
        if (currentWidthMm <= 0) continue;

        var scalePercent = (colWidthMm / currentWidthMm) * 100;

        item2.resize(
            scalePercent,
            scalePercent,
            true,
            true,
            true,
            true
        );
    }

    // ---- 画像をグリッドに並べる ----
    var contentLeftPt = abLeft + contentLeftMm * MM;
    var gapPt = GAP_MM * MM;
    var grayMarginTopPt = GRAY_MARGIN_Y_MM * MM;

    // グレー背景の top：テキスト bottom から 6mm 下
    var blockTopPt = textBottomPt - TEXT_TO_BLOCK_GAP_MM * MM;

    var currentRowTopPt = blockTopPt - grayMarginTopPt;

    var idx = 0;
    var rowIndex, colIndex;

    for (rowIndex = 0; rowIndex < rows; rowIndex++) {
        var rowHeightPt = rowHeights[rowIndex] * MM;

        for (colIndex = 0; colIndex < bestCols; colIndex++) {
            if (idx >= imgData.length) break;
            var d2 = imgData[idx];
            var item3 = d2.item;

            var gb3 = item3.geometricBounds;
            var wPt3 = gb3[2] - gb3[0];
            var hPt3 = gb3[1] - gb3[3];

            var leftPt = contentLeftPt + (colWidthMm * MM + gapPt) * colIndex;
            var topPt = currentRowTopPt;

            item3.position = [leftPt, topPt];

            idx++;
        }

        currentRowTopPt -= (rowHeightPt + gapPt);
    }

    // ---- グレー背景の描画 ----
    var grayWidthPt = grayWidthMm * MM;
    var grayHeightMm = totalGridHeightMm + GRAY_MARGIN_Y_MM * 2;
    var grayHeightPt = grayHeightMm * MM;

    var grayLeftPt = abLeft;
    var grayTopPt = blockTopPt;

    var grayRect = doc.pathItems.rectangle(
        grayTopPt,
        grayLeftPt,
        grayWidthPt,
        grayHeightPt
    );
    grayRect.filled = true;
    grayRect.stroked = false;
    grayRect.fillColor = makeGray(doc, 10); // 10%K グレー

    // ---- 画像＋背景をグループ化 ----
    var groupItems = [grayRect];
    for (var m = 0; m < imageItems.length; m++) {
        groupItems.push(imageItems[m]);
    }

    var grp = doc.groupItems.add();
    for (var n = 0; n < groupItems.length; n++) {
        groupItems[n].move(grp, ElementPlacement.PLACEATEND);
    }

    // ★グレー背景をグループ内の最背面へ
    grayRect.zOrder(ZOrderMethod.SENDTOBACK);

    doc.selection = [grp];

    alert("画像ブロックのレイアウトが完了しました。（列数: " + bestCols + "）");

    // ========= 補助関数 =========

    function collectImagesFromGroup(group, outArray) {
        for (var i = 0; i < group.pageItems.length; i++) {
            var it = group.pageItems[i];
            if (it.typename === "PlacedItem" || it.typename === "RasterItem") {
                outArray.push(it);
            } else if (it.typename === "GroupItem") {
                collectImagesFromGroup(it, outArray);
            }
        }
    }

    function simulateGridLayout(imgDataArr, cols, contentWidthMm, gapMm) {
        var colWidthMm = (contentWidthMm - gapMm * (cols - 1)) / cols;
        var rowHeights = [];
        var rowIndex, idx, hScaled;

        for (idx = 0; idx < imgDataArr.length; idx++) {
            var d = imgDataArr[idx];
            var scale = colWidthMm / d.wMm;
            hScaled = d.hMm * scale;

            rowIndex = Math.floor(idx / cols);
            if (rowHeights[rowIndex] == null) {
                rowHeights[rowIndex] = hScaled;
            } else {
                if (hScaled > rowHeights[rowIndex]) {
                    rowHeights[rowIndex] = hScaled;
                }
            }
        }

        var totalHeightMm = 0;
        for (rowIndex = 0; rowIndex < rowHeights.length; rowIndex++) {
            totalHeightMm += rowHeights[rowIndex];
            if (rowIndex < rowHeights.length - 1) {
                totalHeightMm += gapMm;
            }
        }

        return {
            rowHeights: rowHeights,
            totalHeightMm: totalHeightMm
        };
    }

    function makeGray(doc, k) {
        var c = new CMYKColor();
        c.cyan = 0;
        c.magenta = 0;
        c.yellow = 0;
        c.black = k;
        return c;
    }

})();
