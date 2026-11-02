import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'file_ops.dart';
import 'location.dart';

/// 在一個根資料夾之內的檔案操作；根由呼叫端決定（App 的資料夾，或桌面上使用者授權的資料夾）。
///
/// 位置已由 [parseLocation] 驗證過；這裡再做一道防線：解析符號連結後的真實路徑必須仍在根之內。
class LocalFileOps implements FileOps {
  LocalFileOps(this.root);

  final Directory root;

  String get _rootReal => root.resolveSymbolicLinksSync();

  String _path(List<String> segments) => p.joinAll([root.path, ...segments]);

  /// 目標（或其最近的既有祖先）解析符號連結後必須在根之內。
  String _checked(List<String> segments) {
    final target = _path(segments);
    var existing = target;
    while (FileSystemEntity.typeSync(existing, followLinks: false) == FileSystemEntityType.notFound) {
      final parent = p.dirname(existing);
      if (parent == existing) {
        break;
      }
      existing = parent;
    }
    final real = File(existing).resolveSymbolicLinksSync();
    final base = _rootReal;
    if (real != base && !p.isWithin(base, real)) {
      throw const FileManagerException(errInvalidPath, '路徑超出根資料夾');
    }
    return target;
  }

  FileSystemEntityType _type(String path) => FileSystemEntity.typeSync(path, followLinks: false);

  Map<String, dynamic> _entry(String name, FileSystemEntity entity) {
    final stat = entity.statSync();
    final isDir = stat.type == FileSystemEntityType.directory;
    return {
      'name': name,
      'kind': isDir ? 'directory' : 'file',
      if (!isDir) 'size': stat.size,
      'modified': stat.modified.millisecondsSinceEpoch,
    };
  }

  List<Map<String, dynamic>> list(List<String> segments) {
    final path = _checked(segments);
    final type = _type(path);
    if (type == FileSystemEntityType.notFound) {
      throw FileManagerException(errNotFound, '找不到資料夾');
    }
    if (type != FileSystemEntityType.directory) {
      throw const FileManagerException(errNotADirectory, '這不是資料夾');
    }
    final entries = Directory(path).listSync(followLinks: false).map((e) => _entry(p.basename(e.path), e)).toList();
    entries.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return entries;
  }

  Map<String, dynamic> stat(List<String> segments) {
    final path = _checked(segments);
    final type = _type(path);
    if (type == FileSystemEntityType.notFound) {
      return {'exists': false};
    }
    final stat = FileStat.statSync(path);
    final isDir = stat.type == FileSystemEntityType.directory;
    return {
      'exists': true,
      'kind': isDir ? 'directory' : 'file',
      if (!isDir) 'size': stat.size,
      'modified': stat.modified.millisecondsSinceEpoch,
    };
  }

  /// 讀取 [offset] 起至多 [length] 位元組（預設與上限皆為 [maxContentBytes]）。
  Map<String, dynamic> read(List<String> segments, {int offset = 0, int? length}) {
    if (offset < 0) {
      throw const FileManagerException(errInvalidPath, 'offset 不得為負數');
    }
    final wanted = length ?? maxContentBytes;
    if (wanted < 0 || wanted > maxContentBytes) {
      throw FileManagerException(errTooLarge, 'length 不得超過 $maxContentBytes');
    }
    final path = _checked(segments);
    final type = _type(path);
    if (type == FileSystemEntityType.notFound) {
      throw const FileManagerException(errNotFound, '找不到檔案');
    }
    if (type == FileSystemEntityType.directory) {
      throw const FileManagerException(errIsADirectory, '這是資料夾');
    }
    final file = File(path).openSync();
    try {
      final total = file.lengthSync();
      file.setPositionSync(offset > total ? total : offset);
      final data = file.readSync(wanted);
      return {'data': data, 'eof': offset + data.length >= total};
    } finally {
      file.closeSync();
    }
  }

  /// 讀取整個檔案；超過 [limit] 位元組回 `too_large`。供「存到下載」這類在 Dart 內完成、不經 bridge 的用途。
  Uint8List readAll(List<String> segments, int limit) {
    final path = _checked(segments);
    final type = _type(path);
    if (type == FileSystemEntityType.notFound) {
      throw const FileManagerException(errNotFound, '找不到檔案');
    }
    if (type == FileSystemEntityType.directory) {
      throw const FileManagerException(errIsADirectory, '這是資料夾');
    }
    final file = File(path);
    if (file.lengthSync() > limit) {
      throw FileManagerException(errTooLarge, '檔案超過 $limit 位元組');
    }
    return file.readAsBytesSync();
  }

  /// [mode]：`create`（已存在則失敗）、`overwrite`、`append`。回傳寫入後的檔案大小。
  int write(List<String> segments, Uint8List data, String mode) {
    if (!const {'create', 'overwrite', 'append'}.contains(mode)) {
      throw const FileManagerException(errInvalidPath, 'mode 必須是 create、overwrite 或 append');
    }
    if (data.length > maxContentBytes) {
      throw FileManagerException(errTooLarge, 'data 不得超過 $maxContentBytes 位元組');
    }
    if (segments.isEmpty) {
      throw const FileManagerException(errInvalidPath, '不能寫入根資料夾');
    }
    final path = _checked(segments);
    final parentType = _type(p.dirname(path));
    if (parentType == FileSystemEntityType.notFound) {
      throw const FileManagerException(errNotFound, '父資料夾不存在');
    }
    final type = _type(path);
    if (type == FileSystemEntityType.directory) {
      throw const FileManagerException(errIsADirectory, '目標是資料夾');
    }
    if (type != FileSystemEntityType.notFound && mode == 'create') {
      throw const FileManagerException(errAlreadyExists, '檔案已存在');
    }
    final file = File(path);
    file.writeAsBytesSync(data, mode: mode == 'append' ? FileMode.append : FileMode.write, flush: true);
    return file.lengthSync();
  }

  void makeDirectory(List<String> segments, {bool recursive = false}) {
    if (segments.isEmpty) {
      throw const FileManagerException(errAlreadyExists, '根資料夾已存在');
    }
    final path = _checked(segments);
    final type = _type(path);
    if (type == FileSystemEntityType.directory) {
      if (recursive) {
        return;
      }
      throw const FileManagerException(errAlreadyExists, '資料夾已存在');
    }
    if (type != FileSystemEntityType.notFound) {
      throw const FileManagerException(errAlreadyExists, '同名的檔案已存在');
    }
    if (!recursive && _type(p.dirname(path)) == FileSystemEntityType.notFound) {
      throw const FileManagerException(errNotFound, '父資料夾不存在');
    }
    Directory(path).createSync(recursive: recursive);
  }

  void copy(List<String> from, List<String> to, {bool overwrite = false}) {
    final source = _prepareTransfer(from, to, overwrite: overwrite);
    _copyEntity(source.$1, source.$2);
  }

  void move(List<String> from, List<String> to, {bool overwrite = false}) {
    final (src, dst) = _prepareTransfer(from, to, overwrite: overwrite);
    try {
      if (_type(src) == FileSystemEntityType.directory) {
        Directory(src).renameSync(dst);
      }
      else {
        File(src).renameSync(dst);
      }
    }
    on FileSystemException {
      // 跨磁碟區無法重新命名：改複製後刪除；複製失敗時來源仍在、目標不留一半
      try {
        _copyEntity(src, dst);
      }
      catch (_) {
        if (_type(dst) != FileSystemEntityType.notFound) {
          _deleteEntity(dst);
        }
        rethrow;
      }
      _deleteEntity(src);
    }
  }

  (String, String) _prepareTransfer(List<String> from, List<String> to, {required bool overwrite}) {
    if (from.isEmpty || to.isEmpty) {
      throw const FileManagerException(errInvalidPath, '來源與目標不能是根資料夾');
    }
    final src = _checked(from);
    final dst = _checked(to);
    if (_type(src) == FileSystemEntityType.notFound) {
      throw const FileManagerException(errNotFound, '找不到來源');
    }
    if (src == dst || p.isWithin(src, dst)) {
      throw const FileManagerException(errInvalidPath, '目標不能是來源本身或在來源之內');
    }
    if (_type(p.dirname(dst)) == FileSystemEntityType.notFound) {
      throw const FileManagerException(errNotFound, '目標的父資料夾不存在');
    }
    if (_type(dst) != FileSystemEntityType.notFound) {
      if (!overwrite) {
        throw const FileManagerException(errAlreadyExists, '目標已存在');
      }
      _deleteEntity(dst);
    }
    return (src, dst);
  }

  void _copyEntity(String src, String dst) {
    if (_type(src) == FileSystemEntityType.directory) {
      Directory(dst).createSync();
      for (final child in Directory(src).listSync(followLinks: false)) {
        _copyEntity(child.path, p.join(dst, p.basename(child.path)));
      }
    }
    else {
      File(src).copySync(dst);
    }
  }

  void _deleteEntity(String path) {
    if (_type(path) == FileSystemEntityType.directory) {
      Directory(path).deleteSync(recursive: true);
    }
    else {
      File(path).deleteSync();
    }
  }

  void delete(List<String> segments, {bool recursive = false}) {
    if (segments.isEmpty) {
      throw const FileManagerException(errInvalidPath, '不能刪除根資料夾');
    }
    final path = _checked(segments);
    final type = _type(path);
    if (type == FileSystemEntityType.notFound) {
      throw const FileManagerException(errNotFound, '找不到');
    }
    if (type == FileSystemEntityType.directory) {
      final isEmpty = Directory(path).listSync(followLinks: false).isEmpty;
      if (!isEmpty && !recursive) {
        throw const FileManagerException(errNotEmpty, '資料夾不是空的；要連同內容刪除請帶 recursive');
      }
      Directory(path).deleteSync(recursive: true);
      return;
    }
    // 檔案或符號連結本身；連結只刪連結，不跟進目標
    if (type == FileSystemEntityType.link) {
      Link(path).deleteSync();
      return;
    }
    File(path).deleteSync();
  }
}
