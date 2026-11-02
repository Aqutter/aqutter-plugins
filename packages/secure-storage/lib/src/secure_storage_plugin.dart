import 'package:aqutter/aqutter.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

import 'secure_store.dart';

/// `secure-storage` plugin 的 Dart 端：把機密存進系統的安全儲存，可要求使用者驗證才能讀出。
///
/// 值只會在成功的 `get` 回給網頁；錯誤訊息與日誌不含鍵與值。
class SecureStoragePlugin extends AqutterPlugin {
  SecureStoragePlugin({SecureBackend? backend, AuthProbe? probe})
      : _store = SecureStore(backend: backend ?? FlutterSecureBackend(), probe: probe ?? LocalAuthProbe());

  final SecureStore _store;

  @override
  String get id => 'secure-storage';

  /// Linux 需要 libsecret、Windows 的底層實作需要 ATL，第一版都不支援（契約 §1 rev 2）；
  /// 這兩個平台上網頁端的呼叫回 `undefined`。
  @override
  Set<TargetPlatform>? get supportedPlatforms => const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      };

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        'set': _guard((payload) async {
          await _store.set(payload['key'], payload['value'], requireAuth: payload['requireAuth'] == true, prompt: payload['prompt']);
          return <String, dynamic>{};
        }),
        'get': _guard((payload) async => {'value': await _store.get(payload['key'], prompt: payload['prompt'])}),
        'has': _guard((payload) async => {'exists': await _store.has(payload['key'])}),
        'delete': _guard((payload) async {
          await _store.delete(payload['key']);
          return <String, dynamic>{};
        }),
        'keys': _guard((payload) async => {'keys': await _store.keys()}),
        'clear': _guard((payload) async {
          await _store.clear();
          return <String, dynamic>{};
        }),
        'capabilities': _guard((payload) async {
          final capabilities = await _store.capabilities();
          return {'auth': capabilities.auth, 'biometrics': capabilities.biometrics};
        }),
      };

  /// 把契約的錯誤轉成殼的錯誤資料；底層的例外先經 [mapStorageError] 對應，訊息不含鍵與值。
  AqutterPluginHandler _guard(AqutterPluginHandler handler) {
    return (payload) async {
      try {
        return await handler(payload);
      }
      catch (error) {
        final mapped = mapStorageError(error);
        return aqutterErrorPayload(mapped.code, mapped.message);
      }
    };
  }
}
