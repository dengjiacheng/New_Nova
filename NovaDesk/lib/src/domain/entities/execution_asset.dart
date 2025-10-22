import 'dart:convert';

import 'package:meta/meta.dart';

@immutable
class UploadAssetResponse {
  const UploadAssetResponse({
    required this.assetId,
    required this.downloadUrl,
    required this.expiresAt,
    required this.checksum,
  });

  final String assetId;
  final String downloadUrl;
  final DateTime expiresAt;
  final String checksum;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'assetId': assetId,
        'downloadUrl': downloadUrl,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'checksum': checksum,
      };

  @override
  String toString() => jsonEncode(toJson());
}

@immutable
class UploadedAsset {
  const UploadedAsset({
    required this.fieldKey,
    required this.assetId,
    required this.checksum,
  });

  final String fieldKey;
  final String assetId;
  final String checksum;
}
