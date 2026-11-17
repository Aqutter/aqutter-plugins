# 驗證報告：透明 WebView 下的原生地圖（方案 2）

- 日期：2026-11-17　裝置：ASUS I006D、Android 13（API 33）、Impeller
- 分支：`Aqutter/aqutter` 與 `Aqutter/aqutter-plugins` 的 `feature/2611171140-map-passthrough-spike`（不併入主幹）
- 範圍：只驗證 Android；iOS 沒有設備，未驗證

## 結論

**可行，且效能明顯好於鏡像。** 地圖直接畫在 Flutter 裡、放在透明 WebView 下面，網頁 HTML 疊在地圖之上，拖曳、縮放、點擊都能由網頁轉成語意手勢驅動地圖。建議做成正式功能，但有三個前置問題要先處理（見「限制與待處理」）。

## 驗證項目

| 項目 | 結果 | 依據 |
|---|---|---|
| 地圖透過透明 WebView 顯示 | 通過 | 螢幕截圖：整面 Google 地圖，Google 標誌與標記都在 |
| HTML 疊層在地圖之上 | 通過 | 返回鈕、座標條、五個按鈕疊在地圖上正常顯示與點擊 |
| 單指拖曳 | 通過 | `adb input swipe` 左拖 500px，經度 121.565 → 121.615，地圖跟著移動 |
| 點擊回報經緯度 | 通過 | 點擊後顯示 `tap 25.0485, 121.6152` |
| 雙指縮放 | 通過 | DevTools 合成雙指放大一倍，z13.1 → z14.4（略多於一級，未精確量化） |
| 雙擊放大 | 未驗證 | 只有單元測試涵蓋 |
| 鏡像模式不受影響（預設） | 通過 | 兩個開關預設 false，同一支手機實測鏡像仍正常顯示 |

## 效能（同一支手機、同一個拖曳腳本：左右各 500px、每次 350ms，連續約 17 秒）

| 指標 | 不鏡像（方案 2） | 鏡像（現況） |
|---|---|---|
| 視窗（HWUI）掉幀 | 0 / 1156 幀（0%） | 223 / 773 幀（28.9%） |
| 視窗幀時間 p90／p99 | 6 ms／10 ms | 34 ms／48 ms |
| Missed Vsync | 0 | 165 |
| 高輸入延遲 | 0 | 113 |
| Flutter surface 呈現間隔 中位數 | 16.7 ms（三次一致，約 60 fps） | 16.8～33.5 ms，p90 50～67 ms |
| 超過 33 ms 的間隔數（每次 126 幀內） | 0、0、1 | 70、57、65 |

注意：兩次量測都把 mirror-demo 的底層關掉，避免它的動畫干擾；樣本是單一裝置、單一手勢腳本，沒有量電量與記憶體。

## 做法（本次實驗的實作）

- 殼：`AQUTTER_WEBVIEW_TRANSPARENT=true` 時 WebView 設為透明背景。
- plugin：`AQUTTER_MAP_PASSTHROUGH=true` 時 `buildUnderlay` 直接回傳 `GoogleMap`（不包 `AqutterNative`）；新增 `mode`、`gesture` handler；網頁端建立透明元素並把 pointer 事件換成 `pan`／`pinch`／`doubleTap`／`tap`，沿用既有 `AqutterMapGestureMapper`。
- 頁面：`html`、`body` 與地圖容器、外層背景層（例如 `bg-surface`）都要透明，這是在 nuxt-app 以暫時 CSS 做的（已還原）。

## 限制與待處理

1. **殼的初始透明設定在 Android 沒有生效。** 只設 `transparentBackground: true` 時畫面仍是白的；用 DevTools 強制底色透明就會透出底層。實驗中改成建立 WebView 後先設 `false` 再設 `true` 才生效（見殼的 `_onWebViewCreated`）。根因未查：核心的初始套用在 `AqutterWebView.kt:364`、執行期更新在 `:940`，兩條路徑看起來都對，但行為不同。正式版應在 aqutter_core 查清楚並修在核心，而不是在殼做兩段式設定。
2. **所有 plugin 的底層疊在一起。** 殼把每個 plugin 的 `buildUnderlay` 依序放進同一個 Stack，nuxt-app 另外裝的 mirror-demo 底層（不透明的格線動畫）會蓋在地圖上面。實驗時暫時關掉它。正式版需要決定多個底層的順序或只允許一個。
3. **頁面背景要由網頁配合。** 網頁任何一層有不透明背景就看不到地圖，目前沒有機制保證，正式版至少要在 README 說明，最好由 plugin 提供一個明確的「進入／離開透明模式」呼叫，離開時恢復不透明（目前殼是啟動時一次性全域設定，所有頁面都透明）。
4. **手勢轉送是 JS 側換算。** 單指拖曳、雙指縮放、短按、雙擊都在網頁端判斷（短按 250 ms、位移 8 px、雙擊 300 ms），手感沒有與原生地圖逐項比對；慣性滑動（fling）與旋轉、傾斜沒有做。
5. **只在 texture 模式驗證。** Android 地圖維持原本的 texture 模式；Hybrid Composition 模式沒有測。
6. **未驗證：** iOS（沒有設備）、桌面平台（本來就用 JS 地圖）、鍵盤彈出、WebView 內捲動與地圖手勢衝突、電量與記憶體。

## 建議

- 做成正式功能，順序：先在 aqutter_core 查出透明初始設定不生效的原因（限制 1），再設計「透明模式」的啟用方式與底層順序（限制 2、3），最後補慣性滑動並實測 iOS。
- 驗證用的兩個 `dart-define` 鍵是實驗性質；轉正時要依 AGENTS.md 第 3 條三處成對（Dart 鍵、`aqutter-cli` 範本、`docs/environment.md`），或改成 plugin 設定而不是編譯期鍵。
