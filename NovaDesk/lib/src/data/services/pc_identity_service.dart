import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../domain/entities/pc_identity.dart';
import '../../platform/app_logger.dart';
import '../../platform/app_paths.dart';

/// 管理 `config/pc.json` 读取与初始化。
class PcIdentityService {
  PcIdentityService._(this._impl);

  final PcIdentityServiceImpl _impl;

  static PcIdentityService defaultInstance() =>
      PcIdentityService._(PcIdentityServiceImpl());

  Future<PcIdentity> ensureLoaded() => _impl.ensureLoaded();

  PcIdentity get identity => _impl.identity;

  Future<void> updateLastLogin(DateTime timestamp) =>
      _impl.updateLastLogin(timestamp);
}

class PcIdentityServiceImpl {
  PcIdentityServiceImpl({
    AppPaths? appPaths,
    Uuid? uuid,
    String? clientVersion,
    AppLogger? logger,
  })  : _appPaths = appPaths ?? AppPaths(),
        _uuid = uuid ?? const Uuid(),
        _clientVersion = clientVersion ?? _defaultClientVersion,
        _logger = logger ?? AppLogger.defaultLogger();

  static const String _defaultClientVersion = '0.1.0';

  final AppPaths _appPaths;
  final Uuid _uuid;
  final String _clientVersion;
  final AppLogger _logger;

  PcIdentity? _identity;

  PcIdentity get identity {
    final PcIdentity? value = _identity;
    if (value == null) {
      throw StateError('PcIdentity has not been loaded yet.');
    }
    return value;
  }

  Future<PcIdentity> ensureLoaded() async {
    if (_identity != null) {
      return _identity!;
    }

    await _appPaths.ensureBaseDirectories();
    final File configFile = _appPaths.pcConfigFile;

    if (await configFile.exists()) {
      try {
        final PcIdentity existing = await _readIdentity(configFile);
        await _logger.info('Loaded existing pc identity ${existing.pcId}');
        _identity = existing;
        return existing;
      } on FormatException catch (_) {
        await _backupCorruptedFile(configFile);
        final PcIdentity regenerated = await _createFreshIdentity(configFile);
        _identity = regenerated;
        return regenerated;
      } on IOException catch (_) {
        await _backupCorruptedFile(configFile);
        final PcIdentity regenerated = await _createFreshIdentity(configFile);
        _identity = regenerated;
        return regenerated;
      }
    } else {
      final PcIdentity created = await _createFreshIdentity(configFile);
      _identity = created;
      return created;
    }
  }

  Future<void> updateLastLogin(DateTime timestamp) async {
    final PcIdentity current = await ensureLoaded();
    final PcIdentity updated = current.copyWith(lastLoginAt: timestamp.toUtc());
    await _writeIdentity(_appPaths.pcConfigFile, updated);
    await _logger.info('Updated lastLoginAt for ${updated.pcId}');
    _identity = updated;
  }

  Future<PcIdentity> _readIdentity(File configFile) async {
    final String content = await configFile.readAsString();
    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;
    return PcIdentity.fromJson(json);
  }

  Future<PcIdentity> _createFreshIdentity(File configFile) async {
    final DateTime now = DateTime.now().toUtc();
    final PcIdentity identity = PcIdentity(
      pcId: _buildPcId(),
      createdAt: now,
      lastLoginAt: now,
      clientVersion: _clientVersion,
    );
    await _writeIdentity(configFile, identity);
    await _logger.info('Generated new pc identity ${identity.pcId}');
    _identity = identity;
    return identity;
  }

  Future<void> _backupCorruptedFile(File configFile) async {
    if (!await configFile.exists()) {
      return;
    }
    final File backupFile = _appPaths.pcConfigBackupFile;
    await configFile.copy(backupFile.path);
    await _logger.warning('Backup corrupted pc.json to ${backupFile.path}');
  }

  Future<void> _writeIdentity(File configFile, PcIdentity identity) async {
    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(identity.toJson()),
    );
  }

  String _buildPcId() => 'PC-${_uuid.v4()}';
}
