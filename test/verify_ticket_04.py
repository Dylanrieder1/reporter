import re
import sys

class ValidationStatus:
    VALID = 'valid'
    SKIPPED_DUPLICATE_PHONE = 'skippedDuplicatePhone'
    SKIPPED_DUPLICATE_NAME = 'skippedDuplicateName'
    SKIPPED_INVALID_PHONE = 'skippedInvalidPhone'
    SKIPPED_EMPTY_NAME = 'skippedEmptyName'

class ContactValidator:
    @classmethod
    def normalize_phone(cls, raw_phone):
        p = re.sub(r'\D', '', raw_phone)
        if p.startswith('86') and len(p) == 13:
            p = p[2:]
        return p

    @classmethod
    def is_valid_mobile(cls, phone):
        return bool(re.match(r'^1[3-9]\d{9}$', phone))

    @classmethod
    def format_display_name(cls, name, department, title, append_dept_title):
        if not append_dept_title:
            return name
        parts = [p for p in [name, department, title] if p]
        return '-'.join(parts)

    @classmethod
    def validate(cls, raw_list, existing_phones, existing_names, append_dept_title_to_name):
        results = []
        seen_phones_in_batch = set()
        seen_names_in_batch = set()

        normalized_existing_phones = {cls.normalize_phone(p) for p in existing_phones if cls.normalize_phone(p)}
        normalized_existing_names = {n.strip() for n in existing_names if n.strip()}

        for raw in raw_list:
            name = raw.get('name', '').strip()
            clean_phone = cls.normalize_phone(raw.get('phone', ''))

            formatted_name = cls.format_display_name(
                name=name,
                department=raw.get('department', '').strip(),
                title=raw.get('title', '').strip(),
                append_dept_title=append_dept_title_to_name
            )

            if not name:
                results.append({'raw': raw, 'status': ValidationStatus.SKIPPED_EMPTY_NAME, 'formatted_name': formatted_name})
                continue

            if not cls.is_valid_mobile(clean_phone):
                results.append({'raw': raw, 'status': ValidationStatus.SKIPPED_INVALID_PHONE, 'formatted_name': formatted_name})
                continue

            if clean_phone in normalized_existing_phones:
                results.append({'raw': raw, 'status': ValidationStatus.SKIPPED_DUPLICATE_PHONE, 'formatted_name': formatted_name})
                continue

            if name in normalized_existing_names:
                results.append({'raw': raw, 'status': ValidationStatus.SKIPPED_DUPLICATE_NAME, 'formatted_name': formatted_name})
                continue

            if clean_phone in seen_phones_in_batch:
                results.append({'raw': raw, 'status': ValidationStatus.SKIPPED_DUPLICATE_PHONE, 'formatted_name': formatted_name})
                continue

            if name in seen_names_in_batch:
                results.append({'raw': raw, 'status': ValidationStatus.SKIPPED_DUPLICATE_NAME, 'formatted_name': formatted_name})
                continue

            seen_phones_in_batch.add(clean_phone)
            seen_names_in_batch.add(name)

            updated_raw = dict(raw)
            updated_raw['phone'] = clean_phone
            results.append({'raw': updated_raw, 'status': ValidationStatus.VALID, 'formatted_name': formatted_name})

        return results

def test_runner():
    print("Running Ticket 04 Verification Suite...")

    # Case 1: Name format
    n1 = ContactValidator.format_display_name('张三', '技术部', '架构师', True)
    assert n1 == '张三-技术部-架构师'
    n2 = ContactValidator.format_display_name('张三', '技术部', '架构师', False)
    assert n2 == '张三'
    print("[PASS] Case 1: Name format")

    # Case 2: Skip existing phone
    raw_list = [{'name': '新人A', 'phone': '13800001111'}]
    res = ContactValidator.validate(raw_list, {'13800001111'}, set(), False)
    assert len(res) == 1
    assert res[0]['status'] == ValidationStatus.SKIPPED_DUPLICATE_PHONE
    print("[PASS] Case 2: Skip existing phone")

    # Case 3: Skip existing name
    raw_list2 = [{'name': '老张', 'phone': '13922223333'}]
    res2 = ContactValidator.validate(raw_list2, set(), {'老张'}, False)
    assert len(res2) == 1
    assert res2[0]['status'] == ValidationStatus.SKIPPED_DUPLICATE_NAME
    print("[PASS] Case 3: Skip existing name")

    # Case 4: Invalid phone and empty name
    raw_list3 = [
        {'name': '王五', 'phone': '12345'},
        {'name': '', 'phone': '13811112222'}
    ]
    res3 = ContactValidator.validate(raw_list3, set(), set(), False)
    assert res3[0]['status'] == ValidationStatus.SKIPPED_INVALID_PHONE
    assert res3[1]['status'] == ValidationStatus.SKIPPED_EMPTY_NAME
    print("[PASS] Case 4: Invalid phone and empty name")

    # Case 5: Intra-batch duplicates
    raw_list4 = [
        {'name': '赵六', 'phone': '13833334444'},
        {'name': '孙七', 'phone': '13833334444'},
        {'name': '赵六', 'phone': '13855556666'}
    ]
    res4 = ContactValidator.validate(raw_list4, set(), set(), False)
    assert res4[0]['status'] == ValidationStatus.VALID
    assert res4[1]['status'] == ValidationStatus.SKIPPED_DUPLICATE_PHONE
    assert res4[2]['status'] == ValidationStatus.SKIPPED_DUPLICATE_NAME
    print("[PASS] Case 5: Intra-batch duplicates")

    print("\nALL TICKET 04 TESTS PASSED PERFECTLY!\n")

if __name__ == '__main__':
    test_runner()
