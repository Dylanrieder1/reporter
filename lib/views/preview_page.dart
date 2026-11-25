import 'package:flutter/material.dart';
import '../models/contact_validation_item.dart';
import '../models/raw_contact_data.dart';
import '../services/contact_validator.dart';
import '../services/contacts_service.dart';
import '../services/permission_service.dart';
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

  // 搜索筛选（如输入"云中台"只看该部门的联系人）
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  Set<String> _existingPhones = {};
  Set<String> _existingNames = {};
  List<ContactValidationItem> _items = [];

  // 手动勾选：记录用户选中条目在 _items 中的下标（跨筛选/搜索保留）
  final Set<int> _selectedIndexes = {};

  @override
  void initState() {
    super.initState();
    _service = widget.contactsService ?? ContactsService();
    _loadExistingContactsAndValidate();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingContactsAndValidate() async {
    try {
      final cache = await _service.fetchExistingContacts();
      _existingPhones = cache.phones;
      _existingNames = cache.names;
    } catch (e) {
      // 若获取系统已有通讯录失败（如暂未授权或 OEM 限制），降级为空集，保证列表正常展示
      debugPrint('获取系统已有联系人失败（优雅降级）: $e');
      _existingPhones = {};
      _existingNames = {};
    } finally {
      if (mounted) {
        _recomputeValidation();
        setState(() => _isLoading = false);
      }
    }
  }

  void _recomputeValidation() {
    _items = ContactValidator.validate(
      rawList: widget.rawContacts,
      existingPhones: _existingPhones,
      existingNames: _existingNames,
      appendDeptTitleToName: _appendDeptTitle,
    );
    // 默认不预选任何条目：由用户自行勾选要导入的联系人。
    // 重算校验（如切换来电显示开关）时保留用户已勾选状态（下标与 rawList 一一对应）。
  }

  void _toggleItemSelection(int index) {
    setState(() {
      if (_selectedIndexes.contains(index)) {
        _selectedIndexes.remove(index);
      } else {
        _selectedIndexes.add(index);
      }
    });
  }

  void _toggleAppendDeptTitle(bool value) {
    setState(() {
      _appendDeptTitle = value;
      _recomputeValidation();
    });
  }

  /// 当前可见条目 = 状态筛选（全部/待导入/已跳过） ∩ 关键字搜索
  List<ContactValidationItem> get _filteredItems {
    Iterable<ContactValidationItem> items = _items;
    if (_selectedFilterIndex == 1) {
      items = items.where((e) => e.isValid);
    } else if (_selectedFilterIndex == 2) {
      items = items.where((e) => !e.isValid);
    }

    final kw = _searchKeyword.trim().toLowerCase();
    if (kw.isNotEmpty) {
      items = items.where((e) {
        final raw = e.raw;
        return raw.name.toLowerCase().contains(kw) ||
            e.formattedDisplayName.toLowerCase().contains(kw) ||
            raw.department.toLowerCase().contains(kw) ||
            raw.title.toLowerCase().contains(kw) ||
            raw.phone.contains(kw);
      });
    }
    return items.toList();
  }

  /// 当前筛选范围内可导入的条目
  List<ContactValidationItem> get _importableVisibleItems =>
      _filteredItems.where((e) => e.isValid).toList();

  /// 用户勾选的有效条目（按下标顺序，跨筛选保留）
  List<ContactValidationItem> get _selectedValidItems => <ContactValidationItem>[
        for (int i = 0; i < _items.length; i++)
          if (_selectedIndexes.contains(i) && _items[i].isValid) _items[i],
      ];

  Future<void> _startImport() async {
    final validItems = _selectedValidItems;
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先勾选要导入的联系人')),
      );
      return;
    }

    // 申请写入权限
    final hasPerm = await _service.requestPermission();
    if (!hasPerm) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('需要通讯录写入权限'),
          content: const Text('导入联系人需要访问系统通讯录权限，以将手机小号及姓名部门写入手机。\n\n请在系统权限设置中允许本应用读写通讯录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await PermissionService.openSettings();
              },
              child: const Text('前往设置'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    try {
      // 跳过数 = 全部条目 - 本次实际导入的条目（含校验跳过与未勾选的有效条目）
      final skippedCount = _items.length - validItems.length;
      final stream = _service.importContactsStream(validItems);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ImportProgressDialog(
          progressStream: stream,
          totalCount: validItems.length,
          skippedCount: skippedCount,
          onFinish: () {
            if (mounted) Navigator.of(context).pop(); // 返回主页
          },
          onContinueImport: () {
            // 留在预览页并重新查重：刚导入的条目会标记为"号码已存在"，
            // 用户可继续筛选/勾选导入剩余联系人，无需重新选文件粘贴
            if (mounted) _loadExistingContactsAndValidate();
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('启动写入出现异常: $e')),
      );
    }
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

                // 1.5 搜索筛选框（按姓名/部门/职位/号码过滤，只导入筛选结果）
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchKeyword = v),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchKeyword.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchKeyword = '');
                              },
                            ),
                      hintText: '搜索筛选：姓名 / 部门 / 职位 / 号码（如：云中台），可勾选后导入',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
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

                // 3.5 手动勾选控制行：跨筛选保留，"选当前筛选"可一键勾选可见的有效条目
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    children: [
                      Icon(Icons.checklist, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text(
                        '已选 ${_selectedValidItems.length} / $validCount 条',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800),
                      ),
                      const Spacer(),
                      TextButton(
                        child: const Text('选当前筛选', style: TextStyle(fontSize: 13)),
                        onPressed: () {
                          setState(() {
                            for (final e in _importableVisibleItems) {
                              _selectedIndexes.add(_items.indexOf(e));
                            }
                          });
                        },
                      ),
                      TextButton(
                        child: const Text('清空选择', style: TextStyle(fontSize: 13)),
                        onPressed: _selectedIndexes.isEmpty
                            ? null
                            : () => setState(() => _selectedIndexes.clear()),
                      ),
                    ],
                  ),
                ),
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
                      child: Builder(builder: (ctx) {
                        final selectedValidCount = _selectedValidItems.length;
                        return FilledButton.icon(
                          icon: const Icon(Icons.contacts),
                          label: Text('导入所选 ($selectedValidCount 条)'),
                          onPressed: selectedValidCount > 0
                              ? _startImport
                              : null,
                        );
                      }),
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
    final itemIndex = _items.indexOf(item);
    final bool selected = _selectedIndexes.contains(itemIndex);
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

    return InkWell(
      onTap: item.isValid ? () => _toggleItemSelection(itemIndex) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 勾选框：仅有效条目可选；勾选状态跨筛选/搜索保留
            Checkbox(
              value: item.isValid && selected,
              tristate: false,
              onChanged: item.isValid
                  ? (_) => _toggleItemSelection(itemIndex)
                  : null,
            ),
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
      ),
    );
  }
}
