# aqutter-plugin-battery

Aqutter plugin：電池資訊。包裝 [`battery_plus`](https://pub.dev/packages/battery_plus)，示範 **「網頁 API ＋ 事件 ＋ 相依既有 Flutter plugin」**：battery_plus 的原生部分由 Flutter 工具鏈自動整合，plugin 本身不含原生程式碼。

## 安裝

```bash
aqutter plugin add github:Aqutter/aqutter-plugin-battery
cd aqutter && flutter pub get
```

需要與 App 相同的殼版本（`aqutter` 的 git ref 為 `0.0.0`）。

## 使用

```ts
import { battery } from 'aqutter-plugin-battery'

if (battery.isSupported()) {
  console.log(await battery.level())          // 0–100
  console.log(await battery.state())          // full | charging | discharging | connectedNotCharging | unknown
  const stop = battery.onStateChanged(state => console.log(state))
}
```

| 方法 / 事件 | 說明 |
|---|---|
| `level()` | 電量百分比 |
| `state()` | 充電狀態 |
| `isInSaveMode()` | 是否為省電模式 |
| `onStateChanged(listener)` | 充電狀態改變事件（頻道 `battery.stateChanged`） |

## 開發

```bash
pnpm install && pnpm typecheck
flutter pub get && flutter test
```
