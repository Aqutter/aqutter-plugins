/** 載入 Google Maps JavaScript API 的逾時（毫秒）。 */
export const LOAD_TIMEOUT_MS = 15_000

const CALLBACK_NAME = '__aqutterGoogleMapsReady'

/** 以 key 為單位快取載入中／已載入的 Promise，避免重複插入腳本。 */
const loading = new Map<string, Promise<typeof google.maps>>()

interface GoogleWindow {
  google?: { maps?: typeof google.maps }
  [CALLBACK_NAME]?: () => void
}

export const scriptUrl = (apiKey: string): string =>
  `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(apiKey)}&callback=${CALLBACK_NAME}&v=weekly`

/**
 * 載入 Google Maps JavaScript API 並回傳 `google.maps`。
 *
 * 失敗（腳本載不到、逾時）一律 reject，不會無回應；失敗不快取，下次可以重試。
 */
export const loadGoogleMaps = (apiKey: string, timeoutMs: number = LOAD_TIMEOUT_MS): Promise<typeof google.maps> => {
  const win = window as unknown as GoogleWindow
  if (win.google?.maps) {
    return Promise.resolve(win.google.maps)
  }
  const cached = loading.get(apiKey)
  if (cached) {
    return cached
  }
  const promise = new Promise<typeof google.maps>((resolve, reject) => {
    const script = document.createElement('script')
    let timer: ReturnType<typeof setTimeout> | undefined
    const fail = (reason: string): void => {
      clearTimeout(timer)
      delete win[CALLBACK_NAME]
      script.remove()
      loading.delete(apiKey)
      reject(new Error(`[googleMaps] ${reason}`))
    }
    win[CALLBACK_NAME] = () => {
      clearTimeout(timer)
      delete win[CALLBACK_NAME]
      if (win.google?.maps) {
        resolve(win.google.maps)
      }
      else {
        fail('the Google Maps script loaded but google.maps is missing')
      }
    }
    script.src = scriptUrl(apiKey)
    script.async = true
    script.onerror = () => fail('failed to load the Google Maps JavaScript API (network, CSP or key problem)')
    timer = setTimeout(() => fail(`loading the Google Maps JavaScript API timed out after ${timeoutMs} ms`), timeoutMs)
    document.head.append(script)
  })
  loading.set(apiKey, promise)
  return promise
}

/** 測試用：清掉快取。 */
export const resetGoogleMapsLoader = (): void => {
  loading.clear()
}
