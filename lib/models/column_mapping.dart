/// 表格列映射关系
class ColumnMapping {
  int nameIndex;
  int phoneIndex;
  int deptIndex;
  int titleIndex;

  ColumnMapping({
    this.nameIndex = -1,
    this.phoneIndex = -1,
    this.deptIndex = -1,
    this.titleIndex = -1,
  });

  /// 姓名和手机号是核心必选列
  bool get isValid => nameIndex >= 0 && phoneIndex >= 0;

  ColumnMapping copyWith({
    int? nameIndex,
    int? phoneIndex,
    int? deptIndex,
    int? titleIndex,
  }) {
    return ColumnMapping(
      nameIndex: nameIndex ?? this.nameIndex,
      phoneIndex: phoneIndex ?? this.phoneIndex,
      deptIndex: deptIndex ?? this.deptIndex,
      titleIndex: titleIndex ?? this.titleIndex,
    );
  }

  @override
  String toString() =>
      'ColumnMapping(name: $nameIndex, phone: $phoneIndex, dept: $deptIndex, title: $titleIndex)';
}
