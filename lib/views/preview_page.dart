import 'package:flutter/material.dart';
import '../models/contact_validation_item.dart';
import '../models/raw_contact_data.dart';
import '../services/contact_validator.dart';
import '../services/contacts_service.dart';
import 'import_progress_dialog.dart';

/// 导入前预览与核对页面
class PreviewPage extends StatefulWidget {
  final List<RawContactData> rawContacts;
  final ContactsService? contactsService;

  const PreviewPage({
    super.key,
    required this.rawContacts,
    this.contactsService,
  });

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  late final ContactsService _service;
  bool _isLoading = true;
  bool _appendDeptTitle = true; // 默认开启来电显示优化
  int _selectedFilterIndex = 0; // 0: 全部, 1: 待导入, 2: 已跳过

  Set<String> _existingPhones = {};
  Set<String> _existingNames = {};
  List<ContactValidationItem> _items = [];

  @override
  void initState() {
    super.initState();
    _service = widget.contactsService ?? ContactsService();
    _loadExistingContactsAndValidate();
  }

  Future<void> _loadExistingContactsAndValidate() async {
    try {
      final cache = await _service.fetchExistingContacts();
      _existingPhones = cache.phones;
      _existingNames = cache.names;
    } catch (_) {
      // 若获取系统已有通讯录失败（如缺少权限），降级为空集
      _existingPhones = {};
      _existingNames = {};
    }

    _recomputeValidation();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _recomputeValidation() {
    _items = ContactValidator.validate(
      rawList: widget.rawContacts,
      existingPhones: _existingPhones,
      existingNames: _existingNames,
      appendDeptTitleToName: _appendDeptTitle,
    );
  }

  void _toggleAppendDeptTitle(bool value) {
    setState(() {
      _appendDeptTitle = value;
      _recomputeValidation();
    });
  }

  List<ContactValidationItem> get _filteredItems {
    if (_selectedFilterIndex == 1) {
      return _items.where((e) => e.isValid).toList();
    } else if (_selectedFilterIndex == 2) {
      return _items.where((e) => !e.isValid).toList();
    }
    return _items;
  }

  Future<void> _startImport() async {
    final validItems = _items.where((e) => e.isValid).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有有效待导入的联系人')),
      );
      return;
    }

    final hasPerm = await _service.requestPermission();
    if (!hasPerm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未获得通讯录写入权限，无法导入')),
      );
      return;
    }

    if (!mounted) return;

    final skippedCount = _items.length - validItems.length;
    final stream = _service.importContactsStream(validItems);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ImportProgressDialog(
        progressStream: stream,
        totalCount: validItems.length,
        skippedCount: skippedCount,
        onComplete: () {
          Navigator.of(context).pop(); // 返回主页
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _items.where((e) => e.isValid).length;
    final skippedCount = _items.length - validCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入核对与预览'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. 来电显示优化开关面板
                Container(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_in_talk, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '来电显示优化（姓名附加部门/职务）',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              _appendDeptTitle
                                  ? '示例：张三-技术部-架构师（推荐，来电直接看清部门）'
                                  : '仅保存原始姓名：张三（不修改姓名）',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _appendDeptTitle,
                        onChanged: _toggleAppendDeptTitle,
                      ),
                    ],
                  ),
                ),

                // 2. 统计状态栏
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _buildStatCard('总计解析', '${_items.length}', Colors.blue),
                      const SizedBox(width: 8),
                      _buildStatCard('就绪待导入', '$validCount', Colors.green),
                      const SizedBox(width: 8),
                      _buildStatCard('自动跳过', '$skippedCount', Colors.orange),
                    ],
                  ),
                ),

                // 3. 过滤分段标签
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text('全部 (${_items.length})')),
                      ButtonSegment(value: 1, label: Text('待导入 ($validCount)')),
                      ButtonSegment(value: 2, label: Text('已跳过 ($skippedCount)')),
                    ],
                    selected: {_selectedFilterIndex},
                    onSelectionChanged: (set) {
                      setState(() => _selectedFilterIndex = set.first);
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // 4. 联系人预览列表
                Expanded(
                  child: _filteredItems.isEmpty
                      ? const Center(child: Text('没有匹配的记录'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, index) {
                            final item = _filteredItems[index];
                            return _buildContactTile(item);
                          },
                        ),
                ),

                // 5. 底部导入操作按钮
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
                        icon: const Icon(Icons.contacts),
                        label: Text('开始写入系统通讯录 ($validCount 条)'),
                        onPressed: validCount > 0 ? _startImport : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(ContactValidationItem item) {
    final Color badgeColor;
    switch (item.status) {
      case ValidationStatus.valid:
        badgeColor = Colors.green;
        break;
      case ValidationStatus.skippedDuplicatePhone:
      case ValidationStatus.skippedDuplicateName:
        badgeColor = Colors.orange;
        break;
      case ValidationStatus.skippedInvalidPhone:
        badgeColor = Colors.red;
        break;
      case ValidationStatus.skippedEmptyName:
        badgeColor = Colors.grey;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: item.isValid ? Colors.blue.shade50 : Colors.grey.shade200,
            child: Text(
              item.raw.name.isNotEmpty ? item.raw.name.characters.first : '?',
              style: TextStyle(
                color: item.isValid ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.formattedDisplayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: item.isValid ? null : TextDecoration.lineThrough,
                    color: item.isValid ? Colors.black87 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.raw.phone} ${item.raw.department.isNotEmpty ? '· ${item.raw.department}' : ''} ${item.raw.title.isNotEmpty ? '· ${item.raw.title}' : ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor.withOpacity(0.5)),
            ),
            child: Text(
              item.statusDescription,
              style: TextStyle(fontSize: 12, color: badgeColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
