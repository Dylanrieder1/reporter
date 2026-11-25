import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contacts_importer/main.dart';
import 'package:contacts_importer/views/preview_page.dart';
import 'package:contacts_importer/models/raw_contact_data.dart';
import 'package:contacts_importer/services/contacts_service.dart';

void main() {
  testWidgets('ContactsImporterApp smoke test & tabs display', (WidgetTester tester) async {
    await tester.pumpWidget(const ContactsImporterApp());
    await tester.pump();

    // 检查首页标题与标签页
    expect(find.text('通讯录导入助手'), findsOneWidget);
    expect(find.text('表格导入'), findsOneWidget);
    expect(find.text('文本粘贴'), findsOneWidget);
    expect(find.text('导出 Excel'), findsOneWidget);
    expect(find.text('通讯录管理'), findsOneWidget);
  });

  testWidgets('PreviewPage displays incoming call switch and stats', (WidgetTester tester) async {
    final mockService = ContactsService(MockContactsProvider());
    final rawContacts = [
      const RawContactData(name: '张三', phone: '13800000000', department: '研发部', title: '架构师'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PreviewPage(
          rawContacts: rawContacts,
          contactsService: mockService,
        ),
      ),
    );

    // 步进帧以完成异步加载
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 检查页面元素
    expect(find.text('导入核对与预览'), findsOneWidget);
    expect(find.text('来电显示优化（姓名附加部门/职务）'), findsOneWidget);
    expect(find.text('张三-研发部-架构师'), findsOneWidget);
  });

  testWidgets('PreviewPage selection toggles update import button', (WidgetTester tester) async {
    final mockService = ContactsService(MockContactsProvider());
    final rawContacts = [
      const RawContactData(name: '张三', phone: '13800000000', department: '研发部', title: '架构师'),
      const RawContactData(name: '李四', phone: '13900000000', department: '云中台', title: '工程师'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PreviewPage(
          rawContacts: rawContacts,
          contactsService: mockService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 默认不选：按钮计数为 0（禁用状态）
    expect(find.text('导入所选 (0 条)'), findsOneWidget);

    // 勾选两条 → 按钮计数变为 2
    await tester.tap(find.text('张三-研发部-架构师'));
    await tester.pump();
    expect(find.text('导入所选 (1 条)'), findsOneWidget);
    await tester.tap(find.text('李四-云中台-工程师'));
    await tester.pump();
    expect(find.text('导入所选 (2 条)'), findsOneWidget);

    // 取消勾选张三 → 计数回落为 1
    await tester.tap(find.text('张三-研发部-架构师'));
    await tester.pump();
    expect(find.text('导入所选 (1 条)'), findsOneWidget);

    // 清空选择 → 按钮计数为 0（按钮禁用）
    await tester.tap(find.text('清空选择'));
    await tester.pump();
    expect(find.text('导入所选 (0 条)'), findsOneWidget);

    // "选当前筛选"一键勾选全部可见有效条目 → 恢复 2 条
    await tester.tap(find.text('选当前筛选'));
    await tester.pump();
    expect(find.text('导入所选 (2 条)'), findsOneWidget);
  });
}
