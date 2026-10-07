import 'package:flutter/services.dart';

/// Jembatan ke kode native Android (Kotlin).
class SakuChannel {
  static final MethodChannel folder = const MethodChannel('saku/folder');
  static final MethodChannel apps = const MethodChannel('saku/apps');
  static final MethodChannel widget = const MethodChannel('saku/widget');
  static final EventChannel notifStream = const EventChannel('saku/notifs');

  static Future<bool> pickFolder() async {
    try {
      final ok = await folder.invokeMethod<bool>('pick') ?? false;
      return ok;
    } on PlatformException {
      return false;
    }
  }

  static Future<String?> folderName() async =>
      folder.invokeMethod<String>('name');

  static Future<bool> folderReady() async {
    try {
      return await folder.invokeMethod<bool>('ready') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> ensureFiles() async {
    try {
      return await folder.invokeMethod<bool>('ensure') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<String?> readFile(String name) async {
    try {
      return await folder.invokeMethod<String>('read', {'name': name});
    } on PlatformException {
      return null;
    }
  }

  static Future<bool> writeFile(String name, String content) async {
    try {
      return await folder.invokeMethod<bool>('write', {'name': name, 'content': content}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> exists(String name) async {
    try {
      return await folder.invokeMethod<bool>('exists', {'name': name}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> appendCsv(String name, String line) async {
    try {
      return await folder.invokeMethod<bool>('appendCsv', {'name': name, 'content': line}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Daftar aplikasi yang bisa dipilih untuk tombol notifikasi.
  static Future<List<Map<String, String>>> listInstalledApps() async {
    try {
      final raw = await apps.invokeMethod<List<dynamic>>('list');
      return (raw ?? [])
          .map((e) => (e as Map).cast<String, Object>())
          .map((m) => <String, String>{
                'package': m['package']?.toString() ?? '',
                'label': m['label']?.toString() ?? '',
              })
          .toList();
    } on PlatformException {
      return <Map<String, String>>[];
    }
  }

  static Future<bool> notifAccessGranted() async {
    try {
      return await apps.invokeMethod<bool>('notifAccess') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openNotifAccessSettings() async {
    try {
      await apps.invokeMethod<void>('openNotifSettings');
    } on PlatformException {
      // abaikan
    }
  }

  static Future<void> sendTestNotification() async {
    try {
      await apps.invokeMethod<void>('testNotif');
    } on PlatformException {
      // abaikan
    }
  }

  /// Whitelist app untuk pembaca notifikasi (disimpan native biar listener bisa akses).
  static Future<List<String>> getWhitelist() async {
    try {
      final raw = await apps.invokeMethod<List<dynamic>>('getWhitelist') ?? <dynamic>[];
      return raw.map((e) => e.toString()).toList();
    } on PlatformException {
      return <String>[];
    }
  }

  static Future<void> setWhitelist(List<String> packages) async {
    try {
      await apps.invokeMethod<void>('setWhitelist', {'packages': packages});
    } on PlatformException {
      // abaikan
    }
  }

  static Future<void> updateWidget(int totalToday) async {
    try {
      await widget.invokeMethod<void>('update', {'totalToday': totalToday});
    } on PlatformException {
      // abaikan
    }
  }
}
