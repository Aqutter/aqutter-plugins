import 'dart:async';

import 'package:aqutter/aqutter.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

import 'locator.dart';

/// 殼的權限型別字串（見 `docs/plugins.md` 的「權限」）。前景定位用「使用 App 時」。
const String locationPermissionType = 'locationWhenInUse';

const Duration defaultTimeout = Duration(seconds: 15);
const int minTimeoutMs = 1000;
const int maxTimeoutMs = 60000;
const int maxDistanceFilterMeters = 10000;
const int minIntervalMs = 500;
const int maxIntervalMs = 3600000;
const int maxWatches = 8;

/// 定位權限的存取；預設走殼的權限服務（`attach` 收到的 context），測試可注入。
abstract interface class PermissionGate {
  Future<String> check();

  Future<String> request();

  Future<void> openAppSettings();
}

class _ContextPermissionGate implements PermissionGate {
  AqutterPluginContext? context;

  @override
  Future<String> check() async => await context?.checkPermission(locationPermissionType) ?? 'denied';

  @override
  Future<String> request() async => await context?.requestPermission(locationPermissionType) ?? 'denied';

  @override
  Future<void> openAppSettings() async => context?.openPermissionSettings();
}

/// `location` plugin 的 Dart 端：取得目前位置一次，或持續監聽位置變化（前景）。
///
/// 位置不保存、不寫日誌；沒有權限時回 `permission_denied`，不會自動跳授權視窗。
class LocationPlugin extends AqutterPlugin {
  LocationPlugin({Locator? locator, PermissionGate? permissions})
      : this._(locator ?? GeolocatorLocator(), permissions, permissions == null ? _ContextPermissionGate() : null);

  LocationPlugin._(this._locator, PermissionGate? injected, this._contextGate) : _permissions = injected ?? _contextGate!;

  final Locator _locator;
  final PermissionGate _permissions;

  /// 沒有注入權限實作時，用 `attach` 收到的 context 走殼的權限服務。
  final _ContextPermissionGate? _contextGate;
  AqutterPluginContext? _context;

  final Map<int, StreamSubscription<LocationFix>> _watches = {};
  int _nextWatchId = 1;

  @override
  String get id => 'location';

  /// Linux 需要 geoclue、行為差距大，第一版不支援（契約 §1）。
  @override
  Set<TargetPlatform>? get supportedPlatforms => const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      };

  @override
  void attach(AqutterPluginContext context) {
    _context = context;
    _contextGate?.context = context;
  }

  @override
  void dispose() {
    for (final subscription in _watches.values) {
      unawaited(subscription.cancel());
    }
    _watches.clear();
    _context = null;
    _contextGate?.context = null;
  }

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        'capabilities': _guard((payload) async => {
              'serviceEnabled': await _locator.serviceEnabled(),
              'permission': await _permissions.check(),
            }),
        'requestPermission': _guard((payload) async => {'permission': await _permissions.request()}),
        'getCurrentPosition': _guard(_getCurrentPosition),
        'startWatching': _guard(_startWatching),
        'stopWatching': _guard(_stopWatching),
        'openSettings': _guard(_openSettings),
      };

  /// 把契約的錯誤轉成殼的錯誤資料。
  AqutterPluginHandler _guard(AqutterPluginHandler handler) {
    return (payload) async {
      try {
        return await handler(payload);
      }
      catch (error) {
        final mapped = mapLocatorError(error);
        return aqutterErrorPayload(mapped.code, mapped.message);
      }
    };
  }

  /// 沒有權限或定位服務關閉時直接回錯，不去問系統。
  Future<void> _requireReady() async {
    if (await _permissions.check() != 'granted') {
      throw const LocationException(errPermissionDenied, '沒有定位權限');
    }
    if (!await _locator.serviceEnabled()) {
      throw const LocationException(errServicesDisabled, '系統的定位服務已關閉');
    }
  }

  LocationAccuracyLevel _accuracy(Map<String, dynamic> payload) {
    if (payload['accuracy'] == null) {
      return LocationAccuracyLevel.high;
    }
    final level = LocationAccuracyLevel.parse(payload['accuracy']);
    if (level == null) {
      throw const LocationException(errInvalidArgument, 'accuracy 必須是 high、balanced 或 low');
    }
    return level;
  }

  int? _intInRange(Map<String, dynamic> payload, String key, int min, int max) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is! int || value < min || value > max) {
      throw LocationException(errInvalidArgument, '$key 必須是 $min 到 $max 的整數');
    }
    return value;
  }

  Future<Map<String, dynamic>> _getCurrentPosition(Map<String, dynamic> payload) async {
    final accuracy = _accuracy(payload);
    final timeoutMs = _intInRange(payload, 'timeoutMs', minTimeoutMs, maxTimeoutMs);
    await _requireReady();
    final fix = await _locator.current(
      accuracy: accuracy,
      timeout: timeoutMs == null ? defaultTimeout : Duration(milliseconds: timeoutMs),
    );
    return {'position': fix.toJson()};
  }

  Future<Map<String, dynamic>> _startWatching(Map<String, dynamic> payload) async {
    final accuracy = _accuracy(payload);
    final distanceFilter = _intInRange(payload, 'distanceFilterMeters', 0, maxDistanceFilterMeters) ?? 0;
    final intervalMs = _intInRange(payload, 'intervalMs', minIntervalMs, maxIntervalMs);
    if (_watches.length >= maxWatches) {
      throw const LocationException(errTooManyWatches, '同時監聽最多 $maxWatches 個');
    }
    await _requireReady();
    final watchId = _nextWatchId++;
    late final StreamSubscription<LocationFix> subscription;
    subscription = _locator
        .watch(
          accuracy: accuracy,
          distanceFilterMeters: distanceFilter,
          interval: intervalMs == null ? null : Duration(milliseconds: intervalMs),
        )
        .listen(
          (fix) => _emit('position', {'watchId': watchId, 'position': fix.toJson()}),
          onError: (Object error) {
            final mapped = mapLocatorError(error);
            _emit('error', {'watchId': watchId, 'code': mapped.code});
            // 權限被收回或定位服務被關掉：先通知再結束這個監聽，不會再有位置
            if (mapped.code == errPermissionDenied || mapped.code == errServicesDisabled) {
              _watches.remove(watchId);
              unawaited(subscription.cancel());
            }
          },
          cancelOnError: false,
        );
    _watches[watchId] = subscription;
    return {'watchId': watchId};
  }

  Future<Map<String, dynamic>> _stopWatching(Map<String, dynamic> payload) async {
    final watchId = payload['watchId'];
    if (watchId is! int) {
      throw const LocationException(errInvalidArgument, 'watchId 必須是整數');
    }
    await _watches.remove(watchId)?.cancel();
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _openSettings(Map<String, dynamic> payload) async {
    final target = payload['target'];
    if (target == 'app') {
      await _permissions.openAppSettings();
    }
    else if (target == 'location') {
      await _locator.openLocationSettings();
    }
    else {
      throw const LocationException(errInvalidArgument, 'target 必須是 app 或 location');
    }
    return <String, dynamic>{};
  }

  void _emit(String event, Map<String, dynamic> payload) {
    final context = _context;
    if (context != null) {
      unawaited(context.emit(event, payload));
    }
  }
}
