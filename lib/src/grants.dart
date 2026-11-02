import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'location.dart';

/// 使用者授權的一個位置：一個資料夾（[kind] `directory`）或單一檔案（`file`）。
///
/// [path] 是桌面平台的實際路徑；它只存在這個 plugin 內，不會交給網頁，網頁只看到 [id]。
class Grant {
  const Grant({required this.id, required this.name, required this.kind, required this.path});

  factory Grant.fromJson(Map<String, dynamic> json) => Grant(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: json['kind'] as String,
        path: json['path'] as String,
      );

  final String id;
  final String name;
  final String kind;
  final String path;

  bool get isDirectory => kind == 'directory';

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'kind': kind, 'path': path};

  /// 回給網頁的樣子：沒有實際路徑。
  Map<String, dynamic> toPublic() => {'id': id, 'name': name, 'kind': kind};
}

/// 授權清單的持久化；測試可注入。
abstract class GrantStore {
  Future<List<Grant>> load();

  Future<void> save(List<Grant> grants);
}

/// 存在 `shared_preferences`：不在 App 資料夾裡，網頁無法經由 sandbox 位置讀寫它。
class PreferencesGrantStore implements GrantStore {
  static const String _key = 'aqutter.file-manager.grants';

  @override
  Future<List<Grant>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) {
      return [];
    }
    try {
      return (jsonDecode(raw) as List<dynamic>).map((item) => Grant.fromJson(item as Map<String, dynamic>)).toList();
    }
    catch (_) {
      return []; // 壞掉的紀錄視為沒有授權，網頁重新授權即可
    }
  }

  @override
  Future<void> save(List<Grant> grants) async {
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(grants.map((g) => g.toJson()).toList()));
  }
}

/// 使用者選到的項目。
class PickedItem {
  const PickedItem({required this.name, required this.path, required this.isDirectory});

  final String name;
  final String path;
  final bool isDirectory;
}

/// 開啟系統的選擇器；測試可注入。取消回空清單。
abstract class GrantPicker {
  Future<List<PickedItem>> pick(String kind);
}

/// 以 `file_picker` 實作（桌面平台：選到的就是實際路徑）。
class FilePickerGrantPicker implements GrantPicker {
  @override
  Future<List<PickedItem>> pick(String kind) async {
    if (kind == 'directory') {
      final dir = await FilePicker.getDirectoryPath();
      return dir == null ? [] : [PickedItem(name: p.basename(dir), path: dir, isDirectory: true)];
    }
    final files = kind == 'file' ? [await FilePicker.pickFile()].whereType<PlatformFile>().toList() : await FilePicker.pickFiles();
    return [
      for (final file in files)
        if (file.path != null) PickedItem(name: file.name, path: file.path!, isDirectory: false),
    ];
  }
}

/// 授權清單的操作：新增、列出、撤銷、解析。
class GrantManager {
  GrantManager({GrantStore? store, GrantPicker? picker, Random? random})
      : _store = store ?? PreferencesGrantStore(),
        _picker = picker ?? FilePickerGrantPicker(),
        _random = random ?? Random.secure();

  final GrantStore _store;
  final GrantPicker _picker;
  final Random _random;

  static const List<String> kinds = ['file', 'files', 'directory'];

  String _newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(12, (_) => alphabet[_random.nextInt(alphabet.length)]).join();
  }

  Future<List<Grant>> list() => _store.load();

  /// 開啟選擇器並登記使用者選的項目；取消回空清單。同一個路徑重複選取沿用原來的授權編號。
  Future<List<Grant>> grant(Object? kind) async {
    if (kind is! String || !kinds.contains(kind)) {
      throw FileManagerException(errInvalidPath, 'kind 必須是 ${kinds.join('、')} 之一');
    }
    final picked = await _picker.pick(kind);
    if (picked.isEmpty) {
      return [];
    }
    final all = await _store.load();
    final result = <Grant>[];
    for (final item in picked) {
      final existing = all.where((g) => g.path == item.path && g.isDirectory == item.isDirectory).firstOrNull;
      if (existing != null) {
        result.add(existing);
        continue;
      }
      final created = Grant(id: _newId(), name: item.name, kind: item.isDirectory ? 'directory' : 'file', path: item.path);
      all.add(created);
      result.add(created);
    }
    await _store.save(all);
    return result;
  }

  Future<void> revoke(Object? id) async {
    if (id is! String) {
      throw const FileManagerException(errInvalidPath, 'id 必須是字串');
    }
    final all = await _store.load();
    if (!all.any((g) => g.id == id)) {
      throw const FileManagerException(errNotFound, '沒有這個授權');
    }
    await _store.save(all.where((g) => g.id != id).toList());
  }

  /// 找出授權並確認它還有效（路徑還在、型別沒變）；失效回 `permission_denied`。
  Future<Grant> resolve(String id) async {
    final grant = (await _store.load()).where((g) => g.id == id).firstOrNull;
    if (grant == null) {
      throw FileManagerException(errNotFound, '沒有授權「$id」');
    }
    final type = FileSystemEntity.typeSync(grant.path);
    final valid = grant.isDirectory ? type == FileSystemEntityType.directory : type == FileSystemEntityType.file;
    if (!valid) {
      throw const FileManagerException(errPermissionDenied, '授權的位置已不存在或已改變，請重新授權');
    }
    return grant;
  }
}
