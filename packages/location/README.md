# aqutter-plugin-location

Aqutter plugin：`location`。取得裝置位置：**取得目前位置一次**，或**持續監聽**位置變化。預設高精度。同一個 repo 同時是 npm 套件（網頁端 API）與 Dart 套件（Flutter 端）。

> **進度**：Dart 端與網頁端已完成，23 個 Dart 單元測試與 3 個網頁端測試通過。**已在 Android 實機與 Windows 驗證**：取得目前位置一次、持續監聽（位置事件陸續到達、停止後狀態指示消失）、權限與定位服務狀態查詢，並用 OpenStreetMap 示範頁顯示位置。**尚未驗證**：iOS 與 macOS（無法編譯 Swift）、權限被拒或定位服務關閉時的實機行為、Android 背景進出的行為。

## 範圍

| 做 | 不做 |
|---|---|
| 取得目前位置一次（有逾時，預設 15 秒） | 背景定位（需要額外的危險權限、Android 前景服務與商店審核） |
| 持續監聽（前景），最多同時 8 個 | 地理圍欄、地址反查 |
| 精度三檔：`high`（預設）、`balanced`、`low` | 保存、上傳或記錄位置 |
| 查詢權限與定位服務狀態、開系統設定頁 | 自動跳授權視窗（由網頁先要權限） |

平台：Android、iOS、macOS、Windows。**不支援 Linux**。**位置是敏感資料**：使用這個 plugin 的 App 要自行處理 Google Play 的資料安全表與 App Store 的隱私標籤。

## 安裝

```bash
aqutter plugin add "github:Aqutter/aqutter-plugins#path:/packages/location"
```

`aqutter doctor` 會檢查還缺的原生設定：Android 的 `ACCESS_FINE_LOCATION`、`ACCESS_COARSE_LOCATION`，iOS 與 macOS 的 `NSLocationWhenInUseUsageDescription`。另外：

- macOS 沙盒 App 還需要 entitlement `com.apple.security.personal-information.location`。
- Windows 要在「設定 → 隱私權 → 位置」開啟定位服務。

## 網頁端

```ts
import { location } from 'aqutter-plugin-location'

// 1. 先要權限（必要時跳系統授權視窗）
if ((await location.capabilities()).permission !== 'granted') {
  const permission = await location.requestPermission()
  if (permission === 'permanentlyDenied') {
    await location.openSettings('app') // 引導使用者到系統設定
  }
}

// 2. 取得一次
const here = await location.getCurrentPosition({ accuracy: 'high', timeoutMs: 15000 })

// 3. 持續監聽
const stop = await location.watch(
  position => console.log(position.latitude, position.longitude, position.accuracy),
  { accuracy: 'balanced', distanceFilterMeters: 10, onError: code => console.warn(code) },
)
// 不再需要時
await stop?.()
```

| 方法 | 說明 |
|---|---|
| `capabilities()` | `{ serviceEnabled, permission }`：定位服務是否開著、目前的權限狀態 |
| `requestPermission()` | 必要時跳系統授權視窗，回傳授權後的狀態 |
| `getCurrentPosition({ accuracy?, timeoutMs? })` | 取得一次，不快取；`timeoutMs` 1,000 到 60,000，預設 15,000 |
| `watch(listener, { accuracy?, distanceFilterMeters?, intervalMs?, onError? })` | 持續監聽，回傳停止函式；同時最多 8 個 |
| `openSettings('app' \| 'location')` | 開本 App 的系統設定或系統的定位服務設定 |

`Position`：`{ latitude, longitude, accuracy, timestamp, altitude?, altitudeAccuracy?, heading?, speed?, isMocked? }`；經緯度為度、`accuracy` 為公尺、`timestamp` 為 Unix 毫秒；平台沒有的欄位省略。

錯誤碼（`AqutterPluginError.code`；監聽中的錯誤用 `onError`）：`invalid_argument`、`permission_denied`、`location_services_disabled`、`timeout`、`position_unavailable`、`too_many_watches`。

- 沒有權限時 `getCurrentPosition` 與 `watch` 回 `permission_denied`，**不會**自動跳授權視窗。
- 暫時性的錯誤（例如室內沒訊號）不會結束監聽；權限被收回或定位服務被關閉時，會先送出錯誤再結束該監聽。
- 前景定位：App 進背景時系統可能暫停，回到前景後繼續，不保證補送錯過的位置。

**plugin 在這個平台用不了時不拋錯**：`capabilities` 回「服務關閉、權限 denied」，`getCurrentPosition` 與 `watch` 回 `null`。

## 開發

```bash
pnpm install
pnpm typecheck
pnpm test
flutter pub get
flutter test
```

契約與計畫見根目錄 `.kn-project/plans/`。
