import 'package:flutter_test/flutter_test.dart';
import 'package:nova_desk/src/application/controllers/connection_controller.dart';
import 'package:nova_desk/src/application/events/app_event.dart';
import 'package:nova_desk/src/application/events/app_event_bus.dart';

void main() {
  group('ConnectionController', () {
    test('reflects connection state changes', () async {
      final AppEventBus bus = AppEventBus();
      final ConnectionController controller =
          ConnectionController(eventBus: bus);

      bus.publish(const ConnectionStateChanged(
        connected: true,
        reason: 'connected',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.state.connected, isTrue);
      expect(controller.state.message, 'connected');

      controller.dispose();
      await bus.dispose();
    });
  });
}
