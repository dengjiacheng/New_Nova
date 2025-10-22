import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap/bootstrap.dart';
import '../../application/controllers/admin_tools_controller.dart';
import '../../application/controllers/auth_controller.dart';
import '../../application/controllers/connection_controller.dart';
import '../../application/controllers/device_controller.dart';
import '../../application/controllers/execution_controller.dart';
import '../../application/controllers/template_controller.dart';
import '../../application/events/app_event_bus.dart';
import '../../domain/ports/device_event_sink.dart';
import '../../application/services/admin_tools_service.dart';
import '../../application/services/agent_package_manager.dart';
import '../../application/services/auth_service.dart';
import '../../application/services/device_sync_coordinator.dart';
import '../../application/services/template_service.dart';
import '../../data/api/api_client.dart';
import '../../data/clients/auth_api_client.dart';
import '../../data/clients/admin_package_api_client.dart';
import '../../data/services/pc_websocket_service.dart';
import '../../data/services/pc_identity_service.dart';
import '../state/admin_tools_state.dart';
import '../state/auth_state.dart';
import '../state/connection_state.dart';
import '../state/device_state.dart';
import '../state/execution_state.dart';
import '../state/template_state.dart';
import '../../application/services/execution_asset_service.dart';

final Provider<Bootstrap> bootstrapProvider =
    Provider<Bootstrap>((_) => throw UnimplementedError('Bootstrap not initialized'));

final Provider<AppEventBus> appEventBusProvider = Provider<AppEventBus>(
  (ref) => ref.watch(bootstrapProvider).eventBus,
);

final Provider<PcWebSocketService> pcWebSocketServiceProvider =
    Provider<PcWebSocketService>(
  (ref) => ref.watch(bootstrapProvider).pcWebSocketService,
);

final Provider<DeviceEventSink> deviceEventSinkProvider = Provider<DeviceEventSink>(
  (ref) => ref.watch(bootstrapProvider).deviceEventSink,
);

final Provider<PcIdentityService> pcIdentityServiceProvider =
    Provider<PcIdentityService>(
  (ref) => ref.watch(bootstrapProvider).pcIdentityService,
);

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>(
  (ref) => ref.watch(bootstrapProvider).apiClient,
);

final Provider<DeviceSyncCoordinator?> deviceSyncCoordinatorProvider =
    Provider<DeviceSyncCoordinator?>(
  (ref) => ref.watch(bootstrapProvider).deviceSyncCoordinator,
);

final Provider<TemplateService> templateServiceProvider = Provider<TemplateService>(
  (ref) => ref.watch(bootstrapProvider).templateService,
);

final Provider<ExecutionAssetService> executionAssetServiceProvider =
    Provider<ExecutionAssetService>(
  (ref) => ref.watch(bootstrapProvider).executionAssetService,
);

final StateNotifierProvider<TemplateController, TemplateState>
    templateStateProvider =
    StateNotifierProvider<TemplateController, TemplateState>(
  (ref) => TemplateController(service: ref.watch(templateServiceProvider)),
);

final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    authApiClient: AuthApiClient(ref.watch(apiClientProvider)),
    identityService: ref.watch(pcIdentityServiceProvider),
  ),
);

final StateNotifierProvider<AuthController, AuthState> authStateProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    authService: ref.watch(authServiceProvider),
    apiClient: ref.watch(apiClientProvider),
    bootstrap: ref.watch(bootstrapProvider),
  ),
);

final StateNotifierProvider<DeviceController, DeviceState>
    deviceStateProvider = StateNotifierProvider<DeviceController, DeviceState>(
  (ref) => DeviceController(deviceEvents: ref.watch(deviceEventSinkProvider)),
);

final StateNotifierProvider<ConnectionController, ConnectionStateView>
    connectionStateProvider =
    StateNotifierProvider<ConnectionController, ConnectionStateView>(
  (ref) => ConnectionController(eventBus: ref.watch(appEventBusProvider)),
);

final StateNotifierProvider<ExecutionController, ExecutionState>
    executionStateProvider =
    StateNotifierProvider<ExecutionController, ExecutionState>(
  (ref) => ExecutionController(eventBus: ref.watch(appEventBusProvider)),
);

final Provider<AdminToolsService> adminToolsServiceProvider = Provider<AdminToolsService>(
  (ref) => AdminToolsService(
    apiClient: AdminPackageApiClient(ref.watch(apiClientProvider)),
    logger: ref.watch(bootstrapProvider).logger,
  ),
);

final StateNotifierProvider<AdminToolsController, AdminToolsState>
    adminToolsStateProvider =
    StateNotifierProvider<AdminToolsController, AdminToolsState>(
  (ref) => AdminToolsController(service: ref.watch(adminToolsServiceProvider)),
);

final Provider<AgentPackageManager> agentPackageManagerProvider =
    Provider<AgentPackageManager>(
  (ref) => ref.watch(bootstrapProvider).agentPackageManager,
);
