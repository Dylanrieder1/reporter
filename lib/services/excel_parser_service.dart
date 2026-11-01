import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../models/column_mapping.dart';
import '../models/raw_contact_data.dart';

/// 表格解析结果包装
class ParsedTableResult {
  final String fileName;
  final List<String> headers;
  final List<List<dynamic>> rows;
  final ColumnMapping mapping;

  const ParsedTableResult({
    required this.fileName,
    required this.headers,
    required this.rows,
    required this.mapping,
  });
}

/// Excel 与 CSV 表格解析及智能表头识别服务
class ExcelParserService {
  /// 姓名列关键词权重
  static const List<String> _nameKeywords = [
    '姓名', '名字', '联系人', '员工姓名', '人员', '成员', 'name', 'user'
  ];

  /// 手机号列关键词权重
  static const List<String> _phoneKeywords = [
    '手机', '电话', '小号', '手机小号', '联系电话', '移动电话', '号码', 'phone', 'mobile', 'tel'
  ];

  /// 部门列关键词权重
  static const List<String> _deptKeywords = [
    '部门', '科室', '机构', '单位', '所属部门', '团队', '组别', 'department', 'dept', 'team'
  ];

  /// 职位列关键词权重
  static const List<String> _titleKeywords = [
    '职位', '职务', '岗位', '工种', '职称', 'title', 'position', 'post', 'role'
  ];

  /// 智能推断表头列映射关系
  static ColumnMapping detectHeaderMapping(List<String> headers) {
    int nameIdx = -1;
    int phoneIdx = -1;
    int deptIdx = -1;
    int titleIdx = -1;

    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].trim().toLowerCase();
      if (header.isEmpty) continue;

      if (nameIdx == -1 && _matchesKeyword(header, _nameKeywords)) {
        nameIdx = i;
      } else if (phoneIdx == -1 && _matchesKeyword(header, _phoneKeywords)) {
        phoneIdx = i;
      } else if (deptIdx == -1 && _matchesKeyword(header, _deptKeywords)) {
        deptIdx = i;
      } else if (titleIdx == -1 && _matchesKeyword(header, _titleKeywords)) {
        titleIdx = i;
      }
    }

    // 若未能识别核心列，且总列数合适，尝试按默认顺序退化兜底
    if (nameIdx == -1 && headers.isNotEmpty) {
      nameIdx = 0;
    }
    if (phoneIdx == -1 && headers.length > 1) {
      phoneIdx = 1;
    }
    if (deptIdx == -1 && headers.length > 2) {
      deptIdx = 2;
    }
    if (titleIdx == -1 && headers.length > 3) {
      titleIdx = 3;
    }

    return ColumnMapping(
      nameIndex: nameIdx,
      phoneIndex: phoneIdx,
      deptIndex: deptIdx,
      titleIndex: titleIdx,
    );
  }

  static bool _matchesKeyword(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// 根据映射关系从二维数据行中提取 Contact 列表
  static List<RawContactData> extractRows(
    List<List<dynamic>> rows,
    ColumnMapping mapping, {
    bool hasHeader = true,
  }) {
    final List<RawContactData> contacts = [];
    final startIndex = hasHeader ? 1 : 0;

    for (int i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      String getCell(int idx) {
        if (idx < 0 || idx >= row.length) return '';
        final val = row[idx];
        return val == null ? '' : val.toString().trim();
      }

      final name = getCell(mapping.nameIndex);
      final phone = getCell(mapping.phoneIndex);
      final dept = getCell(mapping.deptIndex);
      final title = getCell(mapping.titleIndex);

      final contact = RawContactData(
        name: name,
        phone: phone,
        department: dept,
        title: title,
      );

      // 只要有一项不全为空即录入
      if (!contact.isEmpty) {
        contacts.add(contact);
      }
    }

    return contacts;
  }

  /// 从文件字节流解析表格内容
  static Future<ParsedTableResult> parseFileBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.csv')) {
      return _parseCsvBytes(bytes, fileName);
    } else if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xls')) {
      return _parseExcelBytes(bytes, fileName);
    } else {
      throw FormatException('不支持的文件格式，仅支持 .xlsx, .xls, .csv: $fileName');
    }
  }

  static ParsedTableResult _parseCsvBytes(Uint8List bytes, String fileName) {
    // 优先尝试 utf-8 解码，失败则回退 gbk / latin1
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    final converter = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    );
    final rows = converter.convert(content);

    final headers = rows.isNotEmpty
        ? rows.first.map((e) => e.toString().trim()).toList()
        : <String>[];

    final mapping = detectHeaderMapping(headers);

    return ParsedTableResult(
      fileName: fileName,
      headers: headers,
      rows: rows,
      mapping: mapping,
    );
  }

  static ParsedTableResult _parseExcelBytes(Uint8List bytes, String fileName) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return ParsedTableResult(
        fileName: fileName,
        headers: [],
        rows: [],
        mapping: ColumnMapping(),
      );
    }

    // 默认取第一个非空工作表
    Sheet? targetSheet;
    for (final table in excel.tables.values) {
      if (table.maxRows > 0) {
        targetSheet = table;
        break;
      }
    }
    targetSheet ??= excel.tables.values.first;

    final List<List<dynamic>> rows = [];
    for (final excelRow in targetSheet.rows) {
      final rowData = excelRow.map((cell) => cell?.value?.toString() ?? '').toList();
      // 过滤整行全空
      if (rowData.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(rowData);
      }
    }

    final headers = rows.isNotEmpty
        ? rows.first.map((e) => e.toString().trim()).toList()
        : <String>[];

    final mapping = detectHeaderMapping(headers);

    return ParsedTableResult(
      fileName: fileName,
      headers: headers,
      rows: rows,
      mapping: mapping,
    );
  }
}
