import 'package:aqutter/aqutter.dart';
import 'package:aqutter_plugin_secure_storage/aqutter_plugin_secure_storage.dart';
import 'package:aqutter_plugin_secure_storage/src/secure_store.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

/// 記憶體內的安全儲存：需要驗證的項目與一般項目分開存放，與真實實作一致。
class _FakeBackend implements SecureBackend {
  final Map<String, String> plain = {};
  final Map<String, String> protected = {};
  final List<String> authPrompts = [];

  /// 設成非 null：下一次讀寫需要驗證的項目時丟出這個錯誤。
  SecureStorageException? authFailure;

  /// 設成 true：讀取時回 null，模擬底層因金鑰失效而重設。
  bool dropProtected = false;

  Map<String, String> _bucket(bool auth) => auth ? protected : plain;

  void _authenticate(String? prompt) {
    authPrompts.add(prompt ?? '(default)');
    final failure = authFailure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<String?> read(String key, {required bool auth, String? prompt}) async {
    if (auth) {
      _authenticate(prompt);
      if (dropProtected) {
        return null;
      }
    }
    return _bucket(auth)[key];
  }

  @override
  Future<void> write(String key, String value, {required bool auth, String? prompt}) async {
    if (auth) {
      _authenticate(prompt);
    }
    _bucket(auth)[key] = value;
  }

  @override
  Future<void> delete(String key, {required bool auth}) async {
    _bucket(auth).remove(key);
  }
}

class _FakeProbe implements AuthProbe {
  _FakeProbe();

  bool auth = true;
  bool biometrics = true;

  @override
  Future<AuthCapabilities> check() async => AuthCapabilities(auth: auth, biometrics: biometrics);
}

void main() {
  late _FakeBackend backend;
  late _FakeProbe probe;
  late SecureStoragePlugin plugin;

  Future<dynamic> call(String method, [Map<String, dynamic> payload = const {}]) => plugin.handlers[method]!(payload);

  void expectError(dynamic result, String code) {
    final error = aqutterErrorOf(result);
    expect(error, isNotNull, reason: 'expected $code, got $result');
    expect(error!.code, code);
  }

  setUp(() {
    backend = _FakeBackend();
    probe = _FakeProbe();
    plugin = SecureStoragePlugin(backend: backend, probe: probe);
  });

  test('id, handlers and supported platforms (no Linux)', () {
    expect(plugin.id, 'secure-storage');
    expect(plugin.handlers.keys, unorderedEquals(['set', 'get', 'has', 'delete', 'keys', 'clear', 'capabilities']));
    expect(plugin.supportedPlatforms, {TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.windows});
  });

  group('plain items', () {
    test('set, get, has, keys and delete round-trip', () async {
      await call('set', {'key': 'token', 'value': 'abc'});

      expect(await call('get', {'key': 'token'}), {'value': 'abc'});
      expect(await call('has', {'key': 'token'}), {'exists': true});
      expect(await call('keys'), {'keys': ['token']});

      await call('delete', {'key': 'token'});
      expect(await call('get', {'key': 'token'}), {'value': null});
      expect(await call('has', {'key': 'token'}), {'exists': false});
      expect(await call('keys'), {'keys': <String>[]});
    });

    test('a missing item is null, not an error; deleting a missing item succeeds', () async {
      expect(await call('get', {'key': 'nothing'}), {'value': null});
      expect(await call('delete', {'key': 'nothing'}), <String, dynamic>{});
    });

    test('setting the same key again replaces the value', () async {
      await call('set', {'key': 'k', 'value': 'one'});
      await call('set', {'key': 'k', 'value': 'two'});

      expect(await call('get', {'key': 'k'}), {'value': 'two'});
      expect((await call('keys') as Map)['keys'], ['k']);
    });

    test('keys are sorted and clear removes everything the plugin wrote', () async {
      await call('set', {'key': 'b', 'value': '1'});
      await call('set', {'key': 'a', 'value': '2'});
      await call('set', {'key': 'c', 'value': '3', 'requireAuth': true});
      expect((await call('keys') as Map)['keys'], ['a', 'b', 'c']);

      await call('clear');

      expect((await call('keys') as Map)['keys'], isEmpty);
      expect(await call('get', {'key': 'a'}), {'value': null});
      expect(backend.protected.keys.where((key) => key != '__index'), isEmpty);
      expect(backend.plain.keys.where((key) => key != '__index'), isEmpty);
    });

    test('keys never reads a value, so it never shows an auth prompt', () async {
      await call('set', {'key': 'secret', 'value': 'x', 'requireAuth': true});
      backend.authPrompts.clear();

      await call('keys');
      await call('has', {'key': 'secret'});
      await call('delete', {'key': 'secret'});

      expect(backend.authPrompts, isEmpty);
    });
  });

  group('validation', () {
    test('rejects bad keys', () async {
      for (final bad in ['', ' ', 'a b', 'a/b', 'a\u0000b', 'é', 'x' * 129]) {
        expectError(await call('set', {'key': bad, 'value': 'v'}), errInvalidKey);
      }
      expectError(await call('get', {'key': 5}), errInvalidKey);
      expectError(await call('get', {}), errInvalidKey);
      expectError(await call('has', {'key': '../x'}), errInvalidKey);
    });

    test('accepts the full allowed key alphabet', () async {
      await call('set', {'key': 'A-z_0.9', 'value': 'v'});
      await call('set', {'key': 'x' * 128, 'value': 'v'});

      expect((await call('keys') as Map)['keys'], hasLength(2));
    });

    test('values must be strings of at most 64 KiB (UTF-8 bytes)', () async {
      expectError(await call('set', {'key': 'k', 'value': 5}), errInvalidKey);
      expectError(await call('set', {'key': 'k'}), errInvalidKey);
      expectError(await call('set', {'key': 'k', 'value': 'x' * (maxValueBytes + 1)}), errTooLarge);
      expectError(await call('set', {'key': 'k', 'value': '中' * 21846}), errTooLarge, );
      await call('set', {'key': 'k', 'value': 'x' * maxValueBytes});
      expect(((await call('get', {'key': 'k'}) as Map)['value'] as String).length, maxValueBytes);
    });

    test('prompt must be a string of at most 100 characters', () async {
      expectError(await call('set', {'key': 'k', 'value': 'v', 'requireAuth': true, 'prompt': 'x' * 101}), errInvalidKey);
      expectError(await call('get', {'key': 'k', 'prompt': 7}), errInvalidKey);
    });
  });

  group('requireAuth', () {
    test('protected items live in the protected store, plain ones in the plain store', () async {
      await call('set', {'key': 'open', 'value': '1'});
      await call('set', {'key': 'locked', 'value': '2', 'requireAuth': true});

      expect(backend.plain.containsKey('open'), isTrue);
      expect(backend.protected.containsKey('locked'), isTrue);
      expect(backend.plain.containsKey('locked'), isFalse);
    });

    test('reading a protected item shows the prompt and passes the custom prompt text through', () async {
      await call('set', {'key': 'locked', 'value': 'v', 'requireAuth': true, 'prompt': '解鎖帳號'});
      backend.authPrompts.clear();

      expect(await call('get', {'key': 'locked', 'prompt': '確認身分'}), {'value': 'v'});
      expect(backend.authPrompts, ['確認身分']);
    });

    test('reading a plain item never prompts', () async {
      await call('set', {'key': 'open', 'value': 'v'});
      backend.authPrompts.clear();

      await call('get', {'key': 'open'});

      expect(backend.authPrompts, isEmpty);
    });

    test('a device without any screen lock refuses requireAuth instead of storing it unprotected', () async {
      probe.auth = false;

      expectError(await call('set', {'key': 'locked', 'value': 'v', 'requireAuth': true}), errAuthUnavailable);

      expect(backend.protected, isEmpty);
      expect(backend.plain, isEmpty);
      expect(await call('has', {'key': 'locked'}), {'exists': false});
      await call('set', {'key': 'open', 'value': 'v'});
    });

    test('a cancelled prompt on get keeps the item and reveals nothing', () async {
      await call('set', {'key': 'locked', 'value': 'v', 'requireAuth': true});
      backend.authFailure = const SecureStorageException(errAuthCancelled, 'cancelled');

      expectError(await call('get', {'key': 'locked'}), errAuthCancelled);

      backend.authFailure = null;
      expect(await call('get', {'key': 'locked'}), {'value': 'v'});
    });

    test('a cancelled prompt on set stores nothing and leaves the previous value alone', () async {
      await call('set', {'key': 'k', 'value': 'old'});
      backend.authFailure = const SecureStorageException(errAuthCancelled, 'cancelled');

      expectError(await call('set', {'key': 'k', 'value': 'new', 'requireAuth': true}), errAuthCancelled);

      backend.authFailure = null;
      expect(await call('get', {'key': 'k'}), {'value': 'old'});
      expect(backend.protected, isEmpty);
    });

    test('an invalidated key drops the item: the error is reported once, then it is simply gone', () async {
      await call('set', {'key': 'locked', 'value': 'v', 'requireAuth': true});
      backend.authFailure = const SecureStorageException(errKeyInvalidated, 'invalidated');

      expectError(await call('get', {'key': 'locked'}), errKeyInvalidated);

      backend.authFailure = null;
      expect(await call('get', {'key': 'locked'}), {'value': null});
      expect((await call('keys') as Map)['keys'], isEmpty);
    });

    test('an item the storage lost behind our back is treated as missing and the index is corrected', () async {
      await call('set', {'key': 'locked', 'value': 'v', 'requireAuth': true});
      backend.dropProtected = true;

      expect(await call('get', {'key': 'locked'}), {'value': null});
      expect((await call('keys') as Map)['keys'], isEmpty);
    });

    test('changing the condition of a key moves it and removes the old copy', () async {
      await call('set', {'key': 'k', 'value': 'plain'});
      await call('set', {'key': 'k', 'value': 'locked', 'requireAuth': true});

      expect(backend.plain.containsKey('k'), isFalse);
      expect(backend.protected['k'], 'locked');

      await call('set', {'key': 'k', 'value': 'plain again'});

      expect(backend.protected.containsKey('k'), isFalse);
      expect(await call('get', {'key': 'k'}), {'value': 'plain again'});
      expect((await call('keys') as Map)['keys'], ['k']);
    });
  });

  group('capabilities', () {
    test('reports what the device can do', () async {
      expect(await call('capabilities'), {'auth': true, 'biometrics': true});

      probe
        ..auth = true
        ..biometrics = false;
      expect(await call('capabilities'), {'auth': true, 'biometrics': false});

      probe.auth = false;
      expect(await call('capabilities'), {'auth': false, 'biometrics': false});
    });

    test('Windows and Linux never claim auth support', () async {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        final capabilities = await LocalAuthProbe(platform: platform).check();

        expect(capabilities.auth, isFalse);
        expect(capabilities.biometrics, isFalse);
      }
    });
  });

  group('error mapping', () {
    SecureStorageException map(String code, [String message = '']) => mapStorageError(PlatformException(code: code, message: message));

    test('known authentication outcomes map to their contract codes', () {
      expect(map('UserCancel').code, errAuthCancelled);
      expect(map('auth', 'Authentication cancelled by user').code, errAuthCancelled);
      expect(map('x', 'KeyPermanentlyInvalidatedException').code, errKeyInvalidated);
      expect(map('x', 'Biometric lockout, too many attempts').code, errAuthFailed);
      expect(map('x', 'No biometrics enrolled').code, errAuthUnavailable);
    });

    test('anything else is a storage error, and the message never carries the original text', () {
      final mapped = map('Unexpected', 'secret-value-123');

      expect(mapped.code, errStorageError);
      expect(mapped.message, isNot(contains('secret-value-123')));
    });

    test('an unexpected exception inside a handler comes back as storage_error, not a crash', () async {
      final broken = SecureStoragePlugin(backend: _ThrowingBackend(), probe: probe);

      expectError(await broken.handlers['set']!({'key': 'k', 'value': 'v'}), errStorageError);
      expectError(await broken.handlers['keys']!({}), errStorageError);
    });
  });
}

class _ThrowingBackend implements SecureBackend {
  @override
  Future<String?> read(String key, {required bool auth, String? prompt}) => throw StateError('boom');

  @override
  Future<void> write(String key, String value, {required bool auth, String? prompt}) => throw StateError('boom');

  @override
  Future<void> delete(String key, {required bool auth}) => throw StateError('boom');
}
