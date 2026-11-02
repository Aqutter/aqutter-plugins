import 'package:aqutter/aqutter.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

import 'authenticator.dart';

const int maxReasonLength = 100;
const int maxTitleLength = 60;
const int maxCancelLabelLength = 30;

/// `biometrics` plugin 的 Dart 端：叫起系統的驗證視窗（生物辨識或裝置密碼），回報驗證結果。
///
/// 這個 plugin 不知道它在保護什麼，也不保存任何東西；結果只是客戶端的判斷，不能當成伺服器端的憑證。
class BiometricsPlugin extends AqutterPlugin {
  BiometricsPlugin({Authenticator? authenticator}) : _authenticator = authenticator ?? LocalAuthAuthenticator();

  final Authenticator _authenticator;

  /// 一次只能有一個驗證視窗。
  bool _inFlight = false;

  @override
  String get id => 'biometrics';

  /// Linux 沒有對應的系統驗證（契約 §1）。
  @override
  Set<TargetPlatform>? get supportedPlatforms => const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      };

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        'capabilities': (payload) async {
          final capabilities = await _authenticator.capabilities();
          return {
            'available': capabilities.available,
            'biometrics': capabilities.biometrics,
            'types': capabilities.types,
          };
        },
        'authenticate': _authenticate,
      };

  Future<Map<String, dynamic>> _authenticate(Map<String, dynamic> payload) async {
    final reason = _requiredString(payload, 'reason', maxReasonLength);
    final title = _optionalString(payload, 'title', maxTitleLength);
    final cancelLabel = _optionalString(payload, 'cancelLabel', maxCancelLabelLength);
    final biometricOnly = payload['biometricOnly'];
    if (reason == null) {
      return aqutterErrorPayload('invalid_argument', 'reason 必須是 1 到 $maxReasonLength 字的字串');
    }
    if (title is _Invalid) {
      return aqutterErrorPayload('invalid_argument', 'title 必須是 $maxTitleLength 字以內的字串');
    }
    if (cancelLabel is _Invalid) {
      return aqutterErrorPayload('invalid_argument', 'cancelLabel 必須是 $maxCancelLabelLength 字以內的字串');
    }
    if (biometricOnly != null && biometricOnly is! bool) {
      return aqutterErrorPayload('invalid_argument', 'biometricOnly 必須是布林');
    }
    if (_inFlight) {
      return {'status': AuthStatus.busy.wire};
    }
    _inFlight = true;
    try {
      final status = await _authenticator.authenticate(
        reason: reason,
        biometricOnly: biometricOnly == true,
        title: title as String?,
        cancelLabel: cancelLabel as String?,
      );
      return {'status': status.wire};
    }
    finally {
      _inFlight = false;
    }
  }

  /// 必填字串：合法回字串，否則回 null。
  String? _requiredString(Map<String, dynamic> payload, String key, int max) {
    final value = payload[key];
    return value is String && value.isNotEmpty && value.length <= max ? value : null;
  }

  /// 選填字串：沒給回 null，合法回字串，不合法回 [_Invalid]。
  Object? _optionalString(Map<String, dynamic> payload, String key, int max) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    return value is String && value.length <= max ? value : const _Invalid();
  }
}

class _Invalid {
  const _Invalid();
}
