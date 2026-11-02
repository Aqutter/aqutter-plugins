# aqutter-plugin-secure-storage

Aqutter plugin：`secure-storage`。把小量機密（登入 token、金鑰）存進系統的安全儲存，並可要求使用者**通過生物辨識或裝置密碼才能讀出**。同一個 repo 同時是 npm 套件（網頁端 API）與 Dart 套件（Flutter 端）。

> **進度**：Dart 端與網頁端已完成，24 個單元測試通過（以記憶體內的假儲存測試契約與錯誤對應）。**尚未在任何實機驗證**：底層（`flutter_secure_storage`）與驗證視窗的實際行為、各平台的錯誤對應都要實機確認。

## 為什麼不是 `localStorage` 或 `shared_preferences`

| | 這個 plugin | `localStorage`／殼的偏好設定 |
|---|---|---|
| 儲存位置 | iOS／macOS Keychain、Android Keystore 加密、Windows 憑證加密 | 明文檔案 |
| 系統備份 | 不備份（Android 需照下方設定排除） | 會被備份 |
| 讀出條件 | 可要求生物辨識或裝置密碼 | 沒有 |
| 適合 | token、金鑰、小型機密 | 一般設定 |

## 範圍

| 功能 | 做什麼 | 原生設定 |
|---|---|---|
| `storage` | `set`、`get`、`has`、`delete`、`keys`、`clear` | 不需要，但 Android 要排除自動備份 |
| `auth` | `set` 帶 `requireAuth`，之後 `get` 要先驗證 | Android `USE_BIOMETRIC`、iOS／macOS `NSFaceIDUsageDescription`、`MainActivity` 繼承 `FlutterFragmentActivity` |

平台：Android、iOS、macOS、Windows。**`requireAuth` 只有 Android、iOS、macOS**；Windows 回 `auth_unavailable`（不會默默存成不需驗證）。**不支援 Linux**（需要 libsecret，行為差距大）。

## 安裝

```bash
aqutter plugin add aqutter-plugin-secure-storage                    # 全部功能
aqutter plugin add aqutter-plugin-secure-storage --features storage # 只用一般儲存，不需要生物辨識相關設定
```

`aqutter doctor` 會檢查所選功能還缺哪些原生設定（權限與說明文字），CLI 不會替你改原生檔。

### Android 要排除自動備份

Keystore 的金鑰不會隨備份還原，還原後資料會無法解開。請把這個儲存排除在備份之外，例如在 `AndroidManifest.xml` 設定 `android:allowBackup="false"`，或在 `dataExtractionRules`／`fullBackupContent` 排除 `FlutterSecureStorage` 的偏好設定檔。

## 網頁端

```ts
import { secureStorage } from 'aqutter-plugin-secure-storage'

await secureStorage.set('refresh-token', token)                       // 一般項目
await secureStorage.set('card-key', key, { requireAuth: true, prompt: '確認身分以使用金鑰' })

const value = await secureStorage.get('refresh-token')                // 不存在回 null
const key2 = await secureStorage.get('card-key')                      // 會出現系統驗證視窗

if ((await secureStorage.capabilities()).auth) {
  // 這個裝置能用 requireAuth
}
```

| 方法 | 說明 |
|---|---|
| `set(key, value, { requireAuth?, prompt? })` | 同名取代（含條件）。Android 上存入需驗證項目時也會出現驗證視窗。裝置沒有設定任何驗證方式時回 `auth_unavailable` |
| `get(key, { prompt? })` | 項目不存在回 `null`，不是錯誤；需驗證的項目出現系統視窗，取消回 `auth_cancelled`，不會洩漏任何值 |
| `has(key)`、`keys()` | 不讀值，**不會**出現驗證視窗；`keys()` 只列這個 plugin 寫的鍵 |
| `delete(key)` | 不存在也算成功；刪除不需要驗證 |
| `clear()` | 只清這個 plugin 寫的項目 |
| `capabilities()` | `{ auth, biometrics }`：此裝置能不能用 `requireAuth`、有沒有登錄生物辨識 |

鍵名 `^[A-Za-z0-9._-]{1,128}$`；值是字串，UTF-8 ≤ 64 KiB（二進位請自行 base64）。

失敗時拋出 `AqutterPluginError`，`code` 為：`invalid_key`、`too_large`、`auth_unavailable`、`auth_cancelled`、`auth_failed`、`key_invalidated`（系統金鑰失效，例如使用者新增指紋；該項目視為已不存在）、`storage_error`。值不會出現在錯誤訊息與日誌裡。

## 限制

- 條件在寫入時決定，之後不能只改條件不改值；要改就重新 `set`。
- iOS 的存取時機是「第一次解鎖後」；需驗證的項目另外綁在本機裝置（不跨裝置遷移）。
- 以 `keys()` 為準的索引由這個 plugin 維護；不要用其他程式直接改這個儲存。

## 開發

```bash
pnpm install
pnpm typecheck
flutter pub get
flutter test
```

契約與計畫見 `.kn-project/plans/`。
