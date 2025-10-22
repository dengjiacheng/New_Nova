import 'dart:io';

import 'package:path/path.dart' as p;

/// 管理 NovaDesk 运行时所需的本地目录与文件路径。
class AppPaths {
  AppPaths({Directory? root}) : _root = root ?? Directory.current;

  final Directory _root;

  Directory get configDir => Directory(p.join(_root.path, 'config'));
  Directory get logsDir => Directory(p.join(_root.path, 'logs'));
  Directory get cacheDir => Directory(p.join(_root.path, 'cache'));
  Directory get templatesDir => Directory(p.join(_root.path, 'templates'));

  File get pcConfigFile => File(p.join(configDir.path, 'pc.json'));
  File get pcConfigBackupFile {
    final String timestamp =
        DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    return File(p.join(configDir.path, 'pc.json.bak-$timestamp'));
  }
  File get lockFile => File(p.join(configDir.path, '.nova_desk.lock'));

  Future<void> ensureBaseDirectories() async {
    await Future.wait([
      _ensureDirectory(configDir),
      _ensureDirectory(logsDir),
      _ensureDirectory(cacheDir),
      _ensureDirectory(templatesDir),
    ]);
  }

  Future<void> _ensureDirectory(Directory directory) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }
}
