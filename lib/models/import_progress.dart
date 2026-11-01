/// 导入实时进度
class ImportProgress {
  final int current;
  final int total;
  final String currentName;

  const ImportProgress({
    required this.current,
    required this.total,
    this.currentName = '',
  });

  double get ratio => total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);
  int get percentage => (ratio * 100).toInt();

  @override
  String toString() => 'ImportProgress($current/$total, $percentage%)';
}
