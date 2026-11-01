import '../models/raw_contact_data.dart';

/// 剪贴板与多行文本智能切分与解析服务
class TextParserService {
  /// 匹配中国大陆手机号的正则（兼容前缀 +86/0086、连字符 -、空格等）
  static final RegExp _phoneRegex = RegExp(
    r'(?:(?:\+|00)?86[\s\-]?)?1[3-9]\d[\s\-]?\d{4}[\s\-]?\d{4}',
  );

  /// 常见部门关键词
  static final RegExp _deptKeywordRegex = RegExp(
    r'部|科|组|中心|院|所|室|局|处|行|馆|团队|部门|分公司|支行|team|dept',
    caseSensitive: false,
  );

  /// 常见职位/职务关键词
  static final RegExp _titleKeywordRegex = RegExp(
    r'经理|总监|工程师|专员|主管|顾问|架构师|助理|会计|HR|开发|设计|运营|测试|运维|组长|主任|书记|部长|负责人|总管|CEO|CTO|COO|CFO|VP|合伙人|实习生|专家|研究员',
    caseSensitive: false,
  );

  /// 核心解析接口：将多行文本解析为 RawContactData 列表
  static List<RawContactData> parseText(String input) {
    if (input.trim().isEmpty) return [];

    final lines = input.split(RegExp(r'\r?\n'));
    final List<RawContactData> results = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final contact = _parseSingleLine(line);
      if (contact != null) {
        results.add(contact);
      }
    }

    return results;
  }

  /// 单行解析逻辑
  static RawContactData? _parseSingleLine(String line) {
    // 1. 查找手机号
    final match = _phoneRegex.firstMatch(line);
    if (match == null) {
      // 若该行无手机号，尝试直接作为纯人名（若单行仅一个人名）或跳过
      return null;
    }

    final rawPhoneStr = match.group(0)!;
    // 清洗提取纯11位手机号
    final cleanDigits = rawPhoneStr.replaceAll(RegExp(r'\D'), '');
    String phone = cleanDigits;
    if (phone.startsWith('86') && phone.length == 13) {
      phone = phone.substring(2);
    }

    // 2. 将手机号从原文本中扣除，提取剩余文本部分
    final remainingText = line.replaceFirst(rawPhoneStr, ' ');

    // 3. 按照常见分隔符（制表符、逗号、中英文分号、竖线、连续空格）切分
    final rawTokens = remainingText
        .split(RegExp(r'[\t,，;；|/ ]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (rawTokens.isEmpty) {
      // 仅有手机号无姓名
      return RawContactData(name: '', phone: phone);
    }

    String name = '';
    String department = '';
    String title = '';

    final unassignedTokens = <String>[];

    // 4. 智能特征提取：利用关键词优先匹配部门与职位
    for (final token in rawTokens) {
      if (department.isEmpty && _deptKeywordRegex.hasMatch(token)) {
        department = token;
      } else if (title.isEmpty && _titleKeywordRegex.hasMatch(token)) {
        title = token;
      } else {
        unassignedTokens.add(token);
      }
    }

    // 5. 剩余 token 回填
    if (unassignedTokens.isNotEmpty) {
      name = unassignedTokens.removeAt(0);
    }

    if (department.isEmpty && unassignedTokens.isNotEmpty) {
      department = unassignedTokens.removeAt(0);
    }

    if (title.isEmpty && unassignedTokens.isNotEmpty) {
      title = unassignedTokens.removeAt(0);
    }

    return RawContactData(
      name: name,
      phone: phone,
      department: department,
      title: title,
    );
  }
}
