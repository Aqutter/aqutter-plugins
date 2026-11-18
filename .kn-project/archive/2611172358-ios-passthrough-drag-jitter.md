# 2611172358-ios-passthrough-drag-jitter

- Created: 2026-11-19 00:05 / Archived: 2026-11-19 00:16
- Issue: Aqutter/aqutter-plugins#12
- Milestone: N/A / Base Branch: main

## Summary
google-maps 在 `AqutterNativeTouch` 為真（iOS 穿透且觸控直接進原生）時，讓 `GoogleMap` 帶 `EagerGestureRecognizer`，否則上層 WebView 會贏走 Flutter 手勢競技場、封鎖地圖。
其餘情況不宣告手勢，維持原行為。`aqutter_core` 為契約正本；plugin 只依賴殼，`AqutterNativeTouch` 由殼轉出（`Aqutter/aqutter#78`），編譯需要新 core 與殼的 manifest ref。以本機覆寫驗證編譯、測試與 iPad 端到端。

## Cross-Repo Scope
- 契約正本 repo：`aqutter_core`；最終修訂號 `rev 3`（介面：`layout.webRegions`、`AqutterNativeTouch.of(context)`；全文不進 archive，見 `aqutter_core` 的歸檔與程式碼）。
- 參與 repo 與 issue：`aqutter_core`（`Aqutter/aqutter_core#35`，契約與核心路由）、`aqutter-js`（`Aqutter/aqutter-js#20`，取樣回報 `webRegions`）、`aqutter-plugins`（`Aqutter/aqutter-plugins#12`，google-maps 宣告手勢）、`aqutter`（`Aqutter/aqutter#78`，殼轉出 `AqutterNativeTouch`）。共用計畫 ID `2611172358-ios-passthrough-drag-jitter`，共用分支名 `feature/2611172358-ios-passthrough-drag-jitter`。
- 執行順序相依：core 的契約凍結後 js、plugins、殼可平行；plugin 與殼的編譯依賴新 core 的 manifest ref（合併後同步）。建議合併次序：core → 殼 → js → plugins，之後 `aqutter` manifest、`aqutter-cli` snapshot、`aqutter-nuxt-app` 鎖定檔前進。

## Key Decisions
- **[調查]** iPad 實機與最新版確認：現行「網頁轉送手勢 → Dart → `moveCamera`」路徑拖地圖會抖；手指直接拖原生地圖不抖（模擬器合成 swipe 不能當判準）。
- **[根因的一半]** Flutter 手勢競技場把觸控判給最上層 WebView、封鎖地圖；但 UIKit 層的 hit test 也要讓路（整個 WebView 範圍的觸控先進它外層的容器），所以需要 Dart 與 UIKit 兩層配合。關掉 WKWebView 捲動追蹤的假設實驗沒有差別，已排除。
- **[設計]** 以觸控起點決定走原生或網頁：網頁端以 `document.elementFromPoint` 取樣回報 `webRegions`；core 把元素矩形扣掉網頁區域後的區域，一邊讓 Dart 的 `NativeTouchGate` 對 hit test 透明、一邊由 iOS `NativeTouchRouter`（window 最上層的透明 view，略過 WebView 外層 `ChildClippingView`）回傳底下的原生 view；plugin 在 `AqutterNativeTouch` 為真時讓原生 view 以 `EagerGestureRecognizer` 宣告手勢。只有 iOS，Android、macOS、Windows 與 mirror 不變；舊 client 不帶 `webRegions` 時行為不變。
- **[Q2]** spike 在 iPad 不過關就停下、只歸檔文件（實際 spike 與完整實作都在 iPad 實機過關，未觸發）。**[Q3]** 沒有 `pointer-events: none` 的網頁覆蓋層照 DOM 語意算網頁區域。
- **[契約變更]** rev 1 → rev 2：plugin 拿到的 context 來自殼套件，改由 core 以 `AqutterNativeTouch.of(context)` 提供，區域邊界歸屬改為不保證（±1px）。rev 2 → rev 3：plugin 只依賴殼，殼要轉出 `AqutterNativeTouch`（殼納入本計畫為第四個 repo，經使用者同意）。
- **[完成後]** commit + 開 PR（base main）；四個 repo 一起開。

## Deviations
- `AqutterNativeTouch` 的取得方式由契約 rev 1 的「context 欄位」改為 rev 3 的「殼轉出的繼承通知器」。
- 本 repo 沒有 wiki，未做 wikification。

## Impact Files
- `packages/google-maps/lib/src/google_maps_plugin.dart:207`（`GoogleMap`、`nativeGestureRecognizers`）— 依 `AqutterNativeTouch` 切換手勢宣告
- `packages/google-maps/test/google_maps_plugin_test.dart` — 手勢宣告切換測試
