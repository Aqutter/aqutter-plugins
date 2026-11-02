# aqutter-plugin-haptics

Aqutter plugin：網頁呼叫裝置觸覺回饋。**純 Dart**——只用 Flutter 內建的 `HapticFeedback`，沒有原生程式碼，是最小的 plugin 範例。

## 安裝

```bash
aqutter plugin add github:Aqutter/aqutter-plugin-haptics
cd aqutter && flutter pub get
```

需要與 App 相同的殼版本（`aqutter` 的 git ref 為 `0.0.0`）。

## 使用

```ts
import { haptics } from 'aqutter-plugin-haptics'

await haptics.impact('light')   // light | medium | heavy
await haptics.selection()
await haptics.vibrate()
```

不在殼內、或 App 沒裝此 plugin 時，呼叫是安靜的 no-op；可用 `haptics.isSupported()` 判斷。

| 方法 | Dart 對應 |
|---|---|
| `impact(style)` | `HapticFeedback.lightImpact / mediumImpact / heavyImpact` |
| `selection()` | `HapticFeedback.selectionClick` |
| `vibrate()` | `HapticFeedback.vibrate` |

## 開發

```bash
pnpm install && pnpm typecheck
flutter pub get && flutter test
```
