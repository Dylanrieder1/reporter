import 'package:flutter/material.dart';
import '../models/import_progress.dart';
import '../models/import_summary.dart';

/// 实时写入进度与完成结果弹窗
class ImportProgressDialog extends StatefulWidget {
  final Stream<ImportProgress> progressStream;
  final int totalCount;
  final int skippedCount;
  final VoidCallback onComplete;

  const ImportProgressDialog({
    super.key,
    required this.progressStream,
    required this.totalCount,
    required this.skippedCount,
    required this.onComplete,
  });

  @override
  State<ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<ImportProgressDialog> {
  int _current = 0;
  String _currentName = '';
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    widget.progressStream.listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _current = progress.current;
          _currentName = progress.currentName;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('写入发生异常: $err')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double ratio = widget.totalCount == 0
        ? 1.0
        : (_current / widget.totalCount).clamp(0.0, 1.0);
    final percentage = (ratio * 100).toInt();

    return PopScope(
      canPop: _isFinished,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _isFinished ? Icons.check_circle : Icons.sync,
              color: _isFinished ? Colors.green : Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Text(_isFinished ? '导入完成' : '正在写入通讯录'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isFinished) ...[
              LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('进度: $_current / ${widget.totalCount}'),
                  Text('$percentage%', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              if (_currentName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '写入中: $_currentName',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✅ 成功导入: $_current 条',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '⏭️ 自动跳过: ${widget.skippedCount} 条 (已存在或无效)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_isFinished)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onComplete();
              },
              child: const Text('完成并返回'),
            ),
        ],
      ),
    );
  }
}
