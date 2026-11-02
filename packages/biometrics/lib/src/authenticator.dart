import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// 驗證的結果（契約 §3）。取消、失敗、被鎖定、裝置不可用都是正常結果，不是例外。
enum AuthStatus {
  authenticated('authenticated'),
  cancelled('cancelled'),
  failed('failed'),
  lockedOut('locked_out'),
  permanentlyLockedOut('permanently_locked_out'),
  unavailable('unavailable'),
  busy('busy');

  const AuthStatus(this.wire);

  /// 回給網頁的字串。
  final String wire;
}

/// 此裝置的驗證能力。
class BiometricCapabilities {
  const BiometricCapabilities({required this.available, required this.biometrics, required this.types});

  /// 有可用的驗證方式（生物辨識或裝置密碼／螢幕鎖定）。
  final bool available;

  /// 已登錄生物辨識（不含只有裝置密碼）。
  final bool biometrics;

  /// 平台能回報的生物辨識種類（契約 §1 的 `BiometricType`）。
  final List<String> types;
}

/// 叫起系統驗證視窗；測試以假的實作取代。
abstract interface class Authenticator {
  Future<BiometricCapabilities> capabilities();

  /// 一定會出現系統視窗（沒有「剛驗證過」的快取）。[title] 與 [cancelLabel] 依平台可能被忽略。
  Future<AuthStatus> authenticate({
    required String reason,
    required bool biometricOnly,
    String? title,
    String? cancelLabel,
  });
}

/// 以 `local_auth` 實作。
class LocalAuthAuthenticator implements Authenticator {
  LocalAuthAuthenticator({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricCapabilities> capabilities() async {
    try {
      final available = await _auth.isDeviceSupported();
      final enrolled = await _auth.getAvailableBiometrics();
      return BiometricCapabilities(
        available: available,
        biometrics: enrolled.isNotEmpty,
        types: [for (final type in enrolled) type.name],
      );
    }
    catch (_) {
      return const BiometricCapabilities(available: false, biometrics: false, types: []);
    }
  }

  @override
  Future<AuthStatus> authenticate({
    required String reason,
    required bool biometricOnly,
    String? title,
    String? cancelLabel,
  }) async {
    try {
      final passed = await _auth.authenticate(
        localizedReason: reason,
        authMessages: [
          AndroidAuthMessages(signInTitle: title, cancelButton: cancelLabel),
          IOSAuthMessages(cancelButton: cancelLabel),
        ],
        biometricOnly: biometricOnly,
      );
      return passed ? AuthStatus.authenticated : AuthStatus.failed;
    }
    on LocalAuthException catch (error) {
      return statusOfException(error.code);
    }
  }
}

/// 把 `local_auth` 的例外代碼對應成契約的狀態；認不得的代碼視為 `failed`，不把原始訊息交給網頁。
AuthStatus statusOfException(LocalAuthExceptionCode code) {
  switch (code) {
    case LocalAuthExceptionCode.userCanceled:
    case LocalAuthExceptionCode.systemCanceled:
    case LocalAuthExceptionCode.timeout:
    case LocalAuthExceptionCode.userRequestedFallback:
      return AuthStatus.cancelled;
    case LocalAuthExceptionCode.authInProgress:
      return AuthStatus.busy;
    case LocalAuthExceptionCode.noCredentialsSet:
    case LocalAuthExceptionCode.noBiometricsEnrolled:
    case LocalAuthExceptionCode.noBiometricHardware:
    case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
    case LocalAuthExceptionCode.uiUnavailable:
      return AuthStatus.unavailable;
    case LocalAuthExceptionCode.temporaryLockout:
      return AuthStatus.lockedOut;
    case LocalAuthExceptionCode.biometricLockout:
      return AuthStatus.permanentlyLockedOut;
    default:
      return AuthStatus.failed;
  }
}
