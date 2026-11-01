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
  });
}
