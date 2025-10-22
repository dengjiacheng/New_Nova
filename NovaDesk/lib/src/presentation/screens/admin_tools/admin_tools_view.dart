import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../state/admin_tools_state.dart';
import '../../state/auth_state.dart';
import '../../../domain/entities/agent_package.dart';

class AdminToolsView extends ConsumerStatefulWidget {
  const AdminToolsView({super.key});

  @override
  ConsumerState<AdminToolsView> createState() => _AdminToolsViewState();
}

class _AdminToolsViewState extends ConsumerState<AdminToolsView> {
  static const int _maxApkSizeBytes = 200 * 1024 * 1024;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _versionNameController = TextEditingController();
  final TextEditingController _versionCodeController = TextEditingController();
  final TextEditingController _releaseNotesController = TextEditingController();
  ProviderSubscription<AdminToolsState>? _subscription;
  File? _selectedFile;
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _checksum;
  bool _checksumComputing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminToolsStateProvider.notifier).loadPackages();
    });
    _subscription = ref.listenManual<AdminToolsState>(
      adminToolsStateProvider,
      (AdminToolsState? previous, AdminToolsState next) {
        if (next.errorMessage != null &&
            next.errorMessage != previous?.errorMessage &&
            mounted) {
          _showSnack(next.errorMessage!, isError: true);
        } else if (next.successMessage != null &&
            next.successMessage != previous?.successMessage &&
            mounted) {
          _showSnack(next.successMessage!);
          if (previous?.uploading == true && !next.uploading) {
            _resetForm();
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    _versionNameController.dispose();
    _versionCodeController.dispose();
    _releaseNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AdminToolsState state = ref.watch(adminToolsStateProvider);
    final AuthState authState = ref.watch(authStateProvider);
    final List<UserRole> roles = authState.session?.roles ?? const <UserRole>[];
    final bool canActivate =
        roles.contains(UserRole.superAdmin) || roles.contains(UserRole.admin);
    final ThemeData theme = Theme.of(context);
    final AgentPackage? active = state.activePackage;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildUploadCard(theme, state),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (active != null)
                      _ActiveVersionBanner(
                        package: active,
                      ),
                    const SizedBox(height: 16),
                    _buildPackageList(state, canActivate),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard(ThemeData theme, AdminToolsState state) {
    final bool uploading = state.uploading;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('上传 Agent APK', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: uploading
                          ? null
                          : () {
                              _pickFile();
                            },
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('选择 APK 文件'),
                    ),
                  ),
                  if (_selectedFileName != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFileName!,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_selectedFileSize != null)
                            Text(
                              _formatBytes(_selectedFileSize!),
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _versionNameController,
                decoration: const InputDecoration(
                  labelText: 'Version Name',
                  hintText: '例如 2.1.0',
                ),
                enabled: !uploading,
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入版本名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _versionCodeController,
                decoration: const InputDecoration(
                  labelText: 'Version Code',
                  hintText: '例如 2100',
                ),
                enabled: !uploading,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (String? value) {
                  final int? code = int.tryParse(value ?? '');
                  if (code == null || code <= 0) {
                    return '请输入大于 0 的整数版本号';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _releaseNotesController,
                decoration: const InputDecoration(
                  labelText: 'Release Notes',
                  hintText: '可选，支持 Markdown 语法',
                  alignLabelWithHint: true,
                ),
                enabled: !uploading,
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: uploading
                          ? null
                          : () {
                              _submitUpload();
                            },
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(uploading ? '正在上传...' : '上传'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: '清空表单',
                    onPressed: uploading ? null : _resetForm,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (uploading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: state.uploadProgress.clamp(0, 1).toDouble(),
                ),
              ],
              if (_checksumComputing)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('正在计算 SHA256 校验值...'),
                    ],
                  ),
                )
              else if (_checksum != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SelectableText(
                          _checksum!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      IconButton(
                        tooltip: '复制校验值',
                        icon: const Icon(Icons.copy_all_outlined),
                        onPressed: () => _copyToClipboard(_checksum),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageList(AdminToolsState state, bool canActivate) {
    final controller = ref.read(adminToolsStateProvider.notifier);
    final bool disableActions = state.loading;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('历史版本'),
                const Spacer(),
                IconButton(
                  tooltip: '刷新',
                  onPressed: state.loading
                      ? null
                      : () {
                          controller.loadPackages();
                        },
                  icon: state.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.packages.isEmpty && !state.loading)
              const Center(child: Text('暂无上传记录'))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 480),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.packages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final AgentPackage pkg = state.packages[index];
                    final bool isActive = pkg.isActive;
                    return _AgentPackageTile(
                      package: pkg,
                      canActivate: canActivate,
                      sizeLabel: _formatBytes(pkg.fileSize),
                      onActivate: disableActions
                          ? null
                          : () {
                              controller.activatePackage(packageId: pkg.packageId);
                            },
                      onDelete: disableActions ? null : () => _confirmDelete(pkg),
                      onShowNotes: pkg.releaseNotes?.isNotEmpty == true
                          ? () => _showReleaseNotes(pkg)
                          : null,
                      isLatest: index == 0,
                      isActive: isActive,
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['apk'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final PlatformFile platformFile = result.files.single;
    if (platformFile.path == null) {
      _showSnack('未能读取文件路径', isError: true);
      return;
    }
    final String extension = (platformFile.extension ?? '').toLowerCase();
    if (extension != 'apk') {
      _showSnack('仅支持上传 APK 文件', isError: true);
      return;
    }
    final File file = File(platformFile.path!);
    final int sizeInBytes = await file.length();
    if (sizeInBytes <= 0) {
      _showSnack('文件大小异常，请重新选择 APK', isError: true);
      return;
    }
    if (sizeInBytes > _maxApkSizeBytes) {
      _showSnack('文件超过 200 MB 限制，请压缩后再试', isError: true);
      return;
    }
    setState(() {
      _selectedFile = file;
      _selectedFileName = platformFile.name;
      _selectedFileSize = sizeInBytes;
      _checksum = null;
    });
    await _computeChecksum(file);
  }

  Future<void> _computeChecksum(File file) async {
    setState(() => _checksumComputing = true);
    try {
      final String checksum =
          await ref.read(adminToolsStateProvider.notifier).computeChecksum(file);
      if (!mounted) {
        return;
      }
      setState(() {
        _checksum = checksum;
        _checksumComputing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _checksumComputing = false);
      _showSnack('计算校验值失败：$error', isError: true);
    }
  }

  Future<void> _submitUpload() async {
    if (_selectedFile == null) {
      _showSnack('请先选择 APK 文件', isError: true);
      return;
    }
    if (_checksumComputing) {
      _showSnack('正在计算校验值，请稍候', isError: true);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final int versionCode = int.parse(_versionCodeController.text);
    await ref.read(adminToolsStateProvider.notifier).uploadPackage(
          file: _selectedFile!,
          versionName: _versionNameController.text.trim(),
          versionCode: versionCode,
          releaseNotes: _releaseNotesController.text.trim().isEmpty
              ? null
              : _releaseNotesController.text.trim(),
          checksum: _checksum,
    );
  }

  void _resetForm() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _selectedFileSize = null;
      _checksum = null;
      _checksumComputing = false;
    });
    _versionNameController.clear();
    _versionCodeController.clear();
    _releaseNotesController.clear();
  }

  Future<void> _confirmDelete(AgentPackage pkg) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text(
            '确定要删除版本 ${pkg.versionName} (${pkg.versionCode}) 吗？'
            '${pkg.isActive ? '\\n当前为激活版本，删除后将无法自动安装。' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await ref
          .read(adminToolsStateProvider.notifier)
          .deletePackage(pkg.packageId);
    }
  }

  void _copyToClipboard(String? value) {
    if (value == null || value.isEmpty) {
      _showSnack('无可复制内容', isError: true);
      return;
    }
    Clipboard.setData(ClipboardData(text: value));
    _showSnack('已复制到剪贴板');
  }

  void _showReleaseNotes(AgentPackage pkg) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('版本 ${pkg.versionName} 发布说明'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: SelectableText(pkg.releaseNotes ?? '—'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  String _formatBytes(int bytes) {
    const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unitIndex]}';
  }
}

class _ActiveVersionBanner extends StatelessWidget {
  const _ActiveVersionBanner({
    required this.package,
  });

  final AgentPackage package;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.verified, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前激活版本：${package.versionName} (${package.versionCode})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '上传时间：${package.uploadedAt.toLocal()} · 操作人：${package.uploadedBy}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentPackageTile extends StatelessWidget {
  const _AgentPackageTile({
    required this.package,
    required this.canActivate,
    required this.sizeLabel,
    this.onActivate,
    this.onDelete,
    this.onShowNotes,
    required this.isLatest,
    required this.isActive,
  });

  final AgentPackage package;
  final bool canActivate;
  final String sizeLabel;
  final VoidCallback? onActivate;
  final VoidCallback? onDelete;
  final VoidCallback? onShowNotes;
  final bool isLatest;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    Chip statusChip() {
      if (isActive) {
        return Chip(
          backgroundColor: scheme.primaryContainer,
          label: Text(
            'ACTIVE',
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
        );
      }
      if (package.isDraft) {
        return Chip(
          backgroundColor: scheme.secondaryContainer,
          label: Text(
            'DRAFT',
            style: TextStyle(color: scheme.onSecondaryContainer),
          ),
        );
      }
      return Chip(
        label: Text(package.status.name.toUpperCase()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${package.versionName} (${package.versionCode})',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  _DetailRow(
                    icon: Icons.person_outline,
                    value: package.uploadedBy.toString(),
                  ),
                  _DetailRow(
                    icon: Icons.access_time,
                    value: package.uploadedAt.toLocal().toString(),
                  ),
                  _DetailRow(
                    icon: Icons.sd_storage_outlined,
                    value: sizeLabel,
                  ),
                  _DetailRow(
                    icon: Icons.qr_code_2_outlined,
                    value: package.checksum,
                  ),
                  if (isActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '当前激活版本',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            statusChip(),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (onShowNotes != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.description_outlined),
                label: const Text('查看发布说明'),
                onPressed: onShowNotes,
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除'),
              onPressed: onDelete,
            ),
            if (canActivate && !isActive)
              FilledButton.icon(
                icon: const Icon(Icons.verified_outlined),
                label: const Text('设为当前版本'),
                onPressed: onActivate,
              ),
          ],
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.value, this.semanticLabel});

  final IconData icon;
  final String value;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: style?.color, semanticLabel: semanticLabel),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: style,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
