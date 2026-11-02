import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// 回給網頁的錯誤；[code] 是契約 §3 的錯誤碼。
class SecureStorageException implements Exception {
  const SecureStorageException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

const String errInvalidKey = 'invalid_key';
const String errTooLarge = 'too_large';
const String errAuthUnavailable = 'auth_unavailable';
const String errAuthCancelled = 'auth_cancelled';
const String errAuthFailed = 'auth_failed';
const String errKeyInvalidated = 'key_invalidated';
const String errStorageError = 'storage_error';

/// 單一值的上限（UTF-8 位元組）。
const int maxValueBytes = 64 * 1024;

final RegExp _keyPattern = RegExp(r'^[A-Za-z0-9._-]{1,128}$');

String validateKey(Object? key) {
  if (key is! String || !_keyPattern.hasMatch(key)) {
    throw const SecureStorageException(errInvalidKey, 'key 必須符合 ^[A-Za-z0-9._-]{1,128}\$');
  }
  return key;
}

String validateValue(Object? value) {
  if (value is! String) {
    throw const SecureStorageException(errInvalidKey, 'value 必須是字串');
  }
  if (utf8.encode(value).length > maxValueBytes) {
    throw const SecureStorageException(errTooLarge, 'value 不得超過 $maxValueBytes 位元組');
  }
  return value;
}

String? validatePrompt(Object? prompt) {
  if (prompt == null) {
    return null;
  }
  if (prompt is! String || prompt.length > 100) {
    throw const SecureStorageException(errInvalidKey, 'prompt 必須是 100 字以內的字串');
  }
  return prompt;
}

/// 底層的安全儲存：只管單一鍵的讀寫刪，並知道該鍵是否需要驗證。測試以記憶體實作取代。
abstract interface class SecureBackend {
  Future<String?> read(String key, {required bool auth, String? prompt});

  Future<void> write(String key, String value, {required bool auth, String? prompt});

  Future<void> delete(String key, {required bool auth});
}

/// 此裝置能否使用驗證條件。
class AuthCapabilities {
  const AuthCapabilities({required this.auth, required this.biometrics});

  /// 裝置設有可用的驗證方式（生物辨識或裝置密碼）。
  final bool auth;

  /// 裝置已登錄生物辨識。
  final bool biometrics;
}

abstract interface class AuthProbe {
  Future<AuthCapabilities> check();
}

/// 以 `local_auth` 判斷裝置的驗證能力。
///
/// 只有 Android、iOS、macOS 的安全儲存真的會強制驗證；其他平台回兩者皆 false，
/// `requireAuth` 因此會被拒絕，而不是默默存成不需驗證的項目。
class LocalAuthProbe implements AuthProbe {
  LocalAuthProbe({TargetPlatform? platform}) : _platform = platform ?? defaultTargetPlatform;

  final TargetPlatform _platform;

  @override
  Future<AuthCapabilities> check() async {
    if (!const {TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS}.contains(_platform)) {
      return const AuthCapabilities(auth: false, biometrics: false);
    }
    try {
      final localAuth = LocalAuthentication();
      final supported = await localAuth.isDeviceSupported();
      final biometrics = (await localAuth.getAvailableBiometrics()).isNotEmpty;
      return AuthCapabilities(auth: supported, biometrics: biometrics);
    }
    catch (_) {
      return const AuthCapabilities(auth: false, biometrics: false);
    }
  }
}

/// 以 `flutter_secure_storage` 實作。
///
/// 需要驗證的項目與一般項目分開存放（Android 用不同的儲存命名空間，Apple 用不同的 account），
/// 因為「要不要驗證」是儲存層級的設定，不是單一鍵的設定。
class FlutterSecureBackend implements SecureBackend {
  FlutterSecureBackend({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _prefix = 'aqutter.ss.';

  AndroidOptions _android({required bool auth, String? prompt}) {
    if (!auth) {
      return const AndroidOptions(storageNamespace: 'aqutter_ss');
    }
    return AndroidOptions.biometric(
      enforceBiometrics: true,
      storageNamespace: 'aqutter_ss_auth',
      biometricPromptTitle: prompt ?? '請驗證身分',
    );
  }

  IOSOptions _ios({required bool auth}) => IOSOptions(
        accountName: auth ? 'aqutter_ss_auth' : 'aqutter_ss',
        accessibility: auth ? KeychainAccessibility.first_unlock_this_device : KeychainAccessibility.first_unlock,
        accessControlFlags: auth ? const [AccessControlFlag.userPresence] : const [],
      );

  MacOsOptions _macos({required bool auth}) => MacOsOptions(
        accountName: auth ? 'aqutter_ss_auth' : 'aqutter_ss',
        accessibility: auth ? KeychainAccessibility.first_unlock_this_device : KeychainAccessibility.first_unlock,
        accessControlFlags: auth ? const [AccessControlFlag.userPresence] : const [],
      );

  @override
  Future<String?> read(String key, {required bool auth, String? prompt}) async {
    try {
      return await _storage.read(
        key: '$_prefix$key',
        aOptions: _android(auth: auth, prompt: prompt),
        iOptions: _ios(auth: auth),
        mOptions: _macos(auth: auth),
      );
    }
    catch (error) {
      throw mapStorageError(error);
    }
  }

  @override
  Future<void> write(String key, String value, {required bool auth, String? prompt}) async {
    try {
      await _storage.write(
        key: '$_prefix$key',
        value: value,
        aOptions: _android(auth: auth, prompt: prompt),
        iOptions: _ios(auth: auth),
        mOptions: _macos(auth: auth),
      );
    }
    catch (error) {
      throw mapStorageError(error);
    }
  }

  @override
  Future<void> delete(String key, {required bool auth}) async {
    try {
      await _storage.delete(
        key: '$_prefix$key',
        aOptions: _android(auth: auth),
        iOptions: _ios(auth: auth),
        mOptions: _macos(auth: auth),
      );
    }
    catch (error) {
      throw mapStorageError(error);
    }
  }
}

/// 把底層的例外對應成契約的錯誤碼；值與鍵不會出現在訊息裡。
///
/// 底層套件把各平台的驗證結果放在例外的代碼或訊息裡，這裡依關鍵字判斷；認不得的一律是 `storage_error`。
SecureStorageException mapStorageError(Object error) {
  if (error is SecureStorageException) {
    return error;
  }
  final text = error is PlatformException ? '${error.code} ${error.message ?? ''}'.toLowerCase() : error.toString().toLowerCase();
  if (text.contains('invalidated') || text.contains('keypermanentlyinvalidated')) {
    return const SecureStorageException(errKeyInvalidated, '系統金鑰已失效，項目無法讀出');
  }
  if (text.contains('cancel') || text.contains('usercancel') || text.contains('negative button')) {
    return const SecureStorageException(errAuthCancelled, '使用者取消了驗證');
  }
  if (text.contains('lockout') || text.contains('too many') || text.contains('authfailed') || text.contains('authentication failed') || text.contains('not authenticated')) {
    return const SecureStorageException(errAuthFailed, '驗證失敗或暫時被系統鎖定');
  }
  if (text.contains('not enrolled') || text.contains('no biometrics') || text.contains('no credential') || text.contains('passcode not set') || text.contains('unavailable')) {
    return const SecureStorageException(errAuthUnavailable, '裝置沒有可用的驗證方式');
  }
  return const SecureStorageException(errStorageError, '安全儲存失敗');
}

/// 鍵的索引：記錄這個 plugin 寫過哪些鍵、各自要不要驗證。
///
/// 底層儲存沒有「只列鍵、不讀值」的功能（讀值會觸發驗證），所以自己維護一份不需驗證的索引。
class SecureStore {
  SecureStore({required SecureBackend backend, required AuthProbe probe})
      : _backend = backend,
        _probe = probe;

  final SecureBackend _backend;
  final AuthProbe _probe;

  static const String _indexKey = '__index';

  Future<Map<String, bool>> _loadIndex() async {
    final raw = await _backend.read(_indexKey, auth: false);
    if (raw == null) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value == true));
    }
    catch (_) {
      return {}; // 壞掉的索引視為空；項目本身仍在底層，重新 set 即可
    }
  }

  Future<void> _saveIndex(Map<String, bool> index) => _backend.write(_indexKey, jsonEncode(index), auth: false);

  Future<AuthCapabilities> capabilities() => _probe.check();

  Future<void> set(Object? key, Object? value, {bool requireAuth = false, Object? prompt}) async {
    final validKey = validateKey(key);
    final validValue = validateValue(value);
    final validPrompt = validatePrompt(prompt);
    if (requireAuth && !(await _probe.check()).auth) {
      throw const SecureStorageException(errAuthUnavailable, '這個裝置沒有設定任何驗證方式（螢幕鎖定或生物辨識）');
    }
    final index = await _loadIndex();
    final previousAuth = index[validKey];
    await _backend.write(validKey, validValue, auth: requireAuth, prompt: validPrompt);
    // 條件改變時，舊儲存裡的同名項目要清掉，否則 has/keys 與實際讀到的會不一致
    if (previousAuth != null && previousAuth != requireAuth) {
      await _backend.delete(validKey, auth: previousAuth);
    }
    index[validKey] = requireAuth;
    await _saveIndex(index);
  }

  /// 項目不存在回 null；需要驗證的項目會出現系統的驗證視窗。
  Future<String?> get(Object? key, {Object? prompt}) async {
    final validKey = validateKey(key);
    final validPrompt = validatePrompt(prompt);
    final index = await _loadIndex();
    final auth = index[validKey];
    if (auth == null) {
      return null;
    }
    try {
      final value = await _backend.read(validKey, auth: auth, prompt: validPrompt);
      if (value == null) {
        // 索引說有、底層卻沒有（例如底層已重設）：視為不存在並更正索引
        index.remove(validKey);
        await _saveIndex(index);
      }
      return value;
    }
    on SecureStorageException catch (error) {
      if (error.code == errKeyInvalidated) {
        index.remove(validKey);
        await _saveIndex(index);
      }
      rethrow;
    }
  }

  Future<bool> has(Object? key) async => (await _loadIndex()).containsKey(validateKey(key));

  Future<void> delete(Object? key) async {
    final validKey = validateKey(key);
    final index = await _loadIndex();
    final auth = index.remove(validKey);
    if (auth == null) {
      return;
    }
    await _backend.delete(validKey, auth: auth);
    await _saveIndex(index);
  }

  Future<List<String>> keys() async => (await _loadIndex()).keys.toList()..sort();

  Future<void> clear() async {
    final index = await _loadIndex();
    for (final entry in index.entries) {
      await _backend.delete(entry.key, auth: entry.value);
    }
    await _saveIndex({});
  }
}
