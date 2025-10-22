import 'dart:convert';

/// 表示 NovaDesk 客户端的唯一身份。
class PcIdentity {
  PcIdentity({
    required this.pcId,
    required this.createdAt,
    required this.lastLoginAt,
    required this.clientVersion,
  });

  final String pcId;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final String clientVersion;

  PcIdentity copyWith({
    String? pcId,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? clientVersion,
  }) {
    return PcIdentity(
      pcId: pcId ?? this.pcId,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      clientVersion: clientVersion ?? this.clientVersion,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'pcId': pcId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'lastLoginAt': lastLoginAt.toUtc().toIso8601String(),
        'clientVersion': clientVersion,
      };

  static PcIdentity fromJson(Map<String, dynamic> json) {
    final Object? pcIdRaw = json['pcId'];
    if (pcIdRaw is! String || pcIdRaw.isEmpty) {
      throw const FormatException('Missing pcId');
    }
    final String createdAtRaw = json['createdAt'] as String? ??
        (throw const FormatException('Missing createdAt'));
    final String lastLoginRaw = (json['lastLoginAt'] as String?) ?? createdAtRaw;
    return PcIdentity(
      pcId: pcIdRaw,
      createdAt: DateTime.parse(createdAtRaw).toUtc(),
      lastLoginAt: DateTime.parse(lastLoginRaw).toUtc(),
      clientVersion: json['clientVersion'] as String? ?? 'unknown',
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
