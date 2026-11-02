/// 位置字串與路徑驗證（契約 §1、§2）。網頁不碰各平台不同的路徑，只用 `<根>:<相對路徑>`。
library;

/// 回給網頁的錯誤；[code] 是契約 §3 的錯誤碼。
class FileManagerException implements Exception {
  const FileManagerException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

const String errInvalidPath = 'invalid_path';
const String errNotFound = 'not_found';
const String errAlreadyExists = 'already_exists';
const String errNotADirectory = 'not_a_directory';
const String errIsADirectory = 'is_a_directory';
const String errNotEmpty = 'not_empty';
const String errTooLarge = 'too_large';
const String errPermissionDenied = 'permission_denied';
const String errCrossRoot = 'cross_root_unsupported';

/// 單次讀寫的內容上限：與殼的剪貼簿圖片、分享一致。
const int maxContentBytes = 5 * 1024 * 1024;

const int _maxSegmentLength = 255;
const int _maxPathLength = 1024;

/// App 自己的資料夾，名稱對應位置字串的根。
const List<String> sandboxRoots = ['app-documents', 'app-support', 'app-cache', 'app-temp'];

/// 解析後的位置：[root] 是 `app-documents` 等或 `granted:<id>` 的 `granted`，[grantId] 只在授權位置有值。
class Location {
  const Location({required this.root, required this.segments, this.grantId});

  final String root;
  final String? grantId;
  final List<String> segments;

  /// 同一個根：sandbox 看根名稱，授權看編號。
  bool sameRootAs(Location other) => root == other.root && grantId == other.grantId;

  bool get isRoot => segments.isEmpty;

  @override
  String toString() => '${grantId == null ? root : 'granted:$grantId'}:${segments.join('/')}';
}

/// 解析位置字串；不合法一律 `invalid_path`。
///
/// 格式：`app-documents:報表/a.pdf`、`app-cache:`（根本身）、`granted:<編號>/子/路徑`（編號後的 `/` 起算相對路徑）。
Location parseLocation(Object? value) {
  if (value is! String || value.isEmpty) {
    throw const FileManagerException(errInvalidPath, 'location 必須是非空字串');
  }
  if (value.startsWith('granted:')) {
    final rest = value.substring('granted:'.length);
    final slash = rest.indexOf('/');
    final id = slash == -1 ? rest : rest.substring(0, slash);
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id)) {
      throw const FileManagerException(errInvalidPath, '授權編號不合法');
    }
    final relative = slash == -1 ? '' : rest.substring(slash + 1);
    return Location(root: 'granted', grantId: id, segments: _segments(relative));
  }
  final colon = value.indexOf(':');
  if (colon == -1 || !sandboxRoots.contains(value.substring(0, colon))) {
    throw FileManagerException(errInvalidPath, '未知的位置根，可用：${sandboxRoots.join('、')}、granted:<編號>');
  }
  return Location(root: value.substring(0, colon), segments: _segments(value.substring(colon + 1)));
}

/// 相對路徑：以 `/` 分段；不得有 `.`、`..`、空段（開頭與結尾的 `/` 不接受）、反斜線、NUL 或控制字元。
List<String> _segments(String relative) {
  if (relative.isEmpty) {
    return const [];
  }
  if (relative.length > _maxPathLength) {
    throw const FileManagerException(errInvalidPath, '路徑長度不得超過 $_maxPathLength');
  }
  final parts = relative.split('/');
  for (final part in parts) {
    if (part.isEmpty || part == '.' || part == '..') {
      throw FileManagerException(errInvalidPath, '路徑含有不合法的段：「$part」');
    }
    if (part.length > _maxSegmentLength) {
      throw const FileManagerException(errInvalidPath, '路徑的每一段不得超過 $_maxSegmentLength');
    }
    if (part.contains('\\') || part.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
      throw FileManagerException(errInvalidPath, '路徑的段含有反斜線或控制字元：「$part」');
    }
  }
  return parts;
}
