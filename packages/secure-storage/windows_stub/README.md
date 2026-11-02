# Windows 替身（flutter_secure_storage_windows）

`flutter_secure_storage` 的 Windows 實作需要 ATL（`atlstr.h`）才能編譯。`aqutter-plugin-secure-storage` 在 Windows **不支援**，
所以用這個沒有原生程式碼的替身取代它，Windows 建置就不需要安裝 ATL。

在 App 的 `pubspec.yaml`（只有 App 的 `dependency_overrides` 會生效）加上：

```yaml
dependency_overrides:
  flutter_secure_storage_windows:
    path: ../node_modules/aqutter-plugin-secure-storage/windows_stub
```

沒有加這段覆寫的 App 在 Windows 上建置會因為缺少 ATL 失敗。其他平台不受影響。
