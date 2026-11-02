import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:geolocator/geolocator.dart';

/// 回給網頁的位置（契約 §1 的 `Position`）。
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.altitude,
    this.altitudeAccuracy,
    this.heading,
    this.speed,
    this.isMocked,
  });

  final double latitude;
  final double longitude;

  /// 水平精度，公尺。
  final double accuracy;

  /// Unix 毫秒。
  final int timestamp;
  final double? altitude;
  final double? altitudeAccuracy;
  final double? heading;
  final double? speed;
  final bool? isMocked;

  /// 平台沒有的欄位省略（不送 null）。
  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': timestamp,
        if (altitude != null) 'altitude': altitude,
        if (altitudeAccuracy != null) 'altitudeAccuracy': altitudeAccuracy,
        if (heading != null) 'heading': heading,
        if (speed != null) 'speed': speed,
        if (isMocked != null) 'isMocked': isMocked,
      };
}

/// 契約 §3 的錯誤碼。
class LocationException implements Exception {
  const LocationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

const String errInvalidArgument = 'invalid_argument';
const String errPermissionDenied = 'permission_denied';
const String errServicesDisabled = 'location_services_disabled';
const String errTimeout = 'timeout';
const String errPositionUnavailable = 'position_unavailable';
const String errTooManyWatches = 'too_many_watches';

/// 精度三檔（契約 §2）。
enum LocationAccuracyLevel {
  high('high'),
  balanced('balanced'),
  low('low');

  const LocationAccuracyLevel(this.wire);

  final String wire;

  static LocationAccuracyLevel? parse(Object? value) {
    for (final level in values) {
      if (level.wire == value) {
        return level;
      }
    }
    return null;
  }
}

/// 取得位置的來源；測試以假的實作取代。
abstract interface class Locator {
  Future<bool> serviceEnabled();

  /// 取得一次；逾時回 `timeout`。權限與定位服務的問題以 [LocationException] 回報。
  Future<LocationFix> current({required LocationAccuracyLevel accuracy, required Duration timeout});

  /// 持續監聽；錯誤以 stream 的 error 事件送出（[LocationException]）。
  Stream<LocationFix> watch({
    required LocationAccuracyLevel accuracy,
    required int distanceFilterMeters,
    Duration? interval,
  });

  /// 開系統的定位服務設定頁。
  Future<void> openLocationSettings();
}

/// 把底層的例外對應成契約的錯誤碼；不把原始訊息交給網頁。
LocationException mapLocatorError(Object error) {
  if (error is LocationException) {
    return error;
  }
  if (error is PermissionDeniedException || error is InvalidPermissionException) {
    return const LocationException(errPermissionDenied, '沒有定位權限');
  }
  if (error is LocationServiceDisabledException) {
    return const LocationException(errServicesDisabled, '系統的定位服務已關閉');
  }
  if (error is TimeoutException) {
    return const LocationException(errTimeout, '在逾時內沒有取得位置');
  }
  return const LocationException(errPositionUnavailable, '系統無法取得位置');
}

LocationFix _fixOf(Position position) {
  return LocationFix(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy,
    timestamp: position.timestamp.millisecondsSinceEpoch,
    altitude: position.hasAltitude ? position.altitude : null,
    altitudeAccuracy: position.hasAltitudeAccuracy ? position.altitudeAccuracy : null,
    heading: position.hasHeading ? position.heading : null,
    speed: position.hasSpeed ? position.speed : null,
    isMocked: position.isMocked,
  );
}

LocationAccuracy _systemAccuracy(LocationAccuracyLevel level) {
  switch (level) {
    case LocationAccuracyLevel.high:
      return LocationAccuracy.best;
    case LocationAccuracyLevel.balanced:
      return LocationAccuracy.medium;
    case LocationAccuracyLevel.low:
      return LocationAccuracy.low;
  }
}

/// 以 `geolocator` 實作。
class GeolocatorLocator implements Locator {
  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationFix> current({required LocationAccuracyLevel accuracy, required Duration timeout}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: _systemAccuracy(accuracy), timeLimit: timeout),
      );
      return _fixOf(position);
    }
    catch (error) {
      throw mapLocatorError(error);
    }
  }

  @override
  Stream<LocationFix> watch({
    required LocationAccuracyLevel accuracy,
    required int distanceFilterMeters,
    Duration? interval,
  }) {
    // 更新間隔只有 Android 能設定；其他平台只當提示、不使用
    final LocationSettings settings = interval != null && defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: _systemAccuracy(accuracy),
            distanceFilter: distanceFilterMeters,
            intervalDuration: interval,
          )
        : LocationSettings(accuracy: _systemAccuracy(accuracy), distanceFilter: distanceFilterMeters);
    return Geolocator.getPositionStream(locationSettings: settings).map(_fixOf).handleError((Object error) {
      throw mapLocatorError(error);
    });
  }

  @override
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}
