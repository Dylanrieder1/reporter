import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/column_mapping.dart';
import '../models/raw_contact_data.dart';
import '../services/excel_parser_service.dart';
import '../services/text_parser_service.dart';
import 'export_page.dart';
import 'delete_page.dart';
import 'preview_page.dart';

/// 首页：双通道（表格文件选择 & 剪贴板文本粘贴）
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- 表格模式状态 ---
  bool _isFileLoading = false;
  ParsedTableResult? _tableResult;
  ColumnMapping _columnMapping = ColumnMapping();
  String? _fileError;

  // --- 剪贴板模式状态 ---
  final TextEditingController _textController = TextEditingController();
  List<RawContactData> _parsedTextContacts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final contacts = TextParserService.parseText(_textController.text);
    setState(() {
      _parsedTextContacts = contacts;
    });
  }

  // --- 表格选择与解析 ---
  Future<void> _pickTableFile() async {
    setState(() {
      _isFileLoading = true;
      _fileError = null;
    });

    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'xls', 'csv'],
          withData: false,
        );
      } catch (err) {
        // 部分 Android OEM ROM 对 custom MIME types 支持有兼容问题，降级为 any 文件选择
        debugPrint('FileType.custom 异常，降级至 FileType.any: $err');
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          withData: false,
        );
      }

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      Uint8List? bytes = file.bytes;

      if (bytes == null && file.path != null) {
        final ioFile = File(file.path!);
        if (await ioFile.exists()) {
          bytes = await ioFile.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception('未能获取到文件数据，请确认文件路径有效或重新选择');
      }

      final parsed = await ExcelParserService.parseFileBytes(bytes, file.name);
      setState(() {
        _tableResult = parsed;
        _columnMapping = parsed.mapping;
      });
    } catch (e) {
      setState(() {
        _fileError = '选择/解析文件失败: $e\n提示：若为旧版 .xls 格式，请另存为 .xlsx 或 .csv，或使用“剪贴板粘贴”通道导入。';
      });
    } finally {
      if (mounted) {
        setState(() => _isFileLoading = false);
      }
    }
  }

  // 从剪贴板粘贴
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      _textController.text = data.text!;
    }
  }

  // 导航到预览核对页
  void _navigateToPreview(List<RawContactData> contacts) {
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无解析出的联系人数据')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreviewPage(rawContacts: contacts),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通讯录导入助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '使用指南',
            onPressed: _showHelpSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.table_chart), text: '表格导入'),
            Tab(icon: Icon(Icons.content_paste), text: '文本粘贴'),
            Tab(icon: Icon(Icons.file_upload_outlined), text: '导出 Excel'),
            Tab(icon: Icon(Icons.manage_accounts), text: '通讯录管理'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFileTab(),
          _buildClipboardTab(),
          const ExportPage(),
          const DeletePage(),
        ],
      ),
    );
  }

  /// 首页使用指南（底部弹层）
  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('使用指南',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _helpItem('1', '表格导入：选择 Excel/CSV → 核对列匹配 → 预览页搜索筛选（如"云中台"）→ 勾选要导入的联系人 → 导入所选'),
              _helpItem('2', '文本粘贴：粘贴多行文本（微信/钉钉复制）→ 自动识别 → 进入预览核对'),
              _helpItem('3', '导出 Excel：读取手机通讯录 → 勾选 → 导出为表格，可再通过表格导入导回'),
              _helpItem('4', '通讯录管理：搜索筛选 → 勾选 → 批量删除手机中的联系人（有二次确认）'),
              const Divider(height: 20),
              _helpItem('提示', '预览页默认不勾选，勾选状态在搜索/筛选切换时保留；支持公司小号（3~8 位短号）；导入完成后可"继续选择导入"处理剩余联系人'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('我知道了'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpItem(String tag, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(tag,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: 表格文件 ---
  Widget _buildFileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: InkWell(
            onTap: _isFileLoading ? null : _pickTableFile,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Column(
                children: [
                  Icon(
                    Icons.upload_file,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _tableResult == null ? '点击选择本地 Excel (.xlsx/.xls) 或 CSV' : '已选择: ${_tableResult!.fileName}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tableResult == null ? '支持自动识别表头，列顺序随意' : '共检测到 ${_tableResult!.rows.length} 行数据',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_isFileLoading) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ],

        if (_fileError != null) ...[
          const SizedBox(height: 12),
          Text(_fileError!, style: const TextStyle(color: Colors.red)),
        ],

        if (_tableResult != null) ...[
          const SizedBox(height: 20),
          const Text('表头列匹配设置 (若自动匹配有误可在此手动调整):', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildDropdown('姓名列 (*必填)', _columnMapping.nameIndex, (val) {
            setState(() => _columnMapping.nameIndex = val ?? -1);
          }),
          _buildDropdown('手机号列 (*必填)', _columnMapping.phoneIndex, (val) {
            setState(() => _columnMapping.phoneIndex = val ?? -1);
          }),
          _buildDropdown('部门列 (可选)', _columnMapping.deptIndex, (val) {
            setState(() => _columnMapping.deptIndex = val ?? -1);
          }),
          _buildDropdown('职位列 (可选)', _columnMapping.titleIndex, (val) {
            setState(() => _columnMapping.titleIndex = val ?? -1);
          }),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('进入预览核对'),
            onPressed: () {
              final contacts = ExcelParserService.extractRows(
                _tableResult!.rows,
                _columnMapping,
                hasHeader: true,
              );
              _navigateToPreview(contacts);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDropdown(String label, int selectedIndex, ValueChanged<int?> onChanged) {
    final headers = _tableResult?.headers ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: (selectedIndex >= 0 && selectedIndex < headers.length) ? selectedIndex : null,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              hint: const Text('请选择对应列'),
              items: List.generate(headers.length, (idx) {
                return DropdownMenuItem<int>(
                  value: idx,
                  child: Text('第${idx + 1}列: ${headers[idx]}'),
                );
              }),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: 剪贴板文本粘贴 ---
  Widget _buildClipboardTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('粘贴多行文本 (微信/钉钉等复制)', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.paste, size: 18),
                  label: const Text('粘贴'),
                  onPressed: _pasteFromClipboard,
                ),
                TextButton(
                  child: const Text('清空'),
                  onPressed: () => _textController.clear(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _textController,
          maxLines: 10,
          decoration: InputDecoration(
            hintText: '示例格式（制表符/空格/逗号分隔）：\n张三 13800138000 研发部 架构师\n李四, 13912345678, 市场部, 运营总监\n王五 13788889999',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已智能识别: ${_parsedTextContacts.length} 条数据',
              style: TextStyle(
                color: _parsedTextContacts.isNotEmpty ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: const Icon(Icons.arrow_forward),
          label: Text('进入预览核对 (${_parsedTextContacts.length}条)'),
          onPressed: _parsedTextContacts.isNotEmpty
              ? () => _navigateToPreview(_parsedTextContacts)
              : null,
        ),
      ],
    );
  }
}
