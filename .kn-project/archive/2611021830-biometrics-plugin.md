# 2611021830 - biometrics-plugin

- Created: 2026-11-02 18:30 / Archived: 2026-11-02
- Issue: N/A（使用者決議不建 issue）
- Milestone: N/A / Base Branch: main

## Summary
官方 plugin `biometrics`：任何時候都能叫起系統的驗證視窗（生物辨識或裝置密碼），回報使用者有沒有通過，並能查詢裝置有哪些驗證方式。plugin 完全不知道它在保護什麼，也不保存任何東西；結果是客戶端判斷，不能當作伺服器憑證。位於 `packages/biometrics`，Android、iOS、macOS、Windows 支援，Linux 不支援。

## Cross-Repo Scope
- 本 repo（`aqutter-plugins`）為主；`aqutter` 的 `docs/plugins.md` 官方 plugin 清單加一列；`aqutter-nuxt-app` 接入示範頁。

## 契約（只留引用）
正本是 `packages/biometrics/src/index.ts` 與 `lib/src/biometrics_plugin.dart`，修訂號 rev 1（2026-11-02 凍結，無變更）。方法 `capabilities`、`authenticate`（`reason` 必填，選填 `title`、`cancelLabel`、`biometricOnly`）；結果一律用狀態（`authenticated`、`cancelled`、`failed`、`locked_out`、`permanently_locked_out`、`unavailable`、`busy`），只有參數不合法才回 `invalid_argument`。

## Key Decisions
- **[範圍]** 只做「驗證一次」，不管理金鑰（使用者選擇）；與 `secure-storage` 的 `requireAuth` 分工。
- **[通用性]** plugin 不知道在保護什麼、任何時候都能叫起（沒有前置條件、不快取）；新增選填的 `title`、`cancelLabel`（使用者要求）。
- **[Windows]** 納入第一版（使用者同意建議）；**[備援]** 預設允許裝置密碼（`biometricOnly: false`）。
- **[結果]** 一律用狀態回傳、不丟例外。
- **[流程]** 直接 main、不建 issue。

## Deviations
- 無契約變更。
- 驗證範圍：Android 實機只驗證 `unavailable`（測試手機沒有螢幕鎖定）與參數錯誤；Windows 驗證 Windows Hello 可用與一次成功的驗證（驗證是在本機由使用者端完成，不是自動化輸入的）；Windows 的取消路徑無法自動化驗證；iOS、macOS 未驗證（無法編譯 Swift）。
- 單元測試以假的驗證器涵蓋狀態對應、參數驗證與 `busy`。

## Impact Files
- `packages/biometrics/**`（new）— plugin 本體、測試、README
- `README.md`（根目錄）— 清單加一列
- `aqutter/docs/plugins.md`（跨 repo）— 清單加一列

## Wiki Changes

無（本 repo 沒有 wiki）。
