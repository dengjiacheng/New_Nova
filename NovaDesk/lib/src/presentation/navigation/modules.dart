import 'package:flutter/material.dart';

import '../state/auth_state.dart';

enum AppModule {
  dashboard(Icons.dashboard_outlined, '仪表盘'),
  devices(Icons.devices_other_outlined, '设备管理'),
  scripts(Icons.extension_outlined, '脚本模板'),
  executions(Icons.play_circle_outline, '执行监控'),
  billing(Icons.receipt_long_outlined, '账单审计'),
  adminTools(Icons.build_outlined, '管理员工具');

  const AppModule(this.icon, this.label);

  final IconData icon;
  final String label;
}

List<AppModule> modulesForRole(UserRole role) {
  return switch (role) {
    UserRole.superAdmin => AppModule.values,
    UserRole.admin => AppModule.values,
    UserRole.user => const <AppModule>[
        AppModule.dashboard,
        AppModule.devices,
        AppModule.scripts,
        AppModule.executions,
      ],
    UserRole.unknown => const <AppModule>[
        AppModule.dashboard,
        AppModule.devices,
        AppModule.scripts,
        AppModule.executions,
      ],
  };
}
