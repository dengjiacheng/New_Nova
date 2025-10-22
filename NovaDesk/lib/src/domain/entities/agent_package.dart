import 'package:meta/meta.dart';

enum AgentPackageStatus { draft, active, archived, unknown }

@immutable
class AgentPackage {
  const AgentPackage({
    required this.packageId,
    required this.versionName,
    required this.versionCode,
    required this.fileSize,
    required this.checksum,
    required this.status,
    required this.uploadedAt,
    required this.uploadedBy,
    this.downloadUrl,
    this.releaseNotes,
    this.tenantId,
  });

  final String packageId;
  final String versionName;
  final int versionCode;
  final int fileSize;
  final String checksum;
  final AgentPackageStatus status;
  final DateTime uploadedAt;
  final UploadedBy uploadedBy;
  final String? downloadUrl;
  final String? releaseNotes;
  final String? tenantId;

  bool get isActive => status == AgentPackageStatus.active;
  bool get isDraft => status == AgentPackageStatus.draft;

  AgentPackage copyWith({
    String? packageId,
    String? versionName,
    int? versionCode,
    int? fileSize,
    String? checksum,
    AgentPackageStatus? status,
    DateTime? uploadedAt,
    UploadedBy? uploadedBy,
    String? downloadUrl,
    String? releaseNotes,
    String? tenantId,
  }) {
    return AgentPackage(
      packageId: packageId ?? this.packageId,
      versionName: versionName ?? this.versionName,
      versionCode: versionCode ?? this.versionCode,
      fileSize: fileSize ?? this.fileSize,
      checksum: checksum ?? this.checksum,
      status: status ?? this.status,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      tenantId: tenantId ?? this.tenantId,
    );
  }

  static AgentPackage fromJson(Map<String, dynamic> json) {
    final String packageId = json['packageId']?.toString() ?? json['id']?.toString() ?? '';
    final Map<String, dynamic>? uploadedByJson =
        json['uploadedBy'] as Map<String, dynamic>?;
    return AgentPackage(
      packageId: packageId,
      versionName: json['versionName']?.toString() ?? '',
      versionCode: int.tryParse(json['versionCode']?.toString() ?? '') ?? 0,
      fileSize: int.tryParse(json['fileSize']?.toString() ?? '') ?? 0,
      checksum: json['checksum']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      uploadedAt: _parseDateTime(json['uploadedAt']?.toString()),
      uploadedBy: UploadedBy.fromJson(uploadedByJson ?? <String, dynamic>{}),
      downloadUrl: json['downloadUrl']?.toString(),
      releaseNotes: json['releaseNotes']?.toString(),
      tenantId: json['tenantId']?.toString(),
    );
  }

  static AgentPackageStatus _parseStatus(String? status) {
    return switch (status?.toUpperCase()) {
      'ACTIVE' => AgentPackageStatus.active,
      'ARCHIVED' => AgentPackageStatus.archived,
      'DRAFT' => AgentPackageStatus.draft,
      _ => AgentPackageStatus.unknown,
    };
  }

  static DateTime _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.tryParse(value)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

@immutable
class UploadedBy {
  const UploadedBy({
    required this.id,
    this.name,
  });

  final String id;
  final String? name;

  factory UploadedBy.fromJson(Map<String, dynamic> json) {
    return UploadedBy(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
    );
  }

  @override
  String toString() => name?.isNotEmpty == true ? name! : id;
}
