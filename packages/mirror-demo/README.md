# aqutter-plugin-mirror-demo

Aqutter plugin 範例：**native view 鏡像**。一個純 Flutter 的互動畫面（圓、計數、色票）墊在 WebView 之下，以 `AqutterNative` 即時鏡像到網頁的 `<aqutter-native>` canvas；網頁在其上疊 HTML，並把手勢回傳給原生畫面。

## 安裝

```bash
aqutter plugin add github:Aqutter/aqutter-plugin-mirror-demo
cd aqutter && flutter pub get
```

需要與 App 相同的殼版本（`aqutter` 的 git ref 為 `0.0.0`）。

## 使用

```html
<aqutter-native session="mirror-demo" fit="cover" style="position:fixed;inset:0"></aqutter-native>
<div class="hud">疊在原生畫面之上的 HTML</div>
```

```ts
import '@aqutter/aqutter/native'
import { mirrorDemo } from 'aqutter-plugin-mirror-demo'

mirrorDemo.onCount(count => console.log(count))
const { x, y, radius } = await mirrorDemo.state()
```

| 手勢（網頁 → 原生） | 效果 |
|---|---|
| `pan` | 拖動圓 |
| `pinch` | 縮放圓 |
| `tap` | 計數 +1（並派送 `count` 事件） |
| `doubleTap` | 計數歸零（與單擊互斥：雙擊不會再多算一次單擊，單擊因此晚約 270 ms 才計數） |
| `longPress` | 換色 |
| `command` `reset` | 回到初始狀態 |

## 鏡像別的東西（以 Google Maps 為例）

把 `child` 換成 `GoogleMap`，停用它自己的手勢，在 `onMessage` 用 `GoogleMapController` 套用手勢：

```dart
AqutterNative(
  sessionId: 'map',
  nativeCapture: true,                  // iOS：PlatformView 需原生擷取
  nativeViewTypeContains: 'GMSMapView', // 直接擷取地圖 view（不含疊在其上的網頁）
  onMessage: (m) {
    if (m.type == 'pan' && m.data['phase'] == 'update') {
      controller.moveCamera(CameraUpdate.scrollBy(-m.number('dx')! * width, -m.number('dy')! * height));
    }
  },
  child: GoogleMap(
    initialCameraPosition: const CameraPosition(target: LatLng(25.034, 121.5645), zoom: 15),
    onMapCreated: (c) => controller = c,
    scrollGesturesEnabled: false,
    zoomGesturesEnabled: false,
  ),
)
```

本 plugin 不相依 `google_maps_flutter`（需要 API key）；上面只是寫法示範。協定與限制見 [網頁端文件](https://github.com/Aqutter/aqutter/blob/main/docs/nativeview.md)。

## 開發

```bash
pnpm install && pnpm typecheck
flutter pub get && flutter test
```

## 輸入的兩種接法

網頁的 `<aqutter-native>` 用 `input` 屬性決定回傳什麼：

| `input` | 網頁送什麼 | 誰判斷手勢 |
|---|---|---|
| `gestures`（預設） | 判斷好的 tap／doubleTap／longPress／pan／pinch | 網頁 |
| `pointers` | 原始指標事件（down／move／up／cancel，附時間戳） | Flutter（標準的 `GestureDetector`：單擊、雙擊、長按、右鍵、單指拖曳、雙指縮放與旋轉、慣性滑動） |
| `both` | 兩者都送 | 兩邊都判斷，通常用不到 |

本範例兩種都支援。用 `pointers` 時是 Flutter 標準行為：同時註冊 `onTap` 與 `onDoubleTap`，單擊要等約 300 ms 確認不是雙擊才觸發，雙擊不會再觸發單擊（互斥）。畫布見 `MirrorDemoCanvas`。
