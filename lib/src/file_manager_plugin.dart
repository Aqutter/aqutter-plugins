import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:aqutter/aqutter.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:path_provider/path_provider.dart';

import 'local_file_ops.dart';
import 'location.dart';
import 'media_saver.dart';

/// 取得 App 的資料夾；測試可注入。
typedef SandboxRootResolver = Future<Directory> Function(String root);

Future<Directory> _defaultRoot(String root) {
  switch (root) {
    case 'app-documents':
      return getApplicationDocumentsDirectory();
    case 'app-support':
      return getApplicationSupportDirectory();
    case 'app-cache':
      return getApplicationCacheDirectory();
    default:
      return getTemporaryDirectory();
  }
}

/// `file-manager` plugin 的 Dart 端：App 資料夾內的檔案管理（契約 `sandbox` 功能）。
///
/// 網頁以位置字串（`app-documents:報表/a.pdf`）指定檔案，路徑驗證與根解析都在這裡，
/// 網頁不會拿到各平台不同的實際路徑。
class FileManagerPlugin extends AqutterPlugin {
  FileManagerPlugin({SandboxRootResolver? rootResolver, GalleryWriter? gallery, FileSaveDialog? saveDialog, TargetPlatform? platform})
      : _rootResolver = rootResolver ?? _defaultRoot,
        _gallery = gallery ?? GalGalleryWriter(),
        _saveDialog = saveDialog ?? FilePickerSaveDialog(),
        _platform = platform;

  final SandboxRootResolver _rootResolver;
  final GalleryWriter _gallery;
  final FileSaveDialog _saveDialog;
  final TargetPlatform? _platform;

  @override
  String get id => 'file-manager';

  /// 相簿只有行動平台；其他方法在支援的平台上都可用（桌面的授權與下載之後補上）。
  @override
  Set<TargetPlatform>? supportedPlatformsFor(String method) {
    return method == 'saveToGallery' ? const {TargetPlatform.android, TargetPlatform.iOS} : null;
  }

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        'saveToGallery': _guard((payload) => saveToGallery(payload, _gallery)),
        'saveToDownloads': _guard((payload) async {
          // 從位置讀檔是同步的檔案操作：先解析出該位置的 ops，再交給驗證函式
          final from = payload['from'];
          final ops = from == null ? null : await _opsFor(parseLocation(from));
          return saveToDownloads(
            payload,
            _saveDialog,
            (location) => ops!.readAll(location.segments, maxDownloadBytes),
            _platform ?? defaultTargetPlatform,
          );
        }),
        'list': _guard((payload) async {
          final (ops, location) = await _ops(payload['location']);
          return {'entries': ops.list(location.segments)};
        }),
        'stat': _guard((payload) async {
          final (ops, location) = await _ops(payload['location']);
          return ops.stat(location.segments);
        }),
        'read': _guard((payload) async {
          final (ops, location) = await _ops(payload['location']);
          return ops.read(location.segments, offset: _optInt(payload, 'offset') ?? 0, length: _optInt(payload, 'length'));
        }),
        'write': _guard((payload) async {
          final (ops, location) = await _ops(payload['location']);
          final data = payload['data'];
          if (data is! Uint8List) {
            throw const FileManagerException(errInvalidPath, 'data 必須是二進位');
          }
          return {'size': ops.write(location.segments, data, payload['mode'] as String? ?? '')};
        }),
        'makeDirectory': _guard((payload) async {
          final (ops, location) = await _ops(payload['location']);
          ops.makeDirectory(location.segments, recursive: payload['recursive'] == true);
          return <String, dynamic>{};
        }),
        'copy': _guard((payload) async {
          final (ops, from, to) = await _opsPair(payload);
          ops.copy(from.segments, to.segments, overwrite: payload['overwrite'] == true);
          return <String, dynamic>{};
        }),
        'move': _guard((payload) async {
          final (ops, from, to) = await _opsPair(payload);
          ops.move(from.segments, to.segments, overwrite: payload['overwrite'] == true);
          return <String, dynamic>{};
        }),
        'delete': _guard((payload) async {
          final (ops, location) = await _ops(payload['location']);
          ops.delete(location.segments, recursive: payload['recursive'] == true);
          return <String, dynamic>{};
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

  Future<(LocalFileOps, Location)> _ops(Object? value) async {
    final location = parseLocation(value);
    return (await _opsFor(location), location);
  }

  Future<(LocalFileOps, Location, Location)> _opsPair(Map<String, dynamic> payload) async {
    final from = parseLocation(payload['from']);
    final to = parseLocation(payload['to']);
    if (!from.sameRootAs(to)) {
      throw const FileManagerException(errCrossRoot, '來源與目標不在同一個根；請改用讀取加寫入');
    }
    return (await _opsFor(from), from, to);
  }

  Future<LocalFileOps> _opsFor(Location location) async {
    if (location.grantId != null) {
      throw FileManagerException(errNotFound, '沒有授權「${location.grantId}」');
    }
    return LocalFileOps(await _rootResolver(location.root));
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
