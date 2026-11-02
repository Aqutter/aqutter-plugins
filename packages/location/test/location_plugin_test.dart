import 'dart:async';

import 'package:aqutter/aqutter.dart';
import 'package:aqutter_plugin_location/src/locator.dart';
import 'package:aqutter_plugin_location/src/location_plugin.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

const LocationFix _taipei = LocationFix(latitude: 25.033, longitude: 121.5654, accuracy: 8.5, timestamp: 1000, altitude: 12, speed: 0.5);

class _FakeLocator implements Locator {
  bool enabled = true;
  LocationFix fix = _taipei;
  LocationException? failure;
  final List<Map<String, Object?>> currentCalls = [];
  final List<StreamController<LocationFix>> watchers = [];
  final List<Map<String, Object?>> watchCalls = [];
  int settingsOpened = 0;

  @override
  Future<bool> serviceEnabled() async => enabled;

  @override
  Future<LocationFix> current({required LocationAccuracyLevel accuracy, required Duration timeout}) async {
    currentCalls.add({'accuracy': accuracy.wire, 'timeout': timeout});
    final error = failure;
    if (error != null) {
      throw error;
    }
    return fix;
  }

  @override
  Stream<LocationFix> watch({required LocationAccuracyLevel accuracy, required int distanceFilterMeters, Duration? interval}) {
    watchCalls.add({'accuracy': accuracy.wire, 'distanceFilter': distanceFilterMeters, 'interval': interval});
    final controller = StreamController<LocationFix>();
    watchers.add(controller);
    return controller.stream;
  }

  @override
  Future<void> openLocationSettings() async => settingsOpened++;
}

class _FakePermissions implements PermissionGate {
  String status = 'granted';
  String afterRequest = 'granted';
  int appSettings = 0;

  @override
  Future<String> check() async => status;

  @override
  Future<String> request() async {
    status = afterRequest;
    return status;
  }

  @override
  Future<void> openAppSettings() async => appSettings++;
}

class _FakeContext implements AqutterPluginContext {
  final List<(String, Object?)> events = [];

  @override
  Future<void> emit(String event, Object? payload) async => events.add((event, payload));

  @override
  Future<String> checkPermission(String type) async => 'granted';

  @override
  Future<String> requestPermission(String type) async => 'granted';

  @override
  Future<void> openPermissionSettings() async {}
}

void main() {
  late _FakeLocator locator;
  late _FakePermissions permissions;
  late _FakeContext context;
  late LocationPlugin plugin;

  Future<dynamic> call(String method, [Map<String, dynamic> payload = const {}]) => plugin.handlers[method]!(payload);

  void expectError(dynamic result, String code) {
    final error = aqutterErrorOf(result);
    expect(error, isNotNull, reason: 'expected $code, got $result');
    expect(error!.code, code);
  }

  setUp(() {
    locator = _FakeLocator();
    permissions = _FakePermissions();
    context = _FakeContext();
    plugin = LocationPlugin(locator: locator, permissions: permissions)..attach(context);
  });

  tearDown(() => plugin.dispose());

  test('id, handlers and platforms (no Linux)', () {
    expect(plugin.id, 'location');
    expect(plugin.handlers.keys, unorderedEquals(['capabilities', 'requestPermission', 'getCurrentPosition', 'startWatching', 'stopWatching', 'openSettings']));
    expect(plugin.supportedPlatforms, {TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.windows});
  });

  group('capabilities and permission', () {
    test('reports whether location services are on and the permission status', () async {
      expect(await call('capabilities'), {'serviceEnabled': true, 'permission': 'granted'});

      locator.enabled = false;
      permissions.status = 'denied';
      expect(await call('capabilities'), {'serviceEnabled': false, 'permission': 'denied'});
    });

    test('requestPermission asks the system and returns the new status', () async {
      permissions
        ..status = 'denied'
        ..afterRequest = 'granted';

      expect(await call('requestPermission'), {'permission': 'granted'});
    });

    test('a permanently denied permission stays denied after a request', () async {
      permissions
        ..status = 'permanentlyDenied'
        ..afterRequest = 'permanentlyDenied';

      expect(await call('requestPermission'), {'permission': 'permanentlyDenied'});
    });
  });

  group('getCurrentPosition', () {
    test('defaults to high accuracy and a 15 second timeout', () async {
      final result = await call('getCurrentPosition') as Map;

      expect(locator.currentCalls.single, {'accuracy': 'high', 'timeout': const Duration(seconds: 15)});
      final position = result['position'] as Map;
      expect(position['latitude'], 25.033);
      expect(position['longitude'], 121.5654);
      expect(position['accuracy'], 8.5);
      expect(position['timestamp'], 1000);
    });

    test('fields the platform does not report are omitted, not sent as null', () async {
      final position = (await call('getCurrentPosition') as Map)['position'] as Map;

      expect(position.containsKey('altitude'), isTrue);
      expect(position.containsKey('heading'), isFalse);
      expect(position.containsKey('altitudeAccuracy'), isFalse);
    });

    test('passes accuracy and timeout through', () async {
      await call('getCurrentPosition', {'accuracy': 'low', 'timeoutMs': 5000});

      expect(locator.currentCalls.single, {'accuracy': 'low', 'timeout': const Duration(seconds: 5)});
    });

    test('without permission it refuses and never asks the system for a position', () async {
      permissions.status = 'denied';

      expectError(await call('getCurrentPosition'), 'permission_denied');
      expect(locator.currentCalls, isEmpty);
    });

    test('with location services off it says so', () async {
      locator.enabled = false;

      expectError(await call('getCurrentPosition'), 'location_services_disabled');
      expect(locator.currentCalls, isEmpty);
    });

    test('timeouts and unavailable positions come back as their own codes', () async {
      locator.failure = const LocationException('timeout', 'no fix');
      expectError(await call('getCurrentPosition'), 'timeout');

      locator.failure = const LocationException('position_unavailable', 'no signal');
      expectError(await call('getCurrentPosition'), 'position_unavailable');
    });

    test('validates the arguments', () async {
      expectError(await call('getCurrentPosition', {'accuracy': 'best'}), 'invalid_argument');
      expectError(await call('getCurrentPosition', {'timeoutMs': 999}), 'invalid_argument');
      expectError(await call('getCurrentPosition', {'timeoutMs': 60001}), 'invalid_argument');
      expectError(await call('getCurrentPosition', {'timeoutMs': '5000'}), 'invalid_argument');
      expect(locator.currentCalls, isEmpty);
    });
  });

  group('watching', () {
    test('startWatching returns an id and pushes positions as events', () async {
      final started = await call('startWatching', {'distanceFilterMeters': 5, 'intervalMs': 2000}) as Map;
      final watchId = started['watchId'] as int;

      expect(locator.watchCalls.single, {'accuracy': 'high', 'distanceFilter': 5, 'interval': const Duration(seconds: 2)});

      locator.watchers.single.add(_taipei);
      await Future<void>.delayed(Duration.zero);

      expect(context.events, hasLength(1));
      expect(context.events.single.$1, 'position');
      final payload = context.events.single.$2 as Map;
      expect(payload['watchId'], watchId);
      expect((payload['position'] as Map)['latitude'], 25.033);
    });

    test('each watch has its own id and stopWatching ends only that one', () async {
      final a = (await call('startWatching') as Map)['watchId'] as int;
      final b = (await call('startWatching') as Map)['watchId'] as int;
      expect(a, isNot(b));

      expect(await call('stopWatching', {'watchId': a}), <String, dynamic>{});
      expect(locator.watchers[0].hasListener, isFalse);
      expect(locator.watchers[1].hasListener, isTrue);
    });

    test('stopping an unknown id still succeeds', () async {
      expect(await call('stopWatching', {'watchId': 999}), <String, dynamic>{});
      expectError(await call('stopWatching', {'watchId': 'x'}), 'invalid_argument');
      expectError(await call('stopWatching'), 'invalid_argument');
    });

    test('at most 8 watches at the same time', () async {
      for (var i = 0; i < maxWatches; i++) {
        await call('startWatching');
      }

      expectError(await call('startWatching'), 'too_many_watches');
    });

    test('a stopped watch frees a slot', () async {
      final ids = <int>[];
      for (var i = 0; i < maxWatches; i++) {
        ids.add((await call('startWatching') as Map)['watchId'] as int);
      }
      await call('stopWatching', {'watchId': ids.first});

      expect(await call('startWatching'), contains('watchId'));
    });

    test('without permission or with services off it refuses to start', () async {
      permissions.status = 'denied';
      expectError(await call('startWatching'), 'permission_denied');

      permissions.status = 'granted';
      locator.enabled = false;
      expectError(await call('startWatching'), 'location_services_disabled');
      expect(locator.watchCalls, isEmpty);
    });

    test('a temporary error is reported but the watch keeps going', () async {
      await call('startWatching');
      locator.watchers.single.addError(const LocationException('position_unavailable', 'no signal'));
      await Future<void>.delayed(Duration.zero);
      locator.watchers.single.add(_taipei);
      await Future<void>.delayed(Duration.zero);

      expect(context.events.map((e) => e.$1), ['error', 'position']);
      expect((context.events.first.$2 as Map)['code'], 'position_unavailable');
    });

    test('a revoked permission or disabled service reports the error and ends that watch', () async {
      await call('startWatching');
      await call('startWatching');
      locator.watchers.first.addError(const LocationException('permission_denied', 'revoked'));
      await Future<void>.delayed(Duration.zero);

      expect((context.events.single.$2 as Map)['code'], 'permission_denied');
      expect(locator.watchers.first.hasListener, isFalse);
      expect(locator.watchers.last.hasListener, isTrue);
    });

    test('dispose stops every watch', () async {
      await call('startWatching');
      await call('startWatching');

      plugin.dispose();

      expect(locator.watchers.every((c) => !c.hasListener), isTrue);
    });

    test('validates the arguments', () async {
      expectError(await call('startWatching', {'accuracy': 'x'}), 'invalid_argument');
      expectError(await call('startWatching', {'distanceFilterMeters': -1}), 'invalid_argument');
      expectError(await call('startWatching', {'distanceFilterMeters': 10001}), 'invalid_argument');
      expectError(await call('startWatching', {'intervalMs': 100}), 'invalid_argument');
      expect(locator.watchCalls, isEmpty);
    });
  });

  group('openSettings', () {
    test('app opens the app settings, location opens the location settings', () async {
      await call('openSettings', {'target': 'app'});
      await call('openSettings', {'target': 'location'});

      expect(permissions.appSettings, 1);
      expect(locator.settingsOpened, 1);
    });

    test('anything else is invalid', () async {
      expectError(await call('openSettings', {'target': 'wifi'}), 'invalid_argument');
      expectError(await call('openSettings'), 'invalid_argument');
    });
  });
}
