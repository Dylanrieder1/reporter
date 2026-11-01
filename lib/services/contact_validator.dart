import '../models/contact_validation_item.dart';
import '../models/raw_contact_data.dart';

/// 联系人严格查重与来电显示格式化校验引擎
class ContactValidator {
  /// 校验并生成带查重标记与格式化姓名的列表
  static List<ContactValidationItem> validate({
    required List<RawContactData> rawList,
    required Set<String> existingPhones,
    required Set<String> existingNames,
    required bool appendDeptTitleToName,
  }) {
    final List<ContactValidationItem> results = [];
    final Set<String> seenPhonesInBatch = {};
    final Set<String> seenNamesInBatch = {};

    // 预先清洗现有通讯录号码集合为标准格式
    final normalizedExistingPhones = existingPhones
        .map((p) => _normalizePhone(p))
        .where((p) => p.isNotEmpty)
        .toSet();

    final normalizedExistingNames = existingNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toSet();

    for (final raw in rawList) {
      final name = raw.name.trim();
      final cleanPhone = _normalizePhone(raw.phone);

      // 1. 生成最终展示姓名
      final formattedName = formatDisplayName(
        name: name,
        department: raw.department.trim(),
        title: raw.title.trim(),
        appendDeptTitle: appendDeptTitleToName,
      );

      // 2. 规则一：姓名不可为空
      if (name.isEmpty) {
        results.add(ContactValidationItem(
          raw: raw,
          status: ValidationStatus.skippedEmptyName,
          formattedDisplayName: formattedName,
        ));
        continue;
      }

      // 3. 规则二：电话合法性校验（中国大陆 11 位有效手机号）
      if (!_isValidMobile(cleanPhone)) {
        results.add(ContactValidationItem(
          raw: raw,
          status: ValidationStatus.skippedInvalidPhone,
          formattedDisplayName: formattedName,
        ));
        continue;
      }

      // 4. 规则三：严格跳过已存在手机号（手机通讯录已存）
      if (normalizedExistingPhones.contains(cleanPhone)) {
        results.add(ContactValidationItem(
          raw: raw,
          status: ValidationStatus.skippedDuplicatePhone,
          formattedDisplayName: formattedName,
        ));
        continue;
      }

      // 5. 规则四：严格跳过已存在姓名（手机通讯录已存）
      if (normalizedExistingNames.contains(name)) {
        results.add(ContactValidationItem(
          raw: raw,
          status: ValidationStatus.skippedDuplicateName,
          formattedDisplayName: formattedName,
        ));
        continue;
      }

      // 6. 规则五：当前导入批次内自身查重
      if (seenPhonesInBatch.contains(cleanPhone)) {
        results.add(ContactValidationItem(
          raw: raw,
          status: ValidationStatus.skippedDuplicatePhone,
          formattedDisplayName: formattedName,
        ));
        continue;
      }

      if (seenNamesInBatch.contains(name)) {
        results.add(ContactValidationItem(
          raw: raw,
          status: ValidationStatus.skippedDuplicateName,
          formattedDisplayName: formattedName,
        ));
        continue;
      }

      // 记录批次内已录入项
      seenPhonesInBatch.add(cleanPhone);
      seenNamesInBatch.add(name);

      // 校验全部通过
      results.add(ContactValidationItem(
        raw: raw.copyWith(phone: cleanPhone),
        status: ValidationStatus.valid,
        formattedDisplayName: formattedName,
      ));
    }

    return results;
  }

  /// 格式化最终展示姓名（来电优化开关控制）
  static String formatDisplayName({
    required String name,
    required String department,
    required String title,
    required bool appendDeptTitle,
  }) {
    if (!appendDeptTitle) {
      return name;
    }

    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (department.isNotEmpty) parts.add(department);
    if (title.isNotEmpty) parts.add(title);

    return parts.join('-');
  }

  /// 清洗号码格式
  static String _normalizePhone(String rawPhone) {
    String p = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('86') && p.length == 13) {
      p = p.substring(2);
    }
    return p;
  }

  /// 手机号合规判断
  static bool _isValidMobile(String phone) {
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
  }
}
