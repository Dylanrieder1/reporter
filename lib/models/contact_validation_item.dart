import 'raw_contact_data.dart';

/// 校验状态枚举
enum ValidationStatus {
  /// 校验通过，可以正常导入
  valid,

  /// 手机号在手机通讯录或批次中已存在
  skippedDuplicatePhone,

  /// 姓名在手机通讯录中已存在
  skippedDuplicateName,

  /// 手机号不合法（非11位大陆号码）
  skippedInvalidPhone,

  /// 姓名为空
  skippedEmptyName,
}

/// 经过查重与校验后的联系人条目
class ContactValidationItem {
  final RawContactData raw;
  final ValidationStatus status;
  final String formattedDisplayName;

  const ContactValidationItem({
    required this.raw,
    required this.status,
    required this.formattedDisplayName,
  });

  bool get isValid => status == ValidationStatus.valid;

  /// 跳过原因中文提示
  String get statusDescription {
    switch (status) {
      case ValidationStatus.valid:
        return '就绪';
      case ValidationStatus.skippedDuplicatePhone:
        return '号码已存在';
      case ValidationStatus.skippedDuplicateName:
        return '姓名已存在';
      case ValidationStatus.skippedInvalidPhone:
        return '号码格式异常';
      case ValidationStatus.skippedEmptyName:
        return '姓名缺失';
    }
  }

  ContactValidationItem copyWith({
    RawContactData? raw,
    ValidationStatus? status,
    String? formattedDisplayName,
  }) {
    return ContactValidationItem(
      raw: raw ?? this.raw,
      status: status ?? this.status,
      formattedDisplayName: formattedDisplayName ?? this.formattedDisplayName,
    );
  }

  @override
  String toString() =>
      'ContactValidationItem(name: $formattedDisplayName, phone: ${raw.phone}, status: $status)';
}
