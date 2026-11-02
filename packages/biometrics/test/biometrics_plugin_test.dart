import 'dart:async';

import 'package:aqutter/aqutter.dart';
import 'package:aqutter_plugin_biometrics/aqutter_plugin_biometrics.dart';
import 'package:aqutter_plugin_biometrics/src/authenticator.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

class _FakeAuthenticator implements Authenticator {
  BiometricCapabilities caps = const BiometricCapabilities(available: true, biometrics: true, types: ['fingerprint']);
  AuthStatus next = AuthStatus.authenticated;
  Completer<AuthStatus>? hold;
  final List<Map<String, Object?>> calls = [];

  @override
  Future<BiometricCapabilities> capabilities() async => caps;

  @override
  Future<AuthStatus> authenticate({required String reason, required bool biometricOnly, String? title, String? cancelLabel}) async {
    calls.add({'reason': reason, 'biometricOnly': biometricOnly, 'title': title, 'cancelLabel': cancelLabel});
    return hold == null ? next : hold!.future;
  }
}

class _ThrowingAuthenticator implements Authenticator {
  @override
  Future<BiometricCapabilities> capabilities() => throw StateError('boom');

  @override
  Future<AuthStatus> authenticate({required String reason, required bool biometricOnly, String? title, String? cancelLabel}) {
    throw StateError('boom');
  }
}

void main() {
  late _FakeAuthenticator auth;
  late BiometricsPlugin plugin;

  Future<dynamic> call(String method, [Map<String, dynamic> payload = const {}]) => plugin.handlers[method]!(payload);

  void expectInvalid(dynamic result) {
    final error = aqutterErrorOf(result);
    expect(error, isNotNull, reason: '$result');
    expect(error!.code, 'invalid_argument');
  }

  setUp(() {
    auth = _FakeAuthenticator();
    plugin = BiometricsPlugin(authenticator: auth);
  });

  test('id, handlers and platforms (Linux is not supported)', () {
    expect(plugin.id, 'biometrics');
    expect(plugin.handlers.keys, unorderedEquals(['capabilities', 'authenticate']));
    expect(plugin.supportedPlatforms, {TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.windows});
  });

  group('capabilities', () {
    test('reports what the device can do', () async {
      expect(await call('capabilities'), {'available': true, 'biometrics': true, 'types': ['fingerprint']});

      auth.caps = const BiometricCapabilities(available: true, biometrics: false, types: []);
      expect(await call('capabilities'), {'available': true, 'biometrics': false, 'types': <String>[]});

      auth.caps = const BiometricCapabilities(available: false, biometrics: false, types: []);
      expect((await call('capabilities') as Map)['available'], isFalse);
    });
  });

  group('authenticate', () {
    test('returns the status and passes the options through', () async {
      final result = await call('authenticate', {'reason': '確認身分', 'title': '解鎖', 'cancelLabel': '取消', 'biometricOnly': true});

      expect(result, {'status': 'authenticated'});
      expect(auth.calls.single, {'reason': '確認身分', 'biometricOnly': true, 'title': '解鎖', 'cancelLabel': '取消'});
    });

    test('biometricOnly defaults to false, so a device password can be used', () async {
      await call('authenticate', {'reason': 'x'});

      expect(auth.calls.single['biometricOnly'], isFalse);
      expect(auth.calls.single['title'], isNull);
    });

    test('every status is a normal result, never an error', () async {
      for (final status in AuthStatus.values) {
        auth.next = status;
        expect(await call('authenticate', {'reason': 'x'}), {'status': status.wire}, reason: status.name);
      }
    });

    test('there is no cache: every call shows the prompt again', () async {
      await call('authenticate', {'reason': 'x'});
      await call('authenticate', {'reason': 'x'});

      expect(auth.calls, hasLength(2));
    });

    test('a second call while a prompt is showing is busy and does not open another prompt', () async {
      auth.hold = Completer<AuthStatus>();
      final first = call('authenticate', {'reason': 'x'});
      await Future<void>.delayed(Duration.zero);

      expect(await call('authenticate', {'reason': 'y'}), {'status': 'busy'});
      expect(auth.calls, hasLength(1));

      auth.hold!.complete(AuthStatus.authenticated);
      expect(await first, {'status': 'authenticated'});
      auth.hold = null;
      expect(await call('authenticate', {'reason': 'z'}), {'status': 'authenticated'});
    });

    test('a failing prompt does not leave the plugin stuck on busy', () async {
      final broken = BiometricsPlugin(authenticator: _ThrowingAuthenticator());

      await expectLater(broken.handlers['authenticate']!({'reason': 'x'}), throwsStateError);
      await expectLater(broken.handlers['authenticate']!({'reason': 'x'}), throwsStateError);
    });

    test('validates the arguments', () async {
      expectInvalid(await call('authenticate'));
      expectInvalid(await call('authenticate', {'reason': ''}));
      expectInvalid(await call('authenticate', {'reason': 5}));
      expectInvalid(await call('authenticate', {'reason': 'x' * 101}));
      expectInvalid(await call('authenticate', {'reason': 'x', 'title': 'x' * 61}));
      expectInvalid(await call('authenticate', {'reason': 'x', 'title': 3}));
      expectInvalid(await call('authenticate', {'reason': 'x', 'cancelLabel': 'x' * 31}));
      expectInvalid(await call('authenticate', {'reason': 'x', 'biometricOnly': 'yes'}));
      expect(auth.calls, isEmpty, reason: 'nothing is shown for a bad request');
    });
  });

  group('exception mapping', () {
    test('cancelling outcomes are cancelled', () {
      for (final code in [
        LocalAuthExceptionCode.userCanceled,
        LocalAuthExceptionCode.systemCanceled,
        LocalAuthExceptionCode.timeout,
        LocalAuthExceptionCode.userRequestedFallback,
      ]) {
        expect(statusOfException(code), AuthStatus.cancelled, reason: code.name);
      }
    });

    test('a missing way to authenticate is unavailable', () {
      for (final code in [
        LocalAuthExceptionCode.noCredentialsSet,
        LocalAuthExceptionCode.noBiometricsEnrolled,
        LocalAuthExceptionCode.noBiometricHardware,
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable,
        LocalAuthExceptionCode.uiUnavailable,
      ]) {
        expect(statusOfException(code), AuthStatus.unavailable, reason: code.name);
      }
    });

    test('lockouts, busy, and everything else', () {
      expect(statusOfException(LocalAuthExceptionCode.temporaryLockout), AuthStatus.lockedOut);
      expect(statusOfException(LocalAuthExceptionCode.biometricLockout), AuthStatus.permanentlyLockedOut);
      expect(statusOfException(LocalAuthExceptionCode.authInProgress), AuthStatus.busy);
      expect(statusOfException(LocalAuthExceptionCode.unknownError), AuthStatus.failed);
      expect(statusOfException(LocalAuthExceptionCode.deviceError), AuthStatus.failed);
    });
  });
}
