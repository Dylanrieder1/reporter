import 'package:flutter/material.dart';
import '../models/managed_contact.dart';
import '../services/contacts_service.dart';
import '../services/permission_service.dart';

/// 通讯录管理页：读取手机通讯录 → 搜索筛选 → 勾选 → 批量删除
class DeletePage extends StatefulWidget {
  const DeletePage({super.key});

  @override
  State<DeletePage> createState() => _DeletePageState();
}

class _DeletePageState extends State<DeletePage> {
  final ContactsService _service = ContactsService();
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  bool _isLoading = false;
  bool _isDeleting = false;
  int _processedInBatch = 0; // 本轮已处理的删除数
  int _batchTotal = 0; // 本轮待删除总数
  String? _error;
  List<ManagedContact> _contacts = [];
  // 勾选集（存 _contacts 下标，默认不选；跨搜索/筛选保留）
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchKeyword = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 当前可见条目 = 关键字过滤（姓名/电话/部门模糊匹配）
  List<ManagedContact> get _filteredContacts {
    final kw = _searchKeyword.trim().toLowerCase();
    if (kw.isEmpty) return _contacts;
    return _contacts.where((c) {
      return c.displayName.toLowerCase().contains(kw) ||
          c.phone.toLowerCase().contains(kw) ||
          c.department.toLowerCase().contains(kw);
    }).toList();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final contacts = await _service.fetchManagedContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _selected.clear(); // 重新读取后默认不选
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '读取通讯录失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleItem(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  /// 一键勾选当前筛选出的全部条目（无筛选时即全选）
  void _selectFiltered() {
    setState(() {
      for (final c in _filteredContacts) {
        _selected.add(_contacts.indexOf(c));
      }
    });
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty || _isDeleting) return;

    final targets = [for (final i in _selected.toList()..sort()) _contacts[i]];
    final count = targets.length;

    // 危险操作二次确认
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('确认删除'),
          ],
        ),
        content: Text(
          '即将从手机通讯录中删除 $count 位联系人：\n\n'
          '${targets.take(5).map((c) => c.displayName.isEmpty ? '(无姓名) ${c.phone}' : c.displayName).join('、')}'
          '${count > 5 ? ' 等 $count 位' : ''}\n\n'
          '删除后无法通过本应用恢复，请确认这些联系人不再需要。',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _processedInBatch = 0;
      _batchTotal = targets.length;
    });

    int success = 0;
    int failed = 0;
    String lastFailedName = '';

    for (final c in targets) {
      final ok = await _service.deleteContact(c.id);
      if (ok) {
        success++;
      } else {
        failed++;
        lastFailedName = c.displayName.isEmpty ? c.phone : c.displayName;
      }
      if (mounted) {
        setState(() => _processedInBatch = success + failed);
      }
    }

    if (!mounted) return;
    setState(() {
      _isDeleting = false;
      _selected.clear();
    });

    // 删除完成后刷新列表（已删除的联系人会从列表中消失）
    await _loadContacts();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failed == 0
            ? '✅ 已删除 $success 位联系人'
            : '⚠️ 已删除 $success 位，失败 $failed 位'
              '${lastFailedName.isNotEmpty ? '（如「$lastFailedName」，可能被系统账户保护）' : ''}'),
        duration: const Duration(seconds: 4),
        backgroundColor: failed == 0 ? Colors.green : Colors.orange.shade800,
      ),
    );
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
        // 搜索框（删除前精准定位，如输入部门名）
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchKeyword.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _searchController.clear,
                    ),
              hintText: '搜索：姓名 / 号码 / 部门',
              hintStyle: const TextStyle(fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
        ),

        // 计数与勾选控制行
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Text(
                '共 ${_contacts.length} 位 · '
                '${_searchKeyword.trim().isEmpty ? '' : '筛选出 ${_filteredContacts.length} 位 · '}'
                '已选 ${_selected.length}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              TextButton(
                child: const Text('选当前筛选', style: TextStyle(fontSize: 13)),
                onPressed: _selectFiltered,
              ),
              TextButton(
                child: const Text('清空选择', style: TextStyle(fontSize: 13)),
                onPressed:
                    _selected.isEmpty ? null : _clearSelection,
              ),
            ],
          ),
        ),

        Expanded(
          child: _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red)))
              : _filteredContacts.isEmpty
                  ? const Center(child: Text('没有匹配的联系人'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _filteredContacts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final c = _filteredContacts[index];
                        final itemIndex = _contacts.indexOf(c);
                        return CheckboxListTile(
                          value: _selected.contains(itemIndex),
                          onChanged: (_) => _toggleItem(itemIndex),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            c.displayName.isEmpty ? '(无姓名)' : c.displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          subtitle: Text(
                            '${c.phone.isNotEmpty ? c.phone : '无手机号'}'
                            '${c.department.isNotEmpty ? ' · ${c.department}' : ''}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                        );
                      },
                    ),
        ),

        // 底部删除按钮（红色危险操作 + 进度显示）
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
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                ),
                icon: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(_isDeleting
                    ? '正在删除 ($_processedInBatch / $_batchTotal)...'
                    : '删除所选 (${_selected.length} 位)'),
                onPressed:
                    _isDeleting || _selected.isEmpty ? null : _deleteSelected,
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
              Icons.manage_accounts,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              '通讯录批量管理',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '读取手机中的联系人，搜索筛选后勾选，\n批量删除不需要的联系人（删除前会二次确认）。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
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
