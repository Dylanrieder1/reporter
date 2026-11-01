import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contacts_importer/main.dart';
import 'package:contacts_importer/views/preview_page.dart';
import 'package:contacts_importer/models/raw_contact_data.dart';
import 'package:contacts_importer/services/contacts_service.dart';

void main() {
  testWidgets('ContactsImporterApp smoke test & tabs display', (WidgetTester tester) async {
    await tester.pumpWidget(const ContactsImporterApp());

    // 检查首页标题与标签页
    expect(find.text('通讯录导入助手'), findsOneWidget);
    expect(find.text('Excel/CSV 表格导入'), findsOneWidget);
    expect(find.text('剪贴板文本粘贴'), findsOneWidget);
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

    await tester.pumpAndSettle();

    // 检查页面元素
    expect(find.text('导入核对与预览'), findsOneWidget);
    expect(find.text('来电显示优化（姓名附加部门/职务）'), findsOneWidget);
    expect(find.text('张三-研发部-架构师'), findsOneWidget);
    expect(find.text('就绪'), findsOneWidget);
  });
}
