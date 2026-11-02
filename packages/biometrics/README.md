# aqutter-plugin-biometrics

Aqutter plugin：`biometrics`。**隨時叫起系統的驗證視窗**（生物辨識或裝置密碼），回報使用者有沒有通過。它完全不知道你在保護什麼，也不保存任何東西。同一個 repo 同時是 npm 套件（網頁端 API）與 Dart 套件（Flutter 端）。

> **進度**：Dart 端與網頁端已完成，12 個 Dart 單元測試與 1 個網頁端測試通過（以假的驗證器測試狀態對應、參數驗證與 `busy`）。**尚未在任何實機驗證**：系統驗證視窗的實際行為、各平台的例外對應都要實機確認。

## 它做什麼，不做什麼

| 做 | 不做 |
|---|---|
| 叫起系統的驗證視窗，回報結果 | 管理金鑰、儲存機密（請用 `secure-storage` 的 `requireAuth`） |
| 任何時候都能呼叫，沒有前置條件 | 快取「剛驗證過」；每次呼叫都真的跳視窗 |
| 查詢裝置有哪些驗證方式 | 取得或保存任何生物特徵（系統也不提供） |

**重要限制**：結果是這個裝置上、此刻的**客戶端判斷**，網頁端的結果可以被改寫，所以**不能當成伺服器端的憑證**。要向伺服器證明身分請走伺服器的登入流程；要保護機密請用 `secure-storage` 的 `requireAuth`（那是把機密綁在系統金鑰上，沒通過驗證系統層就讀不出來）。

## 安裝

```bash
aqutter plugin add "github:Aqutter/aqutter-plugins#path:/packages/biometrics"
```

`aqutter doctor` 會檢查還缺哪些原生設定：Android 的 `USE_BIOMETRIC` 權限、iOS 與 macOS 的 `NSFaceIDUsageDescription`。另外 Android 的 `MainActivity` 必須繼承 `FlutterFragmentActivity`（CLI 檢查不到，`plugin add` 會提示）。

平台：Android、iOS、macOS、Windows（Windows Hello）。**不支援 Linux**。

## 網頁端

```ts
import { biometrics } from 'aqutter-plugin-biometrics'

const status = await biometrics.authenticate({
  reason: '確認身分以查看帳戶',
  title: '解鎖',             // 選填，只有 Android 使用
  cancelLabel: '取消',        // 選填，Android 與 iOS 使用
  biometricOnly: false,       // 預設 false：沒登錄生物辨識的使用者仍可用裝置密碼
})

if (status === 'authenticated') {
  // 繼續
}

const { available, biometrics: enrolled, types } = await biometrics.capabilities()
```

| `status` | 意義 |
|---|---|
| `authenticated` | 使用者通過驗證 |
| `cancelled` | 使用者取消，或系統中斷了視窗（不算錯誤） |
| `failed` | 驗證沒有通過，可重試 |
| `locked_out` | 嘗試太多次，暫時鎖定 |
| `permanently_locked_out` | 生物辨識被鎖住，需要使用者以裝置密碼解鎖 |
| `unavailable` | 裝置沒有可用的驗證方式；這個平台沒有驗證功能時也是這個值 |
| `busy` | 已經有一個驗證視窗在進行中 |

參數不合法才會拋 `invalid_argument`（`reason` 必填 1 到 100 字；`title` ≤ 60 字；`cancelLabel` ≤ 30 字；`biometricOnly` 必須是布林）。其餘結果一律是狀態。

**plugin 在這個平台用不了時不拋錯**：`authenticate` 回 `'unavailable'`，`capabilities` 回「都沒有」。

## 開發

```bash
pnpm install
pnpm typecheck
pnpm test
flutter pub get
flutter test
```

契約與計畫見根目錄 `.kn-project/plans/`。
