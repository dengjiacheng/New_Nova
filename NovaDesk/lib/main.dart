import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/bootstrap/bootstrap.dart';
import 'src/presentation/app.dart';
import 'src/presentation/providers/app_providers.dart';

final Bootstrap _bootstrap = Bootstrap();

void main() {
  // Flutter desktop 用同步阻塞的 main，会在 bootstrap 完成后启动 UI。
  runZonedGuarded(() async {
    await _bootstrap.initialize();
    runApp(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(_bootstrap),
        ],
        child: const NovaDeskApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    // TODO: 接入统一日志上报
    debugPrint('Uncaught error: $error\n$stack');
    unawaited(_bootstrap.dispose());
  });
}
