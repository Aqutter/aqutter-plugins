import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart' show SafDocumentFile;

import 'file_ops.dart';
import 'location.dart';

/// SAF 裡的一個文件或資料夾。
class SafEntry {
  const SafEntry({required this.uri, required this.name, required this.isDir, required this.length, required this.modified});

  final String uri;
  final String name;
  final bool isDir;

  /// 位元組數；未知為 -1，資料夾沒有意義。
  final int length;

  /// Unix 毫秒。
  final int modified;
}

/// SAF 操作的薄介面：只放 [SafFileOps] 用到的幾個動作，測試以記憶體內的樹取代。
abstract interface class SafBackend {
  /// 開啟系統的資料夾選擇器並保存持久授權；取消回 null。
  Future<SafEntry?> pickDirectory();

  /// [treeUri] 底下以 [names] 逐層找到的文件；[names] 為空就是 [treeUri] 本身；不存在回 null。
  Future<SafEntry?> child(String treeUri, List<String> names);

  Future<List<SafEntry>> list(String dirUri);

  /// 逐層建立資料夾（已存在的略過），回傳最後一層。
  Future<SafEntry> mkdirp(String treeUri, List<String> names);

  Future<void> delete(String uri, bool isDir);

  Future<SafEntry> rename(String uri, bool isDir, String newName);

  Future<SafEntry> moveTo(String uri, bool isDir, String parentUri, String newParentUri);

  Future<SafEntry> copyTo(String uri, bool isDir, String newParentUri);

  Future<Uint8List> read(String uri, {int? start, int? count});

  /// 在 [parentUri] 底下寫入 [name]；[overwrite] 取代既有內容，[append] 接在既有內容之後。
  Future<SafEntry> write(String parentUri, String name, String mime, Uint8List data, {bool overwrite = false, bool append = false});
}

SafEntry _entryOf(SafDocumentFile file) => SafEntry(uri: file.uri, name: file.name, isDir: file.isDir, length: file.length, modified: file.lastModified);

/// 以 `saf_util`、`saf_stream` 實作（Android）。
class PlatformSafBackend implements SafBackend {
  PlatformSafBackend({SafUtil? util, SafStream? stream})
      : _util = util ?? SafUtil(),
        _stream = stream ?? SafStream();

  final SafUtil _util;
  final SafStream _stream;

  @override
  Future<SafEntry?> pickDirectory() async {
    final picked = await _util.pickDirectory(writePermission: true, persistablePermission: true);
    return picked == null ? null : _entryOf(picked);
  }

  @override
  Future<SafEntry?> child(String treeUri, List<String> names) async {
    final found = names.isEmpty ? await _util.documentFileFromUri(treeUri, true) : await _util.child(treeUri, names);
    return found == null ? null : _entryOf(found);
  }

  @override
  Future<List<SafEntry>> list(String dirUri) async => (await _util.list(dirUri)).map(_entryOf).toList();

  @override
  Future<SafEntry> mkdirp(String treeUri, List<String> names) async => _entryOf(await _util.mkdirp(treeUri, names));

  @override
  Future<void> delete(String uri, bool isDir) => _util.delete(uri, isDir);

  @override
  Future<SafEntry> rename(String uri, bool isDir, String newName) async => _entryOf(await _util.rename(uri, isDir, newName));

  @override
  Future<SafEntry> moveTo(String uri, bool isDir, String parentUri, String newParentUri) async {
    return _entryOf(await _util.moveTo(uri, isDir, parentUri, newParentUri));
  }

  @override
  Future<SafEntry> copyTo(String uri, bool isDir, String newParentUri) async => _entryOf(await _util.copyTo(uri, isDir, newParentUri));

  @override
  Future<Uint8List> read(String uri, {int? start, int? count}) => _stream.readFileBytes(uri, start: start, count: count);

  @override
  Future<SafEntry> write(String parentUri, String name, String mime, Uint8List data, {bool overwrite = false, bool append = false}) async {
    final written = await _stream.writeFileBytes(parentUri, name, mime, data, overwrite: overwrite, append: append);
    final stat = await _util.stat(written.uri.toString(), false);
    if (stat == null) {
      throw const FileManagerException(errNotFound, '寫入後找不到檔案');
    }
    return _entryOf(stat);
  }
}

/// 一個已授權的資料夾樹（[treeUri]）之內的檔案操作；與 `LocalFileOps` 同一個介面與同一組錯誤碼。
///
/// SAF 以文件編號而不是路徑定址，名稱段已由 `parseLocation` 驗證為單純的名稱，沒有 `..` 可跳出樹外。
class SafFileOps implements FileOps {
  SafFileOps(this.treeUri, this._backend);

  final String treeUri;
  final SafBackend _backend;

  Map<String, dynamic> _publicEntry(SafEntry entry) => {
        'name': entry.name,
        'kind': entry.isDir ? 'directory' : 'file',
        if (!entry.isDir && entry.length >= 0) 'size': entry.length,
        'modified': entry.modified,
      };

  Future<SafEntry?> _find(List<String> segments) => _backend.child(treeUri, segments);

  Future<SafEntry> _existing(List<String> segments, String missing) async {
    final entry = await _find(segments);
    if (entry == null) {
      throw FileManagerException(errNotFound, missing);
    }
    return entry;
  }

  Future<SafEntry> _file(List<String> segments) async {
    final entry = await _existing(segments, '找不到檔案');
    if (entry.isDir) {
      throw const FileManagerException(errIsADirectory, '這是資料夾');
    }
    return entry;
  }

  @override
  Future<List<Map<String, dynamic>>> list(List<String> segments) async {
    final dir = await _existing(segments, '找不到資料夾');
    if (!dir.isDir) {
      throw const FileManagerException(errNotADirectory, '這不是資料夾');
    }
    final entries = (await _backend.list(dir.uri)).map(_publicEntry).toList();
    entries.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return entries;
  }

  @override
  Future<Map<String, dynamic>> stat(List<String> segments) async {
    final entry = await _find(segments);
    if (entry == null) {
      return {'exists': false};
    }
    return {'exists': true, ..._publicEntry(entry)..remove('name')};
  }

  @override
  Future<Map<String, dynamic>> read(List<String> segments, {int offset = 0, int? length}) async {
    if (offset < 0) {
      throw const FileManagerException(errInvalidPath, 'offset 不得為負數');
    }
    final wanted = length ?? maxContentBytes;
    if (wanted < 0 || wanted > maxContentBytes) {
      throw FileManagerException(errTooLarge, 'length 不得超過 $maxContentBytes');
    }
    final file = await _file(segments);
    if (file.length >= 0 && offset >= file.length) {
      return {'data': Uint8List(0), 'eof': true};
    }
    final data = await _backend.read(file.uri, start: offset, count: wanted);
    final eof = file.length >= 0 ? offset + data.length >= file.length : data.length < wanted;
    return {'data': data, 'eof': eof};
  }

  @override
  Future<Uint8List> readAll(List<String> segments, int limit) async {
    final file = await _file(segments);
    if (file.length > limit) {
      throw FileManagerException(errTooLarge, '檔案超過 $limit 位元組');
    }
    final data = await _backend.read(file.uri);
    if (data.length > limit) {
      throw FileManagerException(errTooLarge, '檔案超過 $limit 位元組');
    }
    return data;
  }

  @override
  Future<int> write(List<String> segments, Uint8List data, String mode) async {
    if (!const {'create', 'overwrite', 'append'}.contains(mode)) {
      throw const FileManagerException(errInvalidPath, 'mode 必須是 create、overwrite 或 append');
    }
    if (data.length > maxContentBytes) {
      throw FileManagerException(errTooLarge, 'data 不得超過 $maxContentBytes 位元組');
    }
    if (segments.isEmpty) {
      throw const FileManagerException(errInvalidPath, '不能寫入根資料夾');
    }
    final parent = await _existing(segments.sublist(0, segments.length - 1), '父資料夾不存在');
    if (!parent.isDir) {
      throw const FileManagerException(errNotADirectory, '父路徑不是資料夾');
    }
    final name = segments.last;
    final existing = await _find(segments);
    if (existing != null && existing.isDir) {
      throw const FileManagerException(errIsADirectory, '目標是資料夾');
    }
    if (existing != null && mode == 'create') {
      throw const FileManagerException(errAlreadyExists, '檔案已存在');
    }
    final written = await _backend.write(
      parent.uri,
      name,
      lookupMimeType(name) ?? 'application/octet-stream',
      data,
      overwrite: mode == 'overwrite',
      append: mode == 'append',
    );
    return written.length;
  }

  @override
  Future<void> makeDirectory(List<String> segments, {bool recursive = false}) async {
    if (segments.isEmpty) {
      throw const FileManagerException(errAlreadyExists, '根資料夾已存在');
    }
    final existing = await _find(segments);
    if (existing != null) {
      if (existing.isDir && recursive) {
        return;
      }
      throw FileManagerException(errAlreadyExists, existing.isDir ? '資料夾已存在' : '同名的檔案已存在');
    }
    if (!recursive) {
      final parent = await _existing(segments.sublist(0, segments.length - 1), '父資料夾不存在');
      if (!parent.isDir) {
        throw const FileManagerException(errNotADirectory, '父路徑不是資料夾');
      }
    }
    await _backend.mkdirp(treeUri, segments);
  }

  /// 搬移與複製共用的前置檢查：回傳來源、目標的父資料夾；目標已存在且允許覆蓋時先刪除。
  Future<(SafEntry source, SafEntry sourceParent, SafEntry targetParent)> _prepareTransfer(
    List<String> from,
    List<String> to, {
    required bool overwrite,
    required bool isMove,
  }) async {
    if (from.isEmpty || to.isEmpty) {
      throw const FileManagerException(errInvalidPath, '來源與目標不能是根資料夾');
    }
    final source = await _existing(from, '找不到來源');
    if (_isSameOrInside(from, to)) {
      throw const FileManagerException(errInvalidPath, '目標不能是來源本身或在來源之內');
    }
    final sourceParent = await _existing(from.sublist(0, from.length - 1), '找不到來源的父資料夾');
    final targetParent = await _existing(to.sublist(0, to.length - 1), '目標的父資料夾不存在');
    if (!targetParent.isDir) {
      throw const FileManagerException(errNotADirectory, '目標的父路徑不是資料夾');
    }
    final destination = await _find(to);
    if (destination != null) {
      if (!overwrite) {
        throw const FileManagerException(errAlreadyExists, '目標已存在');
      }
      await _backend.delete(destination.uri, destination.isDir);
    }
    // SAF 的搬移保留原名再改名：搬到另一個資料夾且改名時，目標資料夾裡若已有與來源同名的其他項目就無法安全進行
    if (isMove && sourceParent.uri != targetParent.uri && from.last != to.last) {
      final clash = await _find([...to.sublist(0, to.length - 1), from.last]);
      if (clash != null) {
        throw const FileManagerException(errAlreadyExists, '目標資料夾裡已有與來源同名的項目；請先改名或改用複製加刪除');
      }
    }
    return (source, sourceParent, targetParent);
  }

  bool _isSameOrInside(List<String> source, List<String> target) {
    if (target.length < source.length) {
      return false;
    }
    for (var i = 0; i < source.length; i++) {
      if (source[i] != target[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<void> copy(List<String> from, List<String> to, {bool overwrite = false}) async {
    final (source, _, targetParent) = await _prepareTransfer(from, to, overwrite: overwrite, isMove: false);
    final copied = await _backend.copyTo(source.uri, source.isDir, targetParent.uri);
    if (copied.name != to.last) {
      await _backend.rename(copied.uri, copied.isDir, to.last);
    }
  }

  @override
  Future<void> move(List<String> from, List<String> to, {bool overwrite = false}) async {
    final (source, sourceParent, targetParent) = await _prepareTransfer(from, to, overwrite: overwrite, isMove: true);
    if (sourceParent.uri == targetParent.uri) {
      if (from.last != to.last) {
        await _backend.rename(source.uri, source.isDir, to.last);
      }
      return;
    }
    final moved = await _backend.moveTo(source.uri, source.isDir, sourceParent.uri, targetParent.uri);
    if (moved.name != to.last) {
      await _backend.rename(moved.uri, moved.isDir, to.last);
    }
  }

  @override
  Future<void> delete(List<String> segments, {bool recursive = false}) async {
    if (segments.isEmpty) {
      throw const FileManagerException(errInvalidPath, '不能刪除根資料夾');
    }
    final entry = await _existing(segments, '找不到');
    if (entry.isDir && !recursive && (await _backend.list(entry.uri)).isNotEmpty) {
      throw const FileManagerException(errNotEmpty, '資料夾不是空的；要連同內容刪除請帶 recursive');
    }
    await _backend.delete(entry.uri, entry.isDir);
  }
}
