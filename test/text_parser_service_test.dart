import 'package:flutter_test/flutter_test.dart';
import 'package:contacts_importer/services/text_parser_service.dart';

void main() {
  group('TextParserService Tests', () {
    test('should parse standard tab-separated string', () {
      const input = '张三\t13800138000\t技术研发部\t高级架构师';
      final list = TextParserService.parseText(input);

      expect(list.length, 1);
      expect(list.first.name, '张三');
      expect(list.first.phone, '13800138000');
      expect(list.first.department, '技术研发部');
      expect(list.first.title, '高级架构师');
    });

    test('should handle +86 and dashes in phone number with comma delimiter', () {
      const input = '李四, +86 139-1234-5678, 市场运营部, 运营总监';
      final list = TextParserService.parseText(input);

      expect(list.length, 1);
      expect(list.first.name, '李四');
      expect(list.first.phone, '13912345678');
      expect(list.first.department, '市场运营部');
      expect(list.first.title, '运营总监');
    });

    test('should tolerate field reordering via keyword intelligence', () {
      // 部门在前，人名在后
      const input = '财务部 王五 13788889999 会计主管';
      final list = TextParserService.parseText(input);

      expect(list.length, 1);
      expect(list.first.name, '王五');
      expect(list.first.phone, '13788889999');
      expect(list.first.department, '财务部');
      expect(list.first.title, '会计主管');
    });

    test('should handle minimal input with name and phone only', () {
      const input = '赵六 13611112222';
      final list = TextParserService.parseText(input);

      expect(list.length, 1);
      expect(list.first.name, '赵六');
      expect(list.first.phone, '13611112222');
      expect(list.first.department, '');
      expect(list.first.title, '');
    });

    test('should ignore empty lines and lines without valid phone number', () {
      const input = '''
        
        通知：请各部门查收小号
        孙七 13500001111
        
        无电话测试人员
        周八 13422223333 客服部
      ''';
      final list = TextParserService.parseText(input);

      expect(list.length, 2);
      expect(list[0].name, '孙七');
      expect(list[0].phone, '13500001111');
      expect(list[1].name, '周八');
      expect(list[1].phone, '13422223333');
      expect(list[1].department, '客服部');
    });
  });
}
