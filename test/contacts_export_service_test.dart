import 'package:flutter_test/flutter_test.dart';
import 'package:contacts_importer/models/device_contact.dart';
import 'package:contacts_importer/services/contacts_export_service.dart';
import 'package:excel/excel.dart';

/// 空安全读取单元格文本
String cellText(dynamic cell) {
  final v = cell?.value;
  return v == null ? '' : v.toString();
}

void main() {
  group('ContactsExportService Excel export tests', () {
    test('buildExcelBytes generates header compatible with importer', () {
      final bytes = ContactsExportService.buildExcelBytes(const [
        DeviceContact(
          displayName: '张三',
          phone: '13800000000',
          department: '研发部',
          title: '架构师',
        ),
        DeviceContact(displayName: '李四', phone: '13900000000'),
        DeviceContact(displayName: '', phone: '13700000000'),
      ]);

      expect(bytes, isNotEmpty);

      // 解码回读验证内容
      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables, isNotEmpty);

      final rows = excel.tables.values.first.rows;
      // 1 表头 + 3 数据行
      expect(rows.length, 4);

      // 表头四列（与导入通道 detectHeaderMapping 的关键词完全兼容）
      final header = rows[0].map(cellText).toList();
      expect(header[0], contains('姓名'));
      expect(header[1], contains('手机号'));
      expect(header[2], contains('部门'));
      expect(header[3], contains('职位'));

      // 第一条数据行
      expect(cellText(rows[1][0]), contains('张三'));
      expect(cellText(rows[1][1]), contains('13800000000'));
      expect(cellText(rows[1][2]), contains('研发部'));
      expect(cellText(rows[1][3]), contains('架构师'));

      // 第二条：部门/职位为空
      expect(cellText(rows[2][0]), contains('李四'));
      expect(cellText(rows[2][1]), contains('13900000000'));

      // 第三条：姓名为空但手机号保留
      expect(cellText(rows[3][0]), isNot(contains('13700000000')));
      expect(cellText(rows[3][1]), contains('13700000000'));
    });

    test('buildExcelBytes with empty list still yields header-only workbook', () {
      final bytes = ContactsExportService.buildExcelBytes(const []);
      final excel = Excel.decodeBytes(bytes);
      final rows = excel.tables.values.first.rows;
      expect(rows.length, 1);
      expect(cellText(rows[0][0]), contains('姓名'));
    });

    test('defaultFileName matches expected pattern', () {
      final name = ContactsExportService.defaultFileName();
      expect(name, startsWith('通讯录导出_'));
      expect(name, endsWith('.xlsx'));
    });
  });
}
