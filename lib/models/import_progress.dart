/// 导入实时进度
class ImportProgress {
  final int current;
  final int total;
  final String currentName;

  /// 截至当前已确认写入成功的条数
  final int successCount;

  /// 截至当前写入失败的条数（绝不静默吞掉）
  final int failedCount;

  /// 最近一次写入失败的失败原因（用于 UI 展示与排查）
  final String lastError;

  const ImportProgress({
    required this.current,
    required this.total,
    this.currentName = '',
    this.successCount = 0,
    this.failedCount = 0,
    this.lastError = '',
  });

  double get ratio => total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);
  int get percentage => (ratio * 100).toInt();

  @override
  String toString() =>
      'ImportProgress($current/$total, $percentage%, success: $successCount, failed: $failedCount)';
}
