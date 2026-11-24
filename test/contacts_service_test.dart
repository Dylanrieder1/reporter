import 'package:flutter_test/flutter_test.dart';
import 'package:contacts_importer/models/contact_validation_item.dart';
import 'package:contacts_importer/models/raw_contact_data.dart';
import 'package:contacts_importer/services/contacts_service.dart';

void main() {
  group('ContactsService with Mock Provider Tests', () {
    test('should fetch existing cache correctly', () async {
      final mock = MockContactsProvider(
        initialPhones: {'13800000000'},
        initialNames: {'张三'},
      );
      final service = ContactsService(mock);

      final cache = await service.fetchExistingContacts();
      expect(cache.phones.contains('13800000000'), isTrue);
      expect(cache.names.contains('张三'), isTrue);
    });

    test('should emit progress events during stream import', () async {
      final mock = MockContactsProvider();
      final service = ContactsService(mock);

      final items = [
        const ContactValidationItem(
          raw: RawContactData(name: '李四', phone: '13911112222', department: '研发部'),
          status: ValidationStatus.valid,
          formattedDisplayName: '李四-研发部',
        ),
        const ContactValidationItem(
          raw: RawContactData(name: '王五', phone: '13933334444', department: '财务部'),
          status: ValidationStatus.valid,
          formattedDisplayName: '王五-财务部',
        ),
      ];

      final progressList = <int>[];
      await for (final p in service.importContactsStream(items)) {
        progressList.add(p.current);
      }

      expect(progressList, [1, 2]);
      expect(mock.insertedRecords.length, 2);
      expect(mock.insertedRecords[0]['name'], '李四-研发部');
      expect(mock.insertedRecords[0]['phone'], '13911112222');
      expect(mock.insertedRecords[1]['name'], '王五-财务部');
      expect(mock.insertedRecords[1]['phone'], '13933334444');
    });

    test('should report real failure counts instead of fake success', () async {
      final service = ContactsService(_FailingProvider());

      final items = [
        const ContactValidationItem(
          raw: RawContactData(name: '赵六', phone: '13755556666'),
          status: ValidationStatus.valid,
          formattedDisplayName: '赵六',
        ),
        const ContactValidationItem(
          raw: RawContactData(name: '钱七', phone: '13666667777'),
          status: ValidationStatus.valid,
          formattedDisplayName: '钱七',
        ),
      ];

      int success = -1;
      int failed = -1;
      String lastError = '';
      await for (final p in service.importContactsStream(items)) {
        success = p.successCount;
        failed = p.failedCount;
        lastError = p.lastError;
      }

      // 关键断言：失败必须如实上报，绝不静默计为成功
      expect(success, 0);
      expect(failed, 2);
      expect(lastError, contains('mock write denied'));
    });
  });
}

/// 模拟写入总是被系统拒绝的 Provider（如权限被 ROM 拦截）
class _FailingProvider implements IContactsProvider {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<ExistingContactsCache> getExistingContacts() async {
    return const ExistingContactsCache(phones: {}, names: {});
  }

  @override
  Future<bool> insertContact({
    required String displayName,
    required String phone,
    required String department,
    required String title,
  }) async {
    throw Exception('mock write denied');
  }
}
