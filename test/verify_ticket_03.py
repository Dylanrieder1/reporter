import sys

class ColumnMapping:
    def __init__(self, name_index=-1, phone_index=-1, dept_index=-1, title_index=-1):
        self.name_index = name_index
        self.phone_index = phone_index
        self.dept_index = dept_index
        self.title_index = title_index

    @property
    def is_valid(self):
        return self.name_index >= 0 and self.phone_index >= 0

class ExcelParserService:
    _name_keywords = ['姓名', '名字', '联系人', '员工姓名', '人员', '成员', 'name', 'user']
    _phone_keywords = ['手机', '电话', '小号', '手机小号', '联系电话', '移动电话', '号码', 'phone', 'mobile', 'tel']
    _dept_keywords = ['部门', '科室', '机构', '单位', '所属部门', '团队', '组别', 'department', 'dept', 'team']
    _title_keywords = ['职位', '职务', '岗位', '工种', '职称', 'title', 'position', 'post', 'role']

    @classmethod
    def _matches_keyword(cls, text, keywords):
        for kw in keywords:
            if kw.lower() in text.lower():
                return True
        return False

    @classmethod
    def detect_header_mapping(cls, headers):
        name_idx = -1
        phone_idx = -1
        dept_idx = -1
        title_idx = -1

        for i, header in enumerate(headers):
            h = header.strip().lower()
            if not h:
                continue
            if name_idx == -1 and cls._matches_keyword(h, cls._name_keywords):
                name_idx = i
            elif phone_idx == -1 and cls._matches_keyword(h, cls._phone_keywords):
                phone_idx = i
            elif dept_idx == -1 and cls._matches_keyword(h, cls._dept_keywords):
                dept_idx = i
            elif title_idx == -1 and cls._matches_keyword(h, cls._title_keywords):
                title_idx = i

        if name_idx == -1 and len(headers) > 0:
            name_idx = 0
        if phone_idx == -1 and len(headers) > 1:
            phone_idx = 1
        if dept_idx == -1 and len(headers) > 2:
            dept_idx = 2
        if title_idx == -1 and len(headers) > 3:
            title_idx = 3

        return ColumnMapping(name_idx, phone_idx, dept_idx, title_idx)

    @classmethod
    def extract_rows(cls, rows, mapping, has_header=True):
        contacts = []
        start_index = 1 if has_header else 0

        for i in range(start_index, len(rows)):
            row = rows[i]
            if not row or not any(str(c).strip() for c in row):
                continue

            def get_cell(idx):
                if idx < 0 or idx >= len(row):
                    return ''
                val = row[idx]
                return '' if val is None else str(val).strip()

            name = get_cell(mapping.name_index)
            phone = get_cell(mapping.phone_index)
            dept = get_cell(mapping.dept_index)
            title = get_cell(mapping.title_index)

            if name or phone or dept or title:
                contacts.append({
                    'name': name,
                    'phone': phone,
                    'department': dept,
                    'title': title
                })
        return contacts

def test_runner():
    print("Running Ticket 03 Verification Suite...")

    # Case 1: Standard Chinese headers
    h1 = ['员工姓名', '联系电话', '所属部门', '岗位职称']
    m1 = ExcelParserService.detect_header_mapping(h1)
    assert m1.name_index == 0
    assert m1.phone_index == 1
    assert m1.dept_index == 2
    assert m1.title_index == 3
    assert m1.is_valid
    print("[PASS] Case 1: Standard headers")

    # Case 2: Reverse headers
    h2 = ['部门', '职位', '手机小号', '姓名']
    m2 = ExcelParserService.detect_header_mapping(h2)
    assert m2.dept_index == 0
    assert m2.title_index == 1
    assert m2.phone_index == 2
    assert m2.name_index == 3
    assert m2.is_valid
    print("[PASS] Case 2: Reverse headers")

    # Case 3: Unknown headers fallback
    h3 = ['Col_A', 'Col_B', 'Col_C', 'Col_D']
    m3 = ExcelParserService.detect_header_mapping(h3)
    assert m3.name_index == 0
    assert m3.phone_index == 1
    assert m3.dept_index == 2
    assert m3.title_index == 3
    print("[PASS] Case 3: Unknown fallback")

    # Case 4: Row extraction
    rows = [
        ['姓名', '手机', '部门', '职位'],
        ['张三', '13800000000', '技术部', '开发'],
        ['李四', '13911112222', '销售部', '销售代表'],
        ['', '', '', '']
    ]
    extracted = ExcelParserService.extract_rows(rows, m1, has_header=True)
    assert len(extracted) == 2
    assert extracted[0]['name'] == '张三'
    assert extracted[0]['phone'] == '13800000000'
    assert extracted[1]['name'] == '李四'
    print("[PASS] Case 4: Extract rows")

    print("\nALL TICKET 03 TESTS PASSED PERFECTLY!\n")

if __name__ == '__main__':
    test_runner()
