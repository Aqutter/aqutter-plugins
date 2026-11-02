/// 沒有實作的替身：Windows 不註冊任何安全儲存。
///
/// aqutter-plugin-secure-storage 在 Windows 不列入支援平台，網頁端的呼叫回 `undefined`；
/// 這個替身只是讓 `flutter_secure_storage` 在 Windows 建置時不必編譯需要 ATL 的原生程式。
class FlutterSecureStorageWindows {
  static void registerWith() {}
}
