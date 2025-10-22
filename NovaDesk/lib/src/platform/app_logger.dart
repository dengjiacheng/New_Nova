import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_paths.dart';

/// 最简版的本地文件日志，用于启动阶段关键事件记录。
class AppLogger {
  AppLogger({AppPaths? appPaths}) : _appPaths = appPaths ?? AppPaths();

  final AppPaths _appPaths;

  static AppLogger? _default;

  static AppLogger defaultLogger() {
    return _default ??= AppLogger();
  }

  Future<void> info(String message) => _write('INFO', message);

  Future<void> warning(String message) => _write('WARN', message);

  Future<void> error(String message, {Object? cause}) =>
      _write('ERROR', cause != null ? '$message | cause=$cause' : message);

  Future<void> _write(String level, String message) async {
    await _appPaths.ensureBaseDirectories();
    final File logFile = File(p.join(_appPaths.logsDir.path, 'app.log'));
    final IOSink sink = logFile.openWrite(mode: FileMode.append);
    final String timestamp = DateTime.now().toUtc().toIso8601String();
    sink.writeln('[$timestamp][$level] $message');
    await sink.flush();
    await sink.close();
  }
}
