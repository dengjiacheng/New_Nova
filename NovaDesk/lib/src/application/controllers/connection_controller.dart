import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../events/app_event.dart';
import '../events/app_event_bus.dart';
import '../../presentation/state/connection_state.dart';

class ConnectionController extends StateNotifier<ConnectionStateView> {
  ConnectionController({required AppEventBus eventBus})
      : _eventBus = eventBus,
        super(const ConnectionStateView.initial()) {
    _subscription = _eventBus.stream.listen(_handleEvent);
  }

  final AppEventBus _eventBus;
  StreamSubscription<AppEvent>? _subscription;

  void _handleEvent(AppEvent event) {
    if (event is ConnectionStateChanged) {
      state = state.copyWith(
        connected: event.connected,
        message: event.reason,
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
