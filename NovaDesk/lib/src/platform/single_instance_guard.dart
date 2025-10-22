import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_logger.dart';
import 'app_paths.dart';

/// 控制桌面客户端仅允许单实例运行的守护。
class SingleInstanceGuard {
  SingleInstanceGuard._(this._impl);

  final SingleInstanceGuardImpl _impl;

  static SingleInstanceGuard defaultInstance() =>
      SingleInstanceGuard._(SingleInstanceGuardImpl());

  /// 获取单实例锁，无法获取时抛出 [SingleInstanceAlreadyRunningException]。
  Future<SingleInstanceGuardHandle> acquire() => _impl.acquire();
}

class SingleInstanceGuardImpl {
  SingleInstanceGuardImpl({AppPaths? appPaths, AppLogger? logger})
      : _appPaths = appPaths ?? AppPaths(),
        _logger = logger ?? AppLogger.defaultLogger();

  final AppPaths _appPaths;
  final AppLogger _logger;
  static final Set<String> _lockedPaths = <String>{};

  SingleInstanceGuardHandle? _activeHandle;

  Future<SingleInstanceGuardHandle> acquire() async {
    if (_activeHandle != null) {
      // 已经获取过锁，直接复用。
      return _activeHandle!;
    }

    await _appPaths.ensureBaseDirectories();
    final File lockFile = _appPaths.lockFile;
    if (_lockedPaths.contains(lockFile.path)) {
      throw SingleInstanceAlreadyRunningException(
        lockFile.path,
        cause: 'locked-by-same-process',
      );
    }
    final RandomAccessFile raf = await lockFile.open(mode: FileMode.write);

    try {
      await raf.lock(FileLock.exclusive);
      final String payload = _buildLockPayload();
      await raf.setPosition(0);
      await raf.truncate(0);
      await raf.writeString(payload);
      await _logger.info(
        'Acquire lock succeeded at ${lockFile.path} with payload: ${payload.replaceAll('\n', '; ')}',
      );
    } on FileSystemException catch (error) {
      await raf.close();
      if (_isAlreadyLockedError(error)) {
        await _logger
            .warning('Lock file already in use: ${lockFile.path} (${error.osError?.message})');
        throw SingleInstanceAlreadyRunningException(lockFile.path, cause: error);
      }
      await _logger.error('Failed to acquire lock ${lockFile.path}', cause: error);
      rethrow;
    }

    final SingleInstanceGuardHandle handle = SingleInstanceGuardHandle._(
      randomAccessFile: raf,
      lockFile: lockFile,
      logger: _logger,
    );
    _lockedPaths.add(lockFile.path);
    _activeHandle = handle;
    handle.onRelease = () {
      _lockedPaths.remove(lockFile.path);
      _activeHandle = null;
    };
    return handle;
  }

  String _buildLockPayload() {
    final int pid = pidCurrent;
    final String timestamp = DateTime.now().toUtc().toIso8601String();
    return 'pid=$pid\nstartedAt=$timestamp\npath=${p.normalize(Directory.current.path)}';
  }

  bool _isAlreadyLockedError(FileSystemException error) {
    final String message = error.osError?.message.toLowerCase() ?? error.message.toLowerCase();
    return message.contains('resource temporarily unavailable') ||
        message.contains('another process') ||
        message.contains('locked') ||
        message.contains('permission denied');
  }
}

/// 锁句柄，负责在进程退出或需要时释放锁。
class SingleInstanceGuardHandle {
  SingleInstanceGuardHandle._({
    required RandomAccessFile randomAccessFile,
    required File lockFile,
    required AppLogger logger,
  })  : _randomAccessFile = randomAccessFile,
        _lockFile = lockFile,
        _logger = logger;

  final RandomAccessFile _randomAccessFile;
  final File _lockFile;
  final AppLogger _logger;
  bool _released = false;
  void Function()? onRelease;

  Future<void> release() async {
    if (_released) {
      return;
    }
    try {
      await _randomAccessFile.unlock();
    } finally {
      await _randomAccessFile.close();
      if (await _lockFile.exists()) {
        await _lockFile.delete();
      }
      await _logger.info('Lock released and file deleted: ${_lockFile.path}');
      _released = true;
      onRelease?.call();
    }
  }
}

/// 锁已被占用时抛出的异常。
class SingleInstanceAlreadyRunningException implements Exception {
  SingleInstanceAlreadyRunningException(this.lockFilePath, {this.cause});

  final String lockFilePath;
  final Object? cause;

  @override
  String toString() =>
      'SingleInstanceAlreadyRunningException: lock file $lockFilePath already in use (${cause ?? 'unknown cause'})';
}

int get pidCurrent => pid;
