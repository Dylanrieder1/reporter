import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/contact_validation_item.dart';
import '../models/import_progress.dart';

/// 已有通讯录数据缓存（供查重使用）
class ExistingContactsCache {
  final Set<String> phones;
  final Set<String> names;

  const ExistingContactsCache({
    required this.phones,
    required this.names,
  });

  bool get isEmpty => phones.isEmpty && names.isEmpty;
}

/// 通讯录底层适配接口（解耦真机系统与测试 Mock）
abstract class IContactsProvider {
  Future<bool> requestPermission();
  Future<ExistingContactsCache> getExistingContacts();

  /// 写入单条联系人；返回 true 表示已确认写入系统通讯录，false 表示写入失败
  Future<bool> insertContact({
    required String displayName,
    required String phone,
    required String department,
    required String title,
  });
}

/// 基于 flutter_contacts 的原生真机适配器
class FlutterContactsProvider implements IContactsProvider {
  @override
  Future<bool> requestPermission() async {
    return await FlutterContacts.requestPermission(readonly: false);
  }

  @override
  Future<ExistingContactsCache> getExistingContacts() async {
    try {
      // 优先安全请求只读权限，若用户暂未授权或设备拦截，安全返回空缓存以确保 App 绝不闪退
      final hasPerm = await FlutterContacts.requestPermission(readonly: true);
      if (!hasPerm) {
        return const ExistingContactsCache(phones: {}, names: {});
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withAccounts: false,
      );

      final phones = <String>{};
      final names = <String>{};

      for (final c in contacts) {
        if (c.displayName.trim().isNotEmpty) {
          names.add(c.displayName.trim());
        }
        for (final p in c.phones) {
          final clean = p.number.replaceAll(RegExp(r'\D'), '');
          if (clean.isNotEmpty) {
            phones.add(clean);
          }
        }
      }

      return ExistingContactsCache(phones: phones, names: names);
    } catch (e) {
      // 捕获任何可能的底层 SecurityException 或系统 ContentProvider 异常
      return const ExistingContactsCache(phones: {}, names: {});
    }
  }

  @override
  Future<bool> insertContact({
    required String displayName,
    required String phone,
    required String department,
    required String title,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    Future<bool> doInsert(Contact contact) async {
      // insert() 成功时会返回携带系统分配 id 的 Contact，以此确认真实写入成功
      final inserted = await contact.insert();
      return inserted.id.isNotEmpty;
    }

    final newContact = Contact();
    newContact.name.first = displayName;

    if (cleanPhone.isNotEmpty) {
      newContact.phones = [
        Phone(cleanPhone, label: PhoneLabel.mobile),
      ];
    }

    if (department.trim().isNotEmpty || title.trim().isNotEmpty) {
      newContact.organizations = [
        Organization(
          company: department.trim().isNotEmpty ? department.trim() : ' ',
          department: department.trim(),
          title: title.trim(),
        ),
      ];
    }

    try {
      return await doInsert(newContact);
    } catch (e) {
      debugPrint('完整联系人写入失败，降级为仅姓名+手机号重试: $e');
      // 容错降级策略：某些国内定制 ROM (MIUI / HyperOS / ColorOS 等)
      // 在写入特定扩展字段 (organizations) 时可能抛出异常。
      // 此时降级为仅写入姓名和手机号。由于来电显示优化已将部门职位拼在姓名中（如 张三-技术部-架构师），
      // 来电时依然能完整清晰显示部门和职务，兼顾写入成功率与来电辨识度。
      final fallbackContact = Contact();
      fallbackContact.name.first = displayName;
      if (cleanPhone.isNotEmpty) {
        fallbackContact.phones = [
          Phone(cleanPhone, label: PhoneLabel.mobile),
        ];
      }
      try {
        return await doInsert(fallbackContact);
      } catch (e2) {
        // 降级写入也失败：把真实原因抛给上层，绝不静默当作成功
        debugPrint('降级写入同样失败: $e2');
        throw Exception('联系人「$displayName」写入失败: $e2');
      }
    }
  }
}

/// 模拟内存通讯录适配器（用于纯单元测试与无真机环境验证）
class MockContactsProvider implements IContactsProvider {
  final Set<String> mockPhones;
  final Set<String> mockNames;
  final List<Map<String, String>> insertedRecords = [];

  MockContactsProvider({
    Set<String>? initialPhones,
    Set<String>? initialNames,
  })  : mockPhones = initialPhones ?? {},
        mockNames = initialNames ?? {};

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<ExistingContactsCache> getExistingContacts() async {
    return ExistingContactsCache(phones: Set.from(mockPhones), names: Set.from(mockNames));
  }

  @override
  Future<bool> insertContact({
    required String displayName,
    required String phone,
    required String department,
    required String title,
  }) async {
    insertedRecords.add({
      'name': displayName,
      'phone': phone,
      'department': department,
      'title': title,
    });
    mockPhones.add(phone);
    mockNames.add(displayName);
    return true;
  }
}

/// 通讯录业务服务：协调权限、查重数据获取、批量流式异步写入
class ContactsService {
  final IContactsProvider _provider;

  ContactsService([IContactsProvider? provider])
      : _provider = provider ?? FlutterContactsProvider();

  Future<bool> requestPermission() async {
    return await _provider.requestPermission();
  }

  Future<ExistingContactsCache> fetchExistingContacts() async {
    return await _provider.getExistingContacts();
  }

  /// 异步批量写入联系人，并以 Stream 形式持续对外抛出写入进度。
  /// 每条写入结果都会被确认：成功计入 successCount，失败计入 failedCount 并携带原因。
  Stream<ImportProgress> importContactsStream(
    List<ContactValidationItem> validItems,
  ) async* {
    final total = validItems.length;
    if (total == 0) {
      yield const ImportProgress(current: 0, total: 0);
      return;
    }

    // 写入前再次确认通讯录写权限（若在预览后被系统/用户撤销，这里能立刻暴露而不是全部假成功）
    final hasWritePerm = await _provider.requestPermission();
    if (!hasWritePerm) {
      throw Exception('通讯录写权限未授权：请在系统设置中允许本应用读写通讯录后重试');
    }

    int success = 0;
    int failed = 0;
    String lastError = '';

    for (int i = 0; i < total; i++) {
      final item = validItems[i];

      try {
        final ok = await _provider.insertContact(
          displayName: item.formattedDisplayName,
          phone: item.raw.phone,
          department: item.raw.department,
          title: item.raw.title,
        );
        if (ok) {
          success++;
        } else {
          failed++;
          lastError = '联系人「${item.formattedDisplayName}」写入失败（未通过系统确认）';
          debugPrint('写入未确认: ${item.formattedDisplayName}');
        }
      } catch (e) {
        // 单条失败：记录真实原因并继续导入后续联系人，绝不中断也绝不静默
        failed++;
        lastError = e.toString();
        debugPrint('单条写入异常: ${item.formattedDisplayName} -> $e');
      }

      // 每处理一条，更新一次进度（含真实成功/失败计数）
      yield ImportProgress(
        current: i + 1,
        total: total,
        currentName: item.formattedDisplayName,
        successCount: success,
        failedCount: failed,
        lastError: lastError,
      );

      // 微小延时释放 UI 线程事件循环，防止主线程卡顿
      await Future.delayed(const Duration(milliseconds: 5));
    }
  }
}
