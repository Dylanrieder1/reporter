/// 最终导入完成结果统计
class ImportSummary {
  final int totalParsed;
  final int validCount;
  final int successCount;
  final int skippedCount;
  final List<String> skipReasons;

  const ImportSummary({
    required this.totalParsed,
    required this.validCount,
    required this.successCount,
    required this.skippedCount,
    this.skipReasons = const [],
  });

  @override
  String toString() =>
      'ImportSummary(parsed: $totalParsed, valid: $validCount, success: $successCount, skipped: $skippedCount)';
}
