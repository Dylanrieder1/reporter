import 'package:flutter_test/flutter_test.dart';
import 'package:contacts_importer/services/excel_parser_service.dart';

void main() {
  group('ExcelParserService Tests', () {
    test('should intelligently detect standard Chinese headers', () {
      final headers = ['员工姓名', '联系电话', '所属部门', '岗位职称'];
      final mapping = ExcelParserService.detectHeaderMapping(headers);

      expect(mapping.nameIndex, 0);
      expect(mapping.phoneIndex, 1);
      expect(mapping.deptIndex, 2);
      expect(mapping.titleIndex, 3);
      expect(mapping.isValid, isTrue);
    });

    test('should detect headers in reverse order', () {
      final headers = ['部门', '职位', '手机小号', '姓名'];
      final mapping = ExcelParserService.detectHeaderMapping(headers);

      expect(mapping.deptIndex, 0);
      expect(mapping.titleIndex, 1);
      expect(mapping.phoneIndex, 2);
      expect(mapping.nameIndex, 3);
      expect(mapping.isValid, isTrue);
    });

    test('should fallback to default indices when headers are unknown', () {
      final headers = ['Col_A', 'Col_B', 'Col_C', 'Col_D'];
      final mapping = ExcelParserService.detectHeaderMapping(headers);

      expect(mapping.nameIndex, 0);
      expect(mapping.phoneIndex, 1);
      expect(mapping.deptIndex, 2);
      expect(mapping.titleIndex, 3);
    });

    test('should extract rows cleanly using mapping', () {
      final headers = ['姓名', '手机', '部门', '职位'];
      final mapping = ExcelParserService.detectHeaderMapping(headers);

      final rows = [
        ['姓名', '手机', '部门', '职位'],
        ['张三', '13800000000', '技术部', '开发'],
        ['李四', '13911112222', '销售部', '销售代表'],
        ['', '', '', ''], // 空行应忽略
      ];

      final contacts = ExcelParserService.extractRows(rows, mapping);
      expect(contacts.length, 2);
      expect(contacts[0].name, '张三');
      expect(contacts[0].phone, '13800000000');
      expect(contacts[1].name, '李四');
      expect(contacts[1].phone, '13911112222');
    });
  });
}
