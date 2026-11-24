import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/device_contact.dart';
import '../services/contacts_export_service.dart';
import '../services/permission_service.dart';

/// 通讯录导出页：读取手机通讯录 → 勾选联系人 → 导出为 Excel
class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  bool _isLoading = false;
  bool _isExporting = false;
  String? _error;
  List<DeviceContact> _contacts = [];
  final Set<int> _selected = {};

  bool get _allSelected =>
      _contacts.isNotEmpty && _selected.length == _contacts.length;

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final contacts = await ContactsExportService.loadDeviceContacts();
      setState(() {
        _contacts = contacts;
        _selected.clear();
      });
    } catch (e) {
      setState(() {
        _error = '读取通讯录失败: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggle(int index, bool? checked) {
    setState(() {
      if (checked == true) {
        _selected.add(index);
      } else {
        _selected.remove(index);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(List.generate(_contacts.length, (i) => i));
      }
    });
  }

  Future<void> _exportSelected() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先勾选要导出的联系人')),
      );
      return;
    }

    final chosen = [for (final i in _selected) _contacts[i]];
    final bytes = ContactsExportService.buildExcelBytes(chosen);
    final fileName = ContactsExportService.defaultFileName();

    setState(() => _isExporting = true);
    try {
      // 优先带 MIME 限制保存（SAF 创建文档）
      String? path;
      try {
        path = await FilePicker.platform.saveFile(
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: bytes,
        );
      } catch (err) {
        // 部分 OEM ROM 对 custom MIME 支持不佳，降级为不限制类型
        debugPrint('saveFile custom 异常，降级重试: $err');
        path = await FilePicker.platform.saveFile(
          fileName: fileName,
          bytes: bytes,
        );
      }

      if (!mounted) return;
      if (path == null) {
        // 用户取消了保存对话框
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 已导出 ${chosen.length} 条联系人\n保存位置: $path'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_contacts.isEmpty) {
      return _buildEmptyView();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '共读取 ${_contacts.length} 位联系人，已选 ${_selected.length} 条',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              TextButton.icon(
                icon: Icon(
                  _allSelected ? Icons.check_box_outline_blank : Icons.check_box,
                  size: 18,
                ),
                label: Text(_allSelected ? '全不选' : '全选'),
                onPressed: _toggleAll,
              ),
            ],
          ),
        ),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _contacts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final c = _contacts[index];
                    return CheckboxListTile(
                      value: _selected.contains(index),
                      onChanged: (v) => _toggle(index, v),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        c.displayName.isEmpty ? '(无姓名)' : c.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      subtitle: Text(
                        '${c.phone.isNotEmpty ? c.phone : '无手机号'}'
                        '${c.department.isNotEmpty ? ' · ${c.department}' : ''}'
                        '${c.title.isNotEmpty ? ' · ${c.title}' : ''}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_download),
                label: Text(_isExporting
                    ? '正在生成 Excel...'
                    : '导出所选为 Excel (${_selected.length} 条)'),
                onPressed: _isExporting || _selected.isEmpty ? null : _exportSelected,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contact_page_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              '导出手机通讯录',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '读取手机中的联系人，勾选后导出为 Excel 表格。\n'
              '导出的表格可直接在「Excel/CSV 表格导入」中再次导入。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('前往权限设置'),
                onPressed: () => PermissionService.openSettings(),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('读取手机通讯录'),
              onPressed: _loadContacts,
            ),
          ],
        ),
      ),
    );
  }
}
