# Tasks for 2611171140

## Phase 1 — Plugin 不鏡像模式
- [x] [aqutter-plugins] `google_maps_plugin.dart` 讀 `AQUTTER_MAP_PASSTHROUGH`，`buildUnderlay` 走直接繪製分支；`attach` 不強制 texture 模式
- [x] [aqutter-plugins] 新增 `mode`、`gesture` handler，手勢交給 `AqutterMapGestureMapper`
- [x] [aqutter-plugins] `nativeProvider.ts` 不鏡像分支：透明容器、pointer 手勢轉送
- [x] [aqutter-plugins] 單元測試與 `flutter analyze`、`pnpm lint`／`pnpm test`

## Phase 2 — 實機驗證（Android）
- [x] [aqutter-plugins] 需等待 [aqutter]：`AQUTTER_WEBVIEW_TRANSPARENT` 開關完成
- [x] [aqutter-plugins] 在 nuxt-app 以本機路徑覆寫殼與 plugin，兩鍵皆 true 跑到 ASUS 實機：顯示、HTML 疊層、拖曳、縮放、點擊
- [x] [aqutter-plugins] 以 `dumpsys gfxinfo` 比較不鏡像與鏡像模式的掉幀與幀時間

## Phase 3 — 報告
- [x] [aqutter-plugins] 寫驗證報告（結果、限制、未驗證項目、建議是否做成正式功能）

## Phase 4 — Iteration 1：按需建立底層、手勢正規化、圓角與遮罩實測
- [x] [aqutter-plugins] `buildUnderlay` 只在 `mount` 後顯示；新增 `show`／`hide`；網頁端 `mount`／`destroy` 呼叫
- [x] [aqutter-plugins] `forwardGestures` 改以視窗大小正規化；補測試
- [x] [aqutter-plugins] 在 nuxt-app 建暫時頁面（不進版控）測圓角卡片、圓形遮罩、漸層淡出邊緣、半透明疊層，實機操作並截圖
- [x] [aqutter-plugins] 結果補進 `report.md`

## Phase 5 — Iteration 2：位置同步與滾動實測
- [x] [aqutter-plugins] `hole_layout.dart` 純函式與單元測試
- [x] [aqutter-plugins] `layout` handler：padding、平移、手勢扣平移、延遲記錄
- [x] [aqutter-plugins] 網頁端 `layout` 追蹤（ResizeObserver、scroll 捕獲、resize），測試
- [x] [aqutter-plugins] nuxt-app 暫時頁面加「滾動內容」版面，實機量延遲、截滾動中的錯位
- [x] [aqutter-plugins] 結果補進 `report.md`
