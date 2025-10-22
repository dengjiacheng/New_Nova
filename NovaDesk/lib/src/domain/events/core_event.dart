import 'dart:convert';

/// 表示服务器推送的核心 WS 消息。
class CoreEvent {
  CoreEvent({
    required this.topic,
    required this.traceId,
    required this.payload,
  });

  final String topic;
  final String traceId;
  final Map<String, dynamic> payload;

  static CoreEvent fromJson(Map<String, dynamic> json) {
    final Object? topicRaw = json['topic'];
    if (topicRaw is! String || topicRaw.isEmpty) {
      throw const FormatException('Missing topic');
    }
    final String traceId = json['traceId'] as String? ?? '';
    final Map<String, dynamic> payload =
        (json['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return CoreEvent(topic: topicRaw, traceId: traceId, payload: payload);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'topic': topic,
        'traceId': traceId,
        'payload': payload,
      };

  @override
  String toString() => jsonEncode(toJson());
}
