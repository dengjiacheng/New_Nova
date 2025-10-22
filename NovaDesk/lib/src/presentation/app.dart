import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/services/agent_package_manager.dart';
import '../application/services/device_sync_coordinator.dart';
import '../domain/entities/device_snapshot.dart';
import '../platform/adb/adb_service.dart';
import 'providers/app_providers.dart';
import 'navigation/modules.dart';
import 'screens/admin_tools/admin_tools_view.dart';
import 'screens/login_screen.dart';
import 'state/auth_state.dart';
import 'state/connection_state.dart';
import 'state/device_state.dart';

class NovaDeskApp extends ConsumerStatefulWidget {
  const NovaDeskApp({super.key});

  @override
  ConsumerState<NovaDeskApp> createState() => _NovaDeskAppState();
}

class _NovaDeskAppState extends ConsumerState<NovaDeskApp> {
  @override
  void dispose() {
    // 应用退出时释放 bootstrap 资源。
    unawaited(ref.read(bootstrapProvider).dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authStateProvider);
    return MaterialApp(
      title: 'NovaDesk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: switch (authState.status) {
        AuthStatus.authenticated => const _HomeScreen(),
        AuthStatus.loading => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        _ => const LoginScreen(),
      },
    );
  }
}

class _HomeScreen extends ConsumerStatefulWidget {
  const _HomeScreen();

  @override
  ConsumerState<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<_HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  AppModule _selectedModule = AppModule.devices;

  List<DeviceSnapshot> _sortedDevices(Iterable<DeviceSnapshot> devices) {
    final List<DeviceSnapshot> list = devices.toList()
      ..sort((DeviceSnapshot a, DeviceSnapshot b) => a.deviceId.compareTo(b.deviceId));
    return list;
  }

  void _showSnack(BuildContext context, String message, {bool error = false}) {
    final SnackBar snackBar = SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _openWifiConnectDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    final String? hostPort = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('连接 Wi-Fi 设备'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '设备地址',
              hintText: '例如 192.168.0.12:5555',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('连接'),
            ),
          ],
        );
      },
    );
    if (hostPort == null || hostPort.isEmpty) {
      return;
    }
    try {
      final DeviceSyncCoordinator? coordinator =
          ref.read(deviceSyncCoordinatorProvider);
      if (coordinator == null) {
        if (mounted) {
          _showSnack(context, '设备同步服务未初始化', error: true);
        }
        return;
      }
      final AdbCommandResult result =
          await coordinator.connectWifiDevice(hostPort);
      if (!context.mounted) {
        return;
      }
      final String message = result.stdout.trim().isNotEmpty
          ? result.stdout.trim()
          : '已连接 Wi-Fi 设备 $hostPort';
      _showSnack(context, message);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnack(context, '连接 Wi-Fi 设备失败: $error', error: true);
    }
  }

  Future<void> _handleDeviceAction(
    BuildContext context,
    DeviceSnapshot device,
    DeviceAction action,
  ) async {
    switch (action) {
      case DeviceAction.bringOnline:
        _showSnack(context, '正在准备上线，请稍候...');
        try {
          final AgentPackagePreparationResult result =
              await ref.read(agentPackageManagerProvider).prepareDevice(device.deviceId);
          if (!context.mounted) {
            return;
          }
          final String message = result.status == AgentPreparationStatus.installed
              ? '设备 ${device.deviceId} 已安装最新 Agent 包，后续启动流程将逐步接入。'
              : '设备 ${device.deviceId} 已具备最新 Agent 包，可直接上线。';
          _showSnack(context, message);
        } catch (error, stackTrace) {
          if (!context.mounted) {
            return;
          }
          unawaited(ref
              .read(bootstrapProvider)
              .logger
              .error('Prepare device ${device.deviceId} failed', cause: '$error\n$stackTrace'));
          _showSnack(context, '上线前准备失败：$error', error: true);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthState authState = ref.watch(authStateProvider);
    final ConnectionStateView connectionState = ref.watch(connectionStateProvider);
    final deviceState = ref.watch(deviceStateProvider);
    final templateState = ref.watch(templateStateProvider);

    final List<DeviceSnapshot> sortedDevices = _sortedDevices(deviceState.devices.values);
    final int localCount =
        sortedDevices.where((DeviceSnapshot d) => !d.remoteOnly).length;
    final int remoteOnlyCount =
        sortedDevices.where((DeviceSnapshot d) => d.remoteOnly).length;

    final int onlineCount = sortedDevices
        .where(
          (DeviceSnapshot d) =>
              d.serverOnline || d.localStatus == DeviceLocalStatus.online,
        )
        .length;
    final int totalTemplates = templateState.templatesByScript.values.fold<int>(
      0,
      (int sum, List<dynamic> templates) => sum + templates.length,
    );

    final List<AppModule> modules =
        modulesForRole(authState.session?.role ?? UserRole.unknown);
    AppModule activeModule = _selectedModule;
    if (!modules.contains(activeModule) && modules.isNotEmpty) {
      activeModule = modules.first;
      if (_selectedModule != activeModule) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedModule = activeModule;
            });
          }
        });
      }
    }

    final String? tenantName = authState.session?.tenantName;
    final String roleLabel = _roleLabel(authState.session?.role ?? UserRole.unknown);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NovaDesk'),
            if ((tenantName ?? '').isNotEmpty)
              Text(
                '$tenantName · $roleLabel',
                style: theme.textTheme.bodySmall,
              )
            else
              Text(
                roleLabel,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: '调试面板',
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('联调调试面板', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                Text('当前角色：$roleLabel'),
                Text('WS 状态：${connectionState.connected ? '已连接' : '未连接'}'),
                Text('说明：${connectionState.message}'),
                const SizedBox(height: 12),
                Text('设备总数：${sortedDevices.length}'),
                Text('在线设备：$onlineCount'),
                if (deviceState.lastUpdatedAt != null)
                  Text('最近同步：${deviceState.lastUpdatedAt!.toLocal()}'),
                const SizedBox(height: 12),
                Text('模板数量：$totalTemplates'),
              ],
            ),
          ),
        ),
      ),
      body: modules.isEmpty
          ? _buildPlaceholder(AppModule.devices)
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: modules.indexOf(activeModule),
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedModule = modules[index];
                    });
                  },
                  destinations: modules
                      .map(
                        (AppModule module) => NavigationRailDestination(
                          icon: Icon(module.icon),
                          selectedIcon: Icon(
                            module.icon,
                            color: theme.colorScheme.primary,
                          ),
                          label: Text(module.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildModuleContent(
                      context: context,
                      module: activeModule,
                      connectionState: connectionState,
                      deviceState: deviceState,
                      sortedDevices: sortedDevices,
                      localCount: localCount,
                      remoteOnlyCount: remoteOnlyCount,
                      onlineCount: onlineCount,
                      totalTemplates: totalTemplates,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildModuleContent({
    required BuildContext context,
    required AppModule module,
    required ConnectionStateView connectionState,
    required DeviceState deviceState,
    required List<DeviceSnapshot> sortedDevices,
    required int localCount,
    required int remoteOnlyCount,
    required int onlineCount,
    required int totalTemplates,
  }) {
    switch (module) {
      case AppModule.devices:
        return KeyedSubtree(
          key: const ValueKey<String>('devices'),
          child: _buildDeviceManagementView(
            context: context,
            connectionState: connectionState,
            deviceState: deviceState,
            sortedDevices: sortedDevices,
            localCount: localCount,
            remoteOnlyCount: remoteOnlyCount,
            onlineCount: onlineCount,
            totalTemplates: totalTemplates,
          ),
        );
      case AppModule.adminTools:
        return const KeyedSubtree(
          key: ValueKey<String>('adminTools'),
          child: AdminToolsView(),
        );
      default:
        return KeyedSubtree(
          key: ValueKey<String>('placeholder-${module.name}'),
          child: _buildPlaceholder(module),
        );
    }
  }

  Widget _buildDeviceManagementView({
    required BuildContext context,
    required ConnectionStateView connectionState,
    required DeviceState deviceState,
    required List<DeviceSnapshot> sortedDevices,
    required int localCount,
    required int remoteOnlyCount,
    required int onlineCount,
    required int totalTemplates,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _DeviceToolbar(
            connectionState: connectionState,
            lastSyncedAt: deviceState.lastUpdatedAt,
            onlineCount: onlineCount,
            totalDevices: sortedDevices.length,
            localCount: localCount,
            remoteOnlyCount: remoteOnlyCount,
            onConnectWifi: () => _openWifiConnectDialog(context),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: sortedDevices.isEmpty
                ? const _EmptyState()
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: _DeviceListTable(
                      devices: sortedDevices,
                      onAction: (DeviceSnapshot device, DeviceAction action) =>
                          _handleDeviceAction(context, device, action),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          _BottomStatusBar(
            connectionState: connectionState,
            templates: totalTemplates,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(AppModule module) {
    return Center(
      child: Text(
        '${module.label} 功能联调中，敬请期待',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  String _roleLabel(UserRole role) {
    return switch (role) {
      UserRole.superAdmin => '超级管理员',
      UserRole.admin => '租户管理员',
      UserRole.user => '普通用户',
      UserRole.unknown => '未识别角色',
    };
  }
}

class _DeviceToolbar extends StatelessWidget {
  const _DeviceToolbar({
    required this.connectionState,
    required this.lastSyncedAt,
    required this.onlineCount,
    required this.totalDevices,
    required this.localCount,
    required this.remoteOnlyCount,
    required this.onConnectWifi,
  });

  final ConnectionStateView connectionState;
  final DateTime? lastSyncedAt;
  final int onlineCount;
  final int totalDevices;
  final int localCount;
  final int remoteOnlyCount;
  final VoidCallback onConnectWifi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      color: scheme.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设备管理',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '在线 $onlineCount / 总计 $totalDevices · 本地可见 $localCount · 仅云端 $remoteOnlyCount',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  connectionState.connected
                      ? 'WebSocket 已连接 · ${connectionState.message}'
                      : 'WebSocket 未连接 · ${connectionState.message}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onConnectWifi,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('连接 Wi-Fi'),
            ),
            const SizedBox(width: 16),
            if (lastSyncedAt != null)
              Text(
                '最近同步 ${TimeOfDay.fromDateTime(lastSyncedAt!.toLocal()).format(context)}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _DeviceListTile extends StatelessWidget {
  const _DeviceListTile({
    required this.device,
    required this.onAction,
  });

  final DeviceSnapshot device;
  final ValueChanged<DeviceAction> onAction;

  String _nameLabel() {
    if (device.alias != null && device.alias!.trim().isNotEmpty) {
      return device.alias!.trim();
    }
    if (device.adbModel != null && device.adbModel!.isNotEmpty) {
      return device.adbModel!;
    }
    if (device.adbProduct != null && device.adbProduct!.isNotEmpty) {
      return device.adbProduct!;
    }
    return '--';
  }

  Color _localStatusColor(ColorScheme scheme) {
    if (device.remoteOnly) {
      return scheme.outline;
    }
    if (device.adbStatus == 'unauthorized') {
      return scheme.error;
    }
    if (device.localStatus == DeviceLocalStatus.online) {
      return scheme.primary;
    }
    if (device.localStatus == DeviceLocalStatus.starting ||
        device.localStatus == DeviceLocalStatus.stopping) {
      return scheme.tertiary;
    }
    return scheme.outline;
  }

  String _localStatusLabel() {
    if (device.remoteOnly) {
      return '未检测';
    }
    if (device.adbStatus == 'unauthorized') {
      return '未授权';
    }
    switch (device.localStatus) {
      case DeviceLocalStatus.online:
        return '在线';
      case DeviceLocalStatus.starting:
        return '启动中';
      case DeviceLocalStatus.stopping:
        return '停止中';
      case DeviceLocalStatus.offline:
        return '未上线';
    }
  }

  Color _cloudStatusColor(ColorScheme scheme) {
    if (device.conflict) {
      return scheme.error;
    }
    if (device.serverOnline) {
      return scheme.primary;
    }
    if (device.remoteOnly) {
      return scheme.tertiary;
    }
    return scheme.outline;
  }

  String _cloudStatusLabel() {
    if (device.conflict) {
      return '被占用';
    }
    if (device.serverOnline) {
      return '在线';
    }
    if (device.remoteOnly) {
      return '云端在线';
    }
    return '未上线';
  }

  Widget _statusChip({required String label, required Color color}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 32, maxWidth: 72),
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String connectionText = device.remoteOnly
        ? '未知'
        : switch (device.connectionType) {
            DeviceConnectionType.usb => 'USB',
            DeviceConnectionType.wifi => 'Wi-Fi',
            DeviceConnectionType.unknown => '未知',
          };
    final String screenSize = device.screenResolution ?? '--';
    final String androidVersion = device.androidVersion ?? '--';

    final bool canBringOnline =
        !device.remoteOnly && !device.serverOnline && !device.conflict;

    final Color localColor = _localStatusColor(scheme);
    final Color cloudColor = _cloudStatusColor(scheme);
    final Color rowColor = device.serverOnline
              ? scheme.primary.withValues(alpha: 0.06)
        : device.remoteOnly
            ? scheme.surfaceContainerLowest
            : scheme.surface;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              device.deviceId,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _nameLabel(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(screenSize, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: 2,
            child: Text(androidVersion, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: 2,
            child: Text(connectionText, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IntrinsicWidth(
                child: _statusChip(
                  label: _localStatusLabel(),
                  color: localColor,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IntrinsicWidth(
                child: _statusChip(
                  label: _cloudStatusLabel(),
                  color: cloudColor,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              device.serverPcId?.isNotEmpty == true ? device.serverPcId! : '--',
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow_outlined, size: 16),
                label: const Text('上线'),
                onPressed: canBringOnline
                    ? () => onAction(DeviceAction.bringOnline)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceListTable extends StatelessWidget {
  const _DeviceListTable({
    required this.devices,
    required this.onAction,
  });

  final List<DeviceSnapshot> devices;
  final void Function(DeviceSnapshot device, DeviceAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius radius = BorderRadius.circular(16);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: radius,
          color: theme.colorScheme.surface,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Row(
                children: [
                  _DeviceListHeaderCell('设备ID', flex: 3),
                  _DeviceListHeaderCell('名称', flex: 3),
                  _DeviceListHeaderCell('屏幕尺寸', flex: 2),
                  _DeviceListHeaderCell('安卓版本', flex: 2),
                  _DeviceListHeaderCell('连接方式', flex: 2),
                  _DeviceListHeaderCell('本地状态', flex: 2),
                  _DeviceListHeaderCell('云端状态', flex: 2),
                  _DeviceListHeaderCell('PC_ID', flex: 2),
                  _DeviceListHeaderCell('操作', flex: 3),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: Scrollbar(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (BuildContext context, int index) {
                    final DeviceSnapshot device = devices[index];
                    return _DeviceListTile(
                      device: device,
                      onAction: (DeviceAction action) => onAction(device, action),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceListHeaderCell extends StatelessWidget {
  const _DeviceListHeaderCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: style,
        textAlign: TextAlign.left,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices_other_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            const Text('暂未发现设备'),
            const SizedBox(height: 8),
            const Text('连接设备或点击“全量刷新”重新拉取'),
          ],
        ),
      ),
    );
  }
}

class _BottomStatusBar extends StatelessWidget {
  const _BottomStatusBar({
    required this.connectionState,
    required this.templates,
  });

  final ConnectionStateView connectionState;
  final int templates;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            connectionState.connected ? Icons.check_circle : Icons.cancel,
            color: connectionState.connected ? scheme.primary : scheme.error,
          ),
          const SizedBox(width: 8),
          Text(
            connectionState.connected
                ? 'WS 已连接 · ${connectionState.message}'
                : 'WS 未连接 · ${connectionState.message}',
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          Text(
            '本地模板：$templates',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

enum DeviceAction { bringOnline }
