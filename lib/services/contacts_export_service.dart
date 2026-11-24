import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/device_contact.dart';

/// 手机通讯录读取与 Excel 导出服务
class ContactsExportService {
  /// 读取设备通讯录，转换为可导出联系人列表。
  /// 每个联系人取第一个可用手机号；部门/职位取第一个组织信息。
  static Future<List<DeviceContact>> loadDeviceContacts() async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      throw Exception('未获得通讯录读取权限，请在系统设置中允许后重试');
    }

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withAccounts: false,
    );

    final result = <DeviceContact>[];
    for (final c in contacts) {
      final name = c.displayName.trim();

      String phone = '';
      for (final p in c.phones) {
        final clean = p.number.replaceAll(RegExp(r'\D'), '');
        if (clean.isNotEmpty) {
          phone = clean;
          break;
        }
      }

      String dept = '';
      String title = '';
      if (c.organizations.isNotEmpty) {
        dept = c.organizations.first.department.trim();
        title = c.organizations.first.title.trim();
      }

      if (name.isEmpty && phone.isEmpty) continue;
      result.add(DeviceContact(
        displayName: name,
        phone: phone,
        department: dept,
        title: title,
      ));
    }

    return result;
  }

  /// 将所选联系人生成 .xlsx 字节流。
  /// 表头使用「姓名/手机号/部门/职位」，与导入功能的智能列识别完全兼容，
  /// 导出的 Excel 可直接再通过本 App 的表格导入通道导回通讯录。
  static Uint8List buildExcelBytes(List<DeviceContact> contacts) {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    sheet.appendRow([
      TextCellValue('姓名'),
      TextCellValue('手机号'),
      TextCellValue('部门'),
      TextCellValue('职位'),
    ]);

    for (final c in contacts) {
      sheet.appendRow([
        TextCellValue(c.displayName),
        TextCellValue(c.phone),
        TextCellValue(c.department),
        TextCellValue(c.title),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('生成 Excel 失败，请重试');
    }
    return Uint8List.fromList(bytes);
  }

  /// 生成默认导出文件名
  static String defaultFileName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '通讯录导出_${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}.xlsx';
  }
}
