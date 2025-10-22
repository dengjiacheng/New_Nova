import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../application/events/app_event.dart';
import '../../application/events/app_event_bus.dart';
import '../../application/events/core_event_mapper.dart';
import '../../domain/events/core_event.dart';
import '../../domain/events/device_event.dart';
import '../../domain/ports/device_event_sink.dart';
import '../../platform/app_logger.dart';

typedef WebSocketConnector = WebSocketChannel Function(
  Uri uri, {
  Iterable<String>? protocols,
  Map<String, dynamic>? headers,
});

WebSocketChannel _defaultConnector(
  Uri uri, {
  Iterable<String>? protocols,
  Map<String, dynamic>? headers,
}) {
  return WebSocketChannel.connect(uri, protocols: protocols);
}

/// 管理 PC 与 Server 的 WebSocket 会话，负责消息解析与事件派发。
class PcWebSocketService {
  PcWebSocketService({
    required AppEventBus eventBus,
    required DeviceEventSink deviceEvents,
    AppLogger? logger,
    CoreEventMapper? mapper,
    WebSocketConnector? connector,
  })  : _eventBus = eventBus,
        _deviceEvents = deviceEvents,
        _logger = logger ?? AppLogger.defaultLogger(),
        _mapper = mapper ?? CoreEventMapper(),
        _connector = connector ?? _defaultConnector;

  final AppEventBus _eventBus;
  final DeviceEventSink _deviceEvents;
  final AppLogger _logger;
  final CoreEventMapper _mapper;
  final WebSocketConnector _connector;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _connected = false;

  bool get isConnected => _connected;

  Future<void> connect(Uri uri, {Iterable<String>? protocols, Map<String, dynamic>? headers}) async {
    await disconnect();
    try {
      final WebSocketChannel channel =
          _connector(uri, protocols: protocols, headers: headers);
      await _bindChannel(channel);
      _connected = true;
      _eventBus.publish(const ConnectionStateChanged(connected: true, reason: 'connected'));
      await _logger.info('WebSocket connected: $uri');
    } catch (error) {
      await _logger.error('Failed to connect WebSocket: $uri', cause: error);
      _eventBus.publish(const ConnectionStateChanged(connected: false, reason: 'connect_error'));
      rethrow;
    }
  }

  Future<void> injectChannel(WebSocketChannel channel) async {
    await disconnect();
    await _bindChannel(channel);
    _connected = true;
    _eventBus.publish(const ConnectionStateChanged(connected: true, reason: 'injected'));
  }

  Future<void> disconnect() async {
    _connected = false;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
  }

  Future<void> _bindChannel(WebSocketChannel channel) async {
    _channel = channel;
    _subscription = channel.stream.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
      cancelOnError: true,
    );
  }

  void _handleMessage(dynamic raw) {
    try {
      final CoreEvent event = _parseMessage(raw);
      final DeviceEvent? deviceEvent = _mapper.mapDeviceEvent(event);
      if (deviceEvent != null) {
        _deviceEvents.publish(deviceEvent);
        return;
      }
      final AppEvent? appEvent = _mapper.mapAppEvent(event);
      if (appEvent != null) {
        _eventBus.publish(appEvent);
      }
    } catch (error) {
      _logger.error('Failed to handle WebSocket message', cause: error);
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _connected = false;
    _eventBus.publish(ConnectionStateChanged(connected: false, reason: error.toString()));
    _logger.error('WebSocket error', cause: error);
  }

  void _handleDone() {
    _connected = false;
    _eventBus.publish(const ConnectionStateChanged(connected: false, reason: 'closed'));
  }

  CoreEvent _parseMessage(dynamic raw) {
    if (raw is String) {
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      return CoreEvent.fromJson(json);
    } else if (raw is List<int>) {
      final String message = utf8.decode(raw);
      final Map<String, dynamic> json =
          jsonDecode(message) as Map<String, dynamic>;
      return CoreEvent.fromJson(json);
    } else {
      throw FormatException('Unsupported message type: ${raw.runtimeType}');
    }
  }
}
