import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:aqutter/aqutter.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_ops.dart';
import 'grants.dart';
import 'local_file_ops.dart';
import 'location.dart';
import 'media_saver.dart';
import 'saf_file_ops.dart';

/// 取得 App 的資料夾；測試可注入。
typedef SandboxRootResolver = Future<Directory> Function(String root);

/// 桌面平台的「文件」與「暫存」是使用者與其他程式共用的資料夾（例如 Windows 的文件資料夾、系統暫存），
/// 不是這個 App 自己的；行動平台上它們是 App 專屬的。為了讓 `app-*` 一律只指 App 自己的資料夾，
/// 桌面改在 App 的支援／快取資料夾底下各開一個子資料夾。
bool get _isDesktop => const {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}.contains(defaultTargetPlatform);

Future<Directory> _privateSubfolder(Directory base, String name) async {
  return Directory(p.join(base.path, name)).create(recursive: true);
}

Future<Directory> _defaultRoot(String root) async {
  switch (root) {
    case 'app-documents':
      return _isDesktop ? _privateSubfolder(await getApplicationSupportDirectory(), 'documents') : getApplicationDocumentsDirectory();
    case 'app-support':
      return getApplicationSupportDirectory();
    case 'app-cache':
      return getApplicationCacheDirectory();
    default:
      return _isDesktop ? _privateSubfolder(await getApplicationCacheDirectory(), 'temp') : getTemporaryDirectory();
  }
}

/// 一個位置解析後的結果：在哪個根上、用哪組路徑段操作。
class _Target {
  const _Target(this.ops, this.segments, {this.isFileGrant = false});

  final FileOps ops;
  final List<String> segments;

  /// 單一檔案的授權：只能對那個檔案本身操作。
  final bool isFileGrant;
}

/// `file-manager` plugin 的 Dart 端：App 資料夾、使用者授權的位置、相簿與下載。
///
/// 網頁以位置字串（`app-documents:報表/a.pdf`、`granted:<編號>/子/路徑`）指定檔案，路徑驗證與根解析都在這裡，
/// 網頁不會拿到各平台不同的實際路徑。
class FileManagerPlugin extends AqutterPlugin {
  FileManagerPlugin({
    SandboxRootResolver? rootResolver,
    GalleryWriter? gallery,
    FileSaveDialog? saveDialog,
    GrantManager? grants,
    TargetPlatform? platform,
  })  : _rootResolver = rootResolver ?? _defaultRoot,
        _gallery = gallery ?? GalGalleryWriter(),
        _saveDialog = saveDialog ?? FilePickerSaveDialog(),
        _grants = grants ?? GrantManager(),
        _platform = platform;

  final SandboxRootResolver _rootResolver;
  final GalleryWriter _gallery;
  final FileSaveDialog _saveDialog;
  final GrantManager _grants;
  final TargetPlatform? _platform;

  @override
  String get id => 'file-manager';

  /// 相簿只有行動平台；授權有 Android 與桌面（iOS 之後補上）；其他方法各平台都可用。
  @override
  Set<TargetPlatform>? supportedPlatformsFor(String method) {
    switch (method) {
      case 'saveToGallery':
        return const {TargetPlatform.android, TargetPlatform.iOS};
      case 'grant':
      case 'grants':
      case 'revoke':
        return const {TargetPlatform.android, TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux};
      default:
        return null;
    }
  }

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        'list': _guard((payload) async {
          final target = await _target(payload['location']);
          return {'entries': await target.ops.list(target.segments)};
        }),
        'stat': _guard((payload) async {
          final target = await _target(payload['location']);
          return await target.ops.stat(target.segments);
        }),
        'read': _guard((payload) async {
          final target = await _target(payload['location']);
          return await target.ops.read(target.segments, offset: _optInt(payload, 'offset') ?? 0, length: _optInt(payload, 'length'));
        }),
        'write': _guard((payload) async {
          final target = await _target(payload['location']);
          final data = payload['data'];
          if (data is! Uint8List) {
            throw const FileManagerException(errInvalidPath, 'data 必須是二進位');
          }
          return {'size': await target.ops.write(target.segments, data, payload['mode'] as String? ?? '')};
        }),
        'makeDirectory': _guard((payload) async {
          final target = await _target(payload['location']);
          if (target.isFileGrant) {
            throw const FileManagerException(errNotADirectory, '這個授權是單一檔案，不能建資料夾');
          }
          await target.ops.makeDirectory(target.segments, recursive: payload['recursive'] == true);
          return <String, dynamic>{};
        }),
        'copy': _guard((payload) async {
          final (from, to) = await _targetPair(payload);
          await from.ops.copy(from.segments, to.segments, overwrite: payload['overwrite'] == true);
          return <String, dynamic>{};
        }),
        'move': _guard((payload) async {
          final (from, to) = await _targetPair(payload);
          await from.ops.move(from.segments, to.segments, overwrite: payload['overwrite'] == true);
          return <String, dynamic>{};
        }),
        'delete': _guard((payload) async {
          final target = await _target(payload['location']);
          await target.ops.delete(target.segments, recursive: payload['recursive'] == true);
          return <String, dynamic>{};
        }),
        'grant': _guard((payload) async {
          final granted = await _grants.grant(payload['kind']);
          return {'grants': granted.map((g) => g.toPublic()).toList()};
        }),
        'grants': _guard((payload) async {
          return {'grants': (await _grants.list()).map((g) => g.toPublic()).toList()};
        }),
        'revoke': _guard((payload) async {
          await _grants.revoke(payload['id']);
          return <String, dynamic>{};
        }),
        'saveToGallery': _guard((payload) => saveToGallery(payload, _gallery)),
        'saveToDownloads': _guard((payload) async {
          // 從位置讀檔是同步的檔案操作：先解析出該位置的操作對象，再交給驗證函式
          final from = payload['from'];
          final target = from == null ? null : await _target(from);
          return saveToDownloads(
            payload,
            _saveDialog,
            () async => target!.ops.readAll(target.segments, maxDownloadBytes),
            _platform ?? defaultTargetPlatform,
          );
        }),
      };

  /// 把契約的錯誤轉成殼的錯誤資料；其他例外（磁碟錯誤等）照樣往外丟，由殼回報為一般失敗。
  AqutterPluginHandler _guard(AqutterPluginHandler handler) {
    return (payload) async {
      try {
        return await handler(payload);
      }
      on FileManagerException catch (error) {
        return aqutterErrorPayload(error.code, error.message);
      }
    };
  }

  Future<_Target> _target(Object? value) async => _resolve(parseLocation(value));

  Future<(_Target, _Target)> _targetPair(Map<String, dynamic> payload) async {
    final from = parseLocation(payload['from']);
    final to = parseLocation(payload['to']);
    if (!from.sameRootAs(to)) {
      throw const FileManagerException(errCrossRoot, '來源與目標不在同一個根；請改用讀取加寫入');
    }
    final source = await _resolve(from);
    if (source.isFileGrant) {
      throw const FileManagerException(errInvalidPath, '單一檔案的授權不能複製或搬移；請改用讀取加寫入');
    }
    return (source, await _resolve(to));
  }

  Future<_Target> _resolve(Location location) async {
    final grantId = location.grantId;
    if (grantId == null) {
      return _Target(LocalFileOps(await _rootResolver(location.root)), location.segments);
    }
    final grant = await _grants.resolve(grantId);
    if (_grants.usesSaf) {
      return _Target(SafFileOps(grant.path, _grants.safBackend), location.segments);
    }
    if (grant.isDirectory) {
      return _Target(LocalFileOps(Directory(grant.path)), location.segments);
    }
    if (location.segments.isNotEmpty) {
      throw const FileManagerException(errNotADirectory, '這個授權是單一檔案，沒有子路徑');
    }
    // 單一檔案：以它所在的資料夾為根、只允許操作那個檔名
    return _Target(LocalFileOps(Directory(p.dirname(grant.path))), [p.basename(grant.path)], isFileGrant: true);
  }

  int? _optInt(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is! int) {
      throw FileManagerException(errInvalidPath, '$key 必須是整數');
    }
    return value;
  }
}
