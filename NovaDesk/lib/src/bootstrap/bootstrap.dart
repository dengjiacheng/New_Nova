import 'dart:async';
import 'dart:io';

import 'package:nova_desk/src/application/events/app_event_bus.dart';
import 'package:nova_desk/src/application/events/device_event_bus.dart';
import 'package:nova_desk/src/application/services/agent_package_manager.dart';
import 'package:nova_desk/src/application/services/device_merge_service.dart';
import 'package:nova_desk/src/application/services/device_sync_coordinator.dart';
import 'package:nova_desk/src/application/services/execution_asset_service.dart';
import 'package:nova_desk/src/application/services/template_service.dart';
import 'package:nova_desk/src/data/api/api_client.dart';
import 'package:nova_desk/src/data/api/api_config.dart';
import 'package:nova_desk/src/data/clients/admin_package_api_client.dart';
import 'package:nova_desk/src/data/clients/asset_api_client.dart';
import 'package:nova_desk/src/data/clients/device_api_client.dart';
import 'package:nova_desk/src/data/repositories/device_repository.dart';
import 'package:nova_desk/src/data/repositories/template_repository.dart';
import 'package:nova_desk/src/data/services/pc_identity_service.dart';
import 'package:nova_desk/src/data/services/pc_websocket_service.dart';
import 'package:nova_desk/src/domain/ports/device_event_sink.dart';
import 'package:nova_desk/src/platform/adb/adb_service.dart';
import 'package:nova_desk/src/platform/app_logger.dart';
import 'package:nova_desk/src/platform/single_instance_guard.dart';

/// 负责启动期的核心流程协调。
class Bootstrap {
  factory Bootstrap({
    SingleInstanceGuard? singleInstanceGuard,
    PcIdentityService? pcIdentityService,
    AppLogger? logger,
    AppEventBus? eventBus,
    DeviceEventSink? deviceEventSink,
    PcWebSocketService? pcWebSocketService,
    AdbService? adbService,
    DeviceApiClient? deviceApiClient,
    TemplateRepository? templateRepository,
    ApiClient? apiClient,
    ApiConfig? apiConfig,
    AssetApiClient? assetApiClient,
    DeviceRepository? deviceRepository,
  }) {
    final AppLogger resolvedLogger = logger ?? AppLogger.defaultLogger();
    final ApiConfig resolvedConfig = apiConfig ?? ApiConfig.fromBaseUrl(ApiClient.defaultBaseUrl);
    final ApiClient resolvedApiClient = apiClient ?? ApiClient(config: resolvedConfig);
    final DeviceApiClient resolvedDeviceApiClient = deviceApiClient ??
        HttpDeviceApiClient(apiClient: resolvedApiClient, logger: resolvedLogger);
    final AssetApiClient resolvedAssetApiClient =
        assetApiClient ?? HttpAssetApiClient(apiClient: resolvedApiClient, logger: resolvedLogger);
    final DeviceRepository resolvedDeviceRepository =
        deviceRepository ?? DeviceRepository(logger: resolvedLogger);
    return Bootstrap._(
      singleInstanceGuard: singleInstanceGuard ?? SingleInstanceGuard.defaultInstance(),
      pcIdentityService: pcIdentityService ?? PcIdentityService.defaultInstance(),
      logger: resolvedLogger,
      eventBus: eventBus ?? AppEventBus(),
      deviceEventSink: deviceEventSink,
      pcWebSocketService: pcWebSocketService,
      adbService: adbService ?? ProcessAdbService(logger: resolvedLogger),
      deviceApiClient: resolvedDeviceApiClient,
      templateRepository: templateRepository ?? TemplateRepository(logger: resolvedLogger),
      deviceRepository: resolvedDeviceRepository,
      apiClient: resolvedApiClient,
      apiConfig: resolvedConfig,
      assetApiClient: resolvedAssetApiClient,
    );
  }

  Bootstrap._({
    required SingleInstanceGuard singleInstanceGuard,
    required PcIdentityService pcIdentityService,
    required AppLogger logger,
    required AppEventBus eventBus,
    DeviceEventSink? deviceEventSink,
    PcWebSocketService? pcWebSocketService,
    required AdbService adbService,
    required DeviceApiClient deviceApiClient,
    required TemplateRepository templateRepository,
    required DeviceRepository deviceRepository,
    required ApiClient apiClient,
    required ApiConfig apiConfig,
    required AssetApiClient assetApiClient,
  })  : _singleInstanceGuard = singleInstanceGuard,
        _pcIdentityService = pcIdentityService,
        _logger = logger,
        _eventBus = eventBus,
        _deviceEvents = deviceEventSink ?? DeviceEventBus(),
        _apiClient = apiClient,
        _apiConfig = apiConfig,
        _adbService = adbService,
        _deviceApiClient = deviceApiClient,
        _templateRepository = templateRepository,
        _deviceRepository = deviceRepository,
        _assetApiClient = assetApiClient {
    _pcWebSocketService =
        pcWebSocketService ??
            PcWebSocketService(
              eventBus: _eventBus,
              deviceEvents: _deviceEvents,
              logger: _logger,
            );
  }

  SingleInstanceGuardHandle? _guardHandle;
  final SingleInstanceGuard _singleInstanceGuard;
  final PcIdentityService _pcIdentityService;
  final AppLogger _logger;
  final AppEventBus _eventBus;
  final DeviceEventSink _deviceEvents;
  late final PcWebSocketService _pcWebSocketService;
  final ApiConfig _apiConfig;
  final ApiClient _apiClient;
  final AdbService _adbService;
  final DeviceApiClient _deviceApiClient;
  final TemplateRepository _templateRepository;
  final DeviceRepository _deviceRepository;
  final AssetApiClient _assetApiClient;
  DeviceMergeService? _deviceMergeService;
  DeviceSyncCoordinator? _deviceSyncCoordinator;
  TemplateService? _templateService;
  ExecutionAssetService? _executionAssetService;
  AgentPackageManager? _agentPackageManager;
  bool _servicesStarted = false;
  final List<StreamSubscription<ProcessSignal>> _signalSubscriptions = <StreamSubscription<ProcessSignal>>[];

  AppEventBus get eventBus => _eventBus;
  DeviceEventSink get deviceEventSink => _deviceEvents;
  PcIdentityService get pcIdentityService => _pcIdentityService;
  PcWebSocketService get pcWebSocketService => _pcWebSocketService;
  AppLogger get logger => _logger;
  ApiClient get apiClient => _apiClient;
  DeviceSyncCoordinator? get deviceSyncCoordinator => _deviceSyncCoordinator;
  TemplateRepository get templateRepository => _templateRepository;
  TemplateService get templateService =>
      _templateService ??= TemplateService(repository: _templateRepository);
  ExecutionAssetService get executionAssetService =>
      _executionAssetService ??=
          ExecutionAssetService(assetApiClient: _assetApiClient, logger: _logger);
  DeviceRepository get deviceRepository => _deviceRepository;
  AgentPackageManager get agentPackageManager =>
      _agentPackageManager ??=
          AgentPackageManager(
            adminClient: AdminPackageApiClient(_apiClient),
            apiClient: _apiClient,
            adbService: _adbService,
            logger: _logger,
          );

  Future<void> connectWebSocket(Uri uri, {Iterable<String>? protocols, Map<String, dynamic>? headers}) {
    return _pcWebSocketService.connect(uri, protocols: protocols, headers: headers);
  }

  /// 执行启动阶段的准备工作。
  Future<void> initialize() async {
    await _logger.info('Bootstrap initialize start');
    _guardHandle = await _singleInstanceGuard.acquire();
    _registerSignalHandlers();
    final identity = await _pcIdentityService.ensureLoaded();
    await _logger.info('Loaded pc identity ${identity.pcId}');
    await _deviceRepository.load();
    _deviceMergeService ??= DeviceMergeService(pcId: identity.pcId);
    _deviceSyncCoordinator ??= DeviceSyncCoordinator(
      adbService: _adbService,
      deviceApiClient: _deviceApiClient,
      mergeService: _deviceMergeService!,
      deviceEvents: _deviceEvents,
      deviceRepository: _deviceRepository,
      logger: _logger,
    );
  }

  /// 释放持有的资源（主要用于集成测试或优雅退出）。
  Future<void> dispose() async {
    await _logger.info('Bootstrap dispose start');
    for (final StreamSubscription<ProcessSignal> subscription in _signalSubscriptions) {
      await subscription.cancel();
    }
    _signalSubscriptions.clear();
    await _deviceSyncCoordinator?.dispose();
    await _pcWebSocketService.dispose();
    await _eventBus.dispose();
    await _deviceEvents.dispose();
    await _guardHandle?.release();
  }

  Future<void> onAuthenticated({required String token}) async {
    _apiClient.updateAuthToken(token);
    if (_servicesStarted) {
      return;
    }
    final identity = _pcIdentityService.identity;
    final Uri wsUri = Uri.parse('${_apiConfig.wsBaseUrl}/ws/pc').replace(
      queryParameters: <String, String>{
        'token': token,
        'pcId': identity.pcId,
      },
    );
    await _pcWebSocketService.connect(wsUri);
    await _deviceSyncCoordinator?.start();
    _servicesStarted = true;
  }

  Future<void> onLogout() async {
    _apiClient.updateAuthToken(null);
    _servicesStarted = false;
    await _deviceSyncCoordinator?.dispose();
    await _pcWebSocketService.disconnect();
  }

  void _registerSignalHandlers() {
    final List<ProcessSignal> signals = <ProcessSignal>[
      ProcessSignal.sigint,
      if (!Platform.isWindows) ProcessSignal.sigterm,
    ];

    for (final ProcessSignal signal in signals) {
      try {
        final StreamSubscription<ProcessSignal> subscription = signal.watch().listen((ProcessSignal _) async {
          await _logger.info('Received signal $signal, disposing resources');
          await dispose();
          exit(0);
        });
        _signalSubscriptions.add(subscription);
      } on SignalException {
        unawaited(_logger.warning('Signal $signal not supported on current platform'));
      }
    }
  }
}
