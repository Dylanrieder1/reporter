import 'package:flutter_test/flutter_test.dart';
import 'package:contacts_importer/models/contact_validation_item.dart';
import 'package:contacts_importer/models/raw_contact_data.dart';
import 'package:contacts_importer/services/contact_validator.dart';

void main() {
  group('ContactValidator Tests', () {
    test('should format display name according to toggle', () {
      final name1 = ContactValidator.formatDisplayName(
        name: '张三',
        department: '技术部',
        title: '架构师',
        appendDeptTitle: true,
      );
      expect(name1, '张三-技术部-架构师');

      final name2 = ContactValidator.formatDisplayName(
        name: '张三',
        department: '技术部',
        title: '架构师',
        appendDeptTitle: false,
      );
      expect(name2, '张三');
    });

    test('should strictly skip existing phone number', () {
      final rawList = [
        const RawContactData(name: '新人A', phone: '13800001111'),
      ];
      final existingPhones = {'13800001111'};
      final existingNames = <String>{};

      final items = ContactValidator.validate(
        rawList: rawList,
        existingPhones: existingPhones,
        existingNames: existingNames,
        appendDeptTitleToName: false,
      );

      expect(items.length, 1);
      expect(items.first.status, ValidationStatus.skippedDuplicatePhone);
      expect(items.first.isValid, isFalse);
    });

    test('should strictly skip existing name', () {
      final rawList = [
        const RawContactData(name: '老张', phone: '13922223333'),
      ];
      final existingPhones = <String>{};
      final existingNames = {'老张'};

      final items = ContactValidator.validate(
        rawList: rawList,
        existingPhones: existingPhones,
        existingNames: existingNames,
        appendDeptTitleToName: false,
      );

      expect(items.length, 1);
      expect(items.first.status, ValidationStatus.skippedDuplicateName);
      expect(items.first.isValid, isFalse);
    });

    test('should flag invalid phone numbers and empty names', () {
      final rawList = [
        const RawContactData(name: '王五', phone: '12345'), // 非法号码
        const RawContactData(name: '', phone: '13811112222'), // 空人名
      ];

      final items = ContactValidator.validate(
        rawList: rawList,
        existingPhones: {},
        existingNames: {},
        appendDeptTitleToName: false,
      );

      expect(items[0].status, ValidationStatus.skippedInvalidPhone);
      expect(items[1].status, ValidationStatus.skippedEmptyName);
    });

    test('should detect intra-batch duplicates', () {
      final rawList = [
        const RawContactData(name: '赵六', phone: '13833334444'),
        const RawContactData(name: '孙七', phone: '13833334444'), // 同号码
        const RawContactData(name: '赵六', phone: '13855556666'), // 同姓名
      ];

      final items = ContactValidator.validate(
        rawList: rawList,
        existingPhones: {},
        existingNames: {},
        appendDeptTitleToName: false,
      );

      expect(items[0].status, ValidationStatus.valid);
      expect(items[1].status, ValidationStatus.skippedDuplicatePhone);
      expect(items[2].status, ValidationStatus.skippedDuplicateName);
    });
  });
}
