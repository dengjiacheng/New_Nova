import 'package:meta/meta.dart';

@immutable
class ConnectionStateView {
  const ConnectionStateView({
    required this.connected,
    required this.message,
  });

  const ConnectionStateView.initial()
      : connected = false,
        message = 'disconnected';

  final bool connected;
  final String message;

  ConnectionStateView copyWith({
    bool? connected,
    String? message,
  }) {
    return ConnectionStateView(
      connected: connected ?? this.connected,
      message: message ?? this.message,
    );
  }
}
