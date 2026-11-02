import 'dart:async';
import 'dart:typed_data';

/// 在一個根（資料夾）之內的檔案操作；路徑一律是已驗證的相對路徑段。
///
/// 桌面與 App 資料夾用 `dart:io`（同步完成），Android 的授權位置走 SAF（非同步），
/// 所以回傳型別是 [FutureOr]，呼叫端一律 `await`。錯誤一律以 `FileManagerException` 回報（契約 §3）。
abstract interface class FileOps {
  FutureOr<List<Map<String, dynamic>>> list(List<String> segments);

  FutureOr<Map<String, dynamic>> stat(List<String> segments);

  FutureOr<Map<String, dynamic>> read(List<String> segments, {int offset = 0, int? length});

  /// 讀取整個檔案；超過 [limit] 位元組回 `too_large`。
  FutureOr<Uint8List> readAll(List<String> segments, int limit);

  /// [mode]：`create`、`overwrite`、`append`；回傳寫入後的檔案大小。
  FutureOr<int> write(List<String> segments, Uint8List data, String mode);

  FutureOr<void> makeDirectory(List<String> segments, {bool recursive = false});

  FutureOr<void> copy(List<String> from, List<String> to, {bool overwrite = false});

  FutureOr<void> move(List<String> from, List<String> to, {bool overwrite = false});

  FutureOr<void> delete(List<String> segments, {bool recursive = false});
}
