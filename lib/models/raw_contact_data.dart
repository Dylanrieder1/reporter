/// 原始解析联系人数据
class RawContactData {
  final String name;
  final String phone;
  final String department;
  final String title;

  const RawContactData({
    required this.name,
    required this.phone,
    this.department = '',
    this.title = '',
  });

  /// 快速复制
  RawContactData copyWith({
    String? name,
    String? phone,
    String? department,
    String? title,
  }) {
    return RawContactData(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      title: title ?? this.title,
    );
  }

  /// 判断是否完全为空
  bool get isEmpty =>
      name.trim().isEmpty &&
      phone.trim().isEmpty &&
      department.trim().isEmpty &&
      title.trim().isEmpty;

  /// 清洗后的纯数字手机号（去除空格、连字符及+86）
  String get sanitizedPhone {
    String p = phone.replaceAll(RegExp(r'[\s\-—_()]'), '');
    if (p.startsWith('+86')) {
      p = p.substring(3);
    } else if (p.startsWith('0086')) {
      p = p.substring(4);
    } else if (p.startsWith('86') && p.length > 11) {
      p = p.substring(2);
    }
    return p;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'department': department,
      'title': title,
    };
  }

  factory RawContactData.fromMap(Map<String, dynamic> map) {
    return RawContactData(
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      department: map['department']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
    );
  }

  @override
  String toString() =>
      'RawContactData(name: $name, phone: $phone, dept: $department, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RawContactData &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          phone == other.phone &&
          department == other.department &&
          title == other.title;

  @override
  int get hashCode =>
      name.hashCode ^ phone.hashCode ^ department.hashCode ^ title.hashCode;
}
