/** 地圖相機位置。 */
export interface GoogleMapsCamera {
  lat: number
  lng: number
  zoom: number
}

/** 標記。`id` 省略時由實作產生。 */
export interface GoogleMapsMarker {
  id?: string
  lat: number
  lng: number
  title?: string
}

export type GoogleMapsType = 'normal' | 'satellite' | 'terrain' | 'hybrid'

/** 地圖由誰繪製：`'native'`＝原生地圖鏡像到 `<aqutter-native>`（iOS、Android）；`'js'`＝Google Maps JavaScript API。 */
export type GoogleMapsProvider = 'native' | 'js'

export interface GoogleMapsMountOptions {
  /** 初始相機；省略時由地圖自己決定。 */
  camera?: { lat: number, lng: number, zoom?: number }
  mapType?: GoogleMapsType
  /**
   * 原生地圖的顯示模式，設到 `<aqutter-native>` 的 `mode` 屬性（只有 `'native'` provider 用）：
   * `'auto'`（預設）平台支援且頁面可穿透時用穿透，否則鏡像；`'mirror'` 一律鏡像；`'passthrough'` 要求穿透
   * （不偵測頁面條件：元素後方的祖先不可有不透明背景）。省略時不設屬性，由元素的預設（`auto`）決定。
   */
  mode?: 'auto' | 'mirror' | 'passthrough'
}

export interface GoogleMapsMoveOptions {
  zoom?: number
  /** 預設立即移動；`true` 才做動畫（原生端的動畫要靠地圖持續繪圖）。 */
  animate?: boolean
}

export type GoogleMapsUnsubscribe = () => void

/** 兩種 provider 共同的地圖控制介面：方法與事件行為一致。 */
export interface GoogleMapsView {
  readonly provider: GoogleMapsProvider
  getCamera: () => Promise<GoogleMapsCamera>
  moveTo: (lat: number, lng: number, options?: GoogleMapsMoveOptions) => Promise<void>
  /** 以這份清單取代全部標記。 */
  setMarkers: (markers: GoogleMapsMarker[]) => Promise<void>
  setMapType: (type: GoogleMapsType) => Promise<void>
  /** 地圖建立完成。 */
  onReady: (listener: (camera: GoogleMapsCamera) => void) => GoogleMapsUnsubscribe
  /** 相機停止移動（拖曳、縮放或動畫結束）。 */
  onCameraIdle: (listener: (camera: GoogleMapsCamera) => void) => GoogleMapsUnsubscribe
  /** 點擊地圖，回報點到的經緯度。 */
  onTap: (listener: (position: { lat: number, lng: number }) => void) => GoogleMapsUnsubscribe
  /** 移除地圖與所有監聽；之後不可再使用。 */
  destroy: () => void
}
