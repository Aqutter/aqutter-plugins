# aqutter-plugin-google-maps

Aqutter plugin：把 `google_maps_flutter` 的地圖在 Flutter 裡渲染（墊在 WebView 之下），以 native view 鏡像（或在 Android 上穿透）顯示到網頁的 `<aqutter-native>`。網頁因此能在地圖**之上**疊任何 HTML、做 z-index 與動畫；拖曳、縮放、點擊從網頁回傳，換成地圖的相機操作。

**多平台**：Android、iOS 用上述的原生地圖；其他平台（macOS、Windows、Linux，以及純瀏覽器）用 **Google Maps JavaScript API**。網頁只寫一份 `googleMaps.mount(container)`，兩者的方法與事件一致，也都能在地圖上疊 HTML。

| 平台 | 地圖由誰繪製 | 需要的 key |
|---|---|---|
| Android、iOS | 原生地圖（`google_maps_flutter`），鏡像到 `<aqutter-native>` | 原生 SDK key（見下方） |
| 其他 | Google Maps JavaScript API，直接在網頁裡繪製 | JS API key（見下方，與原生 key 是**不同**的 key） |

## 安裝

在 Aqutter 專案：

```bash
pnpm exec aqutter plugin add github:Aqutter/aqutter-plugins#path:/packages/google-maps
```

## 網頁端

```html
<div id="map" style="position: relative; height: 360px">
  <div class="overlay">任何 HTML 都可以疊在地圖上</div>
</div>
```

```ts
import { googleMaps } from 'aqutter-plugin-google-maps'

// 非原生平台用的 JS API key：由 App 傳入（例如來自自己的環境變數），不要寫進會提交的檔案
googleMaps.configure({ jsApiKey: useRuntimeConfig().public.googleMapsJsApiKey })

const map = await googleMaps.mount(document.getElementById('map')!, {
  camera: { lat: 35.6762, lng: 139.6503, zoom: 11 },
})
await map.setMarkers([{ id: 'tokyo', lat: 35.6762, lng: 139.6503, title: 'Tokyo' }])
map.onTap(({ lat, lng }) => console.log('tapped', lat, lng))
map.onCameraIdle(camera => console.log(camera))
// 不再使用時
map.destroy()
```

| 成員 | 說明 |
|---|---|
| `googleMaps.configure({ jsApiKey })` | 設定非原生平台用的 JS API key；須在 `mount` 前呼叫，原生平台忽略 |
| `googleMaps.provider()` | 同步：`'native'` 或 `'js'`。依殼回報的能力表判斷 |
| `googleMaps.mount(container, { camera?, mapType? })` | 在 `container` 內建立地圖，回傳 `GoogleMapsView`。`'js'` 沒有 `configure` 過 key、或腳本載入失敗／逾時（15 秒）都會 reject |
| `GoogleMapsView.provider` | 這張地圖用的 provider |
| `getCamera()` | 目前相機：`{ lat, lng, zoom }` |
| `moveTo(lat, lng, { zoom?, animate? })` | 移動相機；預設立即移動，`animate: true` 才做動畫（原生端的動畫要靠地圖持續繪圖） |
| `setMarkers(markers)` | 以這份清單取代全部標記 |
| `setMapType(type)` | `normal`／`satellite`／`terrain`／`hybrid` |
| `onReady` / `onCameraIdle` / `onTap` | 事件，回傳取消訂閱函式 |
| `destroy()` | 移除地圖與所有監聽 |

操作（原生）：單指拖曳平移、雙指縮放、雙擊放大、單擊回報經緯度。JS 地圖用 Google 預設的手勢。

> **在 App 的平台資訊就緒之後再 `mount`。** `provider()` 依殼回報的能力表判斷；能力表還沒取得時（啟動早期）一律視為支援，會回 `'native'`，在桌面平台會選錯。

> **頂層的 `isSupported()`、`moveTo()` 等已移除**（開發階段的破壞式變更），改由 `mount` 回傳的 `GoogleMapsView` 提供。

## 非原生平台：Google Maps JavaScript API

macOS、Windows、Linux 與純瀏覽器用 Google Maps JavaScript API 繪製地圖。

1. 在 [Google Cloud Console](https://console.cloud.google.com/google/maps-apis) 啟用 **Maps JavaScript API**（需要計費）並建立一組 **JS API key**。這和原生 SDK 的 key 是**分開**的 key。
2. 由使用端 App 在 `mount` 之前呼叫 `googleMaps.configure({ jsApiKey })`。plugin 不讀任何檔案，key 不要寫進會提交的檔案。
3. 網頁的 Content-Security-Policy 要放行 Google 的腳本、圖磚、樣式與字型來源。**確切網域尚未實測**（沒有 key 無法載入真的地圖），請以瀏覽器 console 的 CSP 違規訊息為準逐一放行。
4. **key 的網址限制尚未驗證**：release 版網頁由殼的本機 server 供應，來源是 `http://127.0.0.1:<隨機埠>`，隨機埠讓 HTTP referrer 限制不好寫；怎麼填請以實測為準，驗證後會補在這裡。

> 這一段在撰寫時只用假的 `google.maps` 物件做過單元測試，**還沒有用真的 key 載入過 Google 的腳本**。

## 設定 Google Maps API key（原生，Android、iOS）

沒有 key 時，Android 會顯示灰色空白地圖，iOS 會在建立地圖時出錯。key 由使用端 App 設定，**不要**把 key 寫進會提交的檔案。

1. 在 [Google Cloud Console](https://console.cloud.google.com/google/maps-apis) 建立專案並啟用計費，啟用 **Maps SDK for Android** 與 **Maps SDK for iOS**，各建立一組 API key（建議分開，方便分別限制）。
2. 限制 key：Android key 限制「Android 應用程式」並填套件名稱與簽章指紋（SHA-1）；iOS key 限制「iOS 應用程式」並填 bundle ID。

### Android

`android/local.properties`（已被 git 忽略，不會提交）加一行：

```properties
GOOGLE_MAPS_API_KEY=你的 Android key
```

`android/app/build.gradle.kts` 最上面加 `import java.util.Properties`，並在 `defaultConfig` 區塊加上：

```kotlin
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
manifestPlaceholders["googleMapsApiKey"] = localProperties.getProperty("GOOGLE_MAPS_API_KEY", "NO_KEY")
```

`android/app/src/main/AndroidManifest.xml` 的 `<application>` 裡加上：

```xml
<meta-data android:name="com.google.android.geo.API_KEY" android:value="${googleMapsApiKey}" />
```

### iOS

建立 `ios/Flutter/Secrets.xcconfig`（加進 `.gitignore`）：

```
GOOGLE_MAPS_API_KEY = 你的 iOS key
```

在 `ios/Flutter/Debug.xcconfig` 與 `ios/Flutter/Release.xcconfig` 各加一行：

```
#include? "Secrets.xcconfig"
```

`ios/Runner/Info.plist` 加上：

```xml
<key>GMSApiKey</key>
<string>$(GOOGLE_MAPS_API_KEY)</string>
```

`ios/Runner/AppDelegate.swift`：

```swift
import GoogleMaps
// …
override func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
  // 沒有設定 key 時用佔位值：地圖顯示灰色（授權失敗）但不會崩潰。
  // iOS 若完全沒呼叫 provideAPIKey，建立地圖時 App 會直接終止。
  let key = (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String) ?? ""
  GMSServices.provideAPIKey(key.isEmpty ? "NO_KEY" : key)
  return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

`ios/Flutter/Secrets.xcconfig` 記得加進 `.gitignore`：

```
ios/Flutter/Secrets.xcconfig
```

### iOS：選擇地圖實作（Swift Package Manager）

Aqutter 框架的最低 iOS 是 **16.0**。`google_maps_flutter` 預設的 iOS 實作 `google_maps_flutter_ios` 不支援 Swift Package Manager，Flutter 3.50 建置 iOS 時會警告「plugin 不支援 Swift Package Manager」。官方建議改用 SDK 專用的實作，由**應用程式**在自己的 `pubspec.yaml` 選擇（本 plugin 不依賴它，讓你能依最低 iOS 版本自己決定）：

```yaml
dependencies:
  google_maps_flutter_ios_sdk10: ^2.19.0
```

| 實作套件 | Google Maps SDK | 最低 iOS |
|---|---|---|
| `google_maps_flutter_ios_sdk10`（建議，框架最低 iOS 16 即適用） | 10.x | 16.0 |
| `google_maps_flutter_ios_sdk9` | 9.2–9.x | 15.0 |

加入後它會自動取代預設實作，其餘照常使用 `google_maps_flutter`；`AppDelegate.swift` 的 `import GoogleMaps` 與 `GMSServices.provideAPIKey(...)` 不需修改。

從預設實作換過來時，若本機留有舊的 CocoaPods 建置產物，建置會出現 `duplicate symbols`（例如 `GoogleMapsUtils` 重複）。先清掉再建置：

```bash
flutter clean
rm -rf ios/Pods ios/Podfile.lock
```

## 顯示模式：鏡像或穿透（`mode`）

原生地圖（Android、iOS）有兩種顯示方式，共用同一個 `<aqutter-native>` 標籤、手勢與事件（`ready`、`cameraIdle`、`tap`），用 `mode` 切換：

| `mode` | 說明 |
|---|---|
| `'auto'`（預設） | 平台支援（目前只有 Android）、App 端允許、且頁面可穿透時用**穿透**，否則**鏡像** |
| `'mirror'` | 一律鏡像：擷取地圖畫面、傳到網頁的 canvas（上面「運作方式與限制」描述的做法） |
| `'passthrough'` | 要求穿透：地圖直接畫在（透明的）WebView 下面，不擷取、不送幀；平台不支援時退回鏡像 |

```ts
await googleMaps.mount(container, { mode: 'auto' }) // 省略時就是 auto（由元素的預設決定）
```

App 端也可以限制：`GoogleMapsPlugin(mode: AqutterNativeMode.mirror)` 表示這個地圖絕不穿透。

- **穿透的地圖大小與位置跟著網頁元素**（也就是你放 `container` 的地方），隨頁面捲動。`backdrop-filter` 模糊對地圖沒有效果。
- **圓角**：替 `container` 加圓角即可（`mount` 建立的元素會繼承它），穿透與鏡像都是圓角。穿透時地圖在 WebView 下面，圓角是框架在背景上挖出的洞。
- **頁面背景自動讓開**：穿透時框架把元素往上到 `<html>` 的不透明背景暫時改成透明，離開穿透就還原；鋪滿畫面的底層背景層（例如 `fixed inset-0` 的底色或漸層）在元素上標 `data-aqutter-bg`，框架會在地圖位置自動挖洞、跟著捲動。`<aqutter-native>` 加 `keep-background` 屬性可關閉，由頁面自己處理。
- 沒標記的兄弟元素、偽元素、`box-shadow` 遮罩不會被自動處理，這類頁面請標記底層背景層，或明確寫 `mode: 'mirror'`。
- 地圖只占畫面一部分（`GoogleMapsPlugin(widthFactor:, heightFactor:)` 不是 1）時一律鏡像。
- 穿透時手指從地圖上開始滑動是操作地圖、不會捲動頁面（元素的 `touch-action: none`）。
- 穿透需要殼與 `aqutter_core` 支援（殼會在穿透時自動讓 WebView 透明）；舊版沒有這個支援時，標籤等不到回覆就退回鏡像。
- 目前只在 Android 實機驗證；iOS 的 `auto` 一律鏡像。
- 協定與決策規則見 [aqutter_core 的 doc/nativeview.md](https://github.com/Aqutter/aqutter_core/blob/main/doc/nativeview.md) 的「穿透模式」。

## 運作方式與限制

- 擷取：Flutter 的 `RepaintBoundary.toImage` 抓不到地圖（鏡像會是透明的）。Android 直接擷取地圖內的 `TextureView`；iOS 用原生 `drawHierarchy` 擷取地圖 view。Android 地圖用 texture 模式（`useAndroidViewSurface = false`），本 plugin 會自動設定。
- 效能（Android 平板實測，滿版約 3200 像素寬）：約 15 fps，每幀約 10 MB。
- 輸入走網頁判斷的語意手勢（`input="gestures"`，預設），換成相機更新。iOS 的 PlatformView 不接受注入的 Flutter 指標事件，所以不用 `input="pointers"`。
- 擷取成本取決於地圖像素數；移動中的解析度預設是 `smooth`（固定在框架預設 `AqutterNative.defaultMinScale`（0.4），`GoogleMapsPlugin(quality:, minScale:)` 可調），停下來補完整解析度的定格幀。效能細節見 [aqutter_core 的 doc/nativeview.md](https://github.com/Aqutter/aqutter_core/blob/main/doc/nativeview.md)。
