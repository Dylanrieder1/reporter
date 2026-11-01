import re
import sys

class TextParserService:
    _phone_regex = re.compile(r'(?:(?:\+|00)?86[\s\-]?)?1[3-9]\d[\s\-]?\d{4}[\s\-]?\d{4}')
    _dept_keyword_regex = re.compile(r'部|科|组|中心|院|所|室|局|处|行|馆|团队|部门|分公司|支行|team|dept', re.IGNORECASE)
    _title_keyword_regex = re.compile(r'经理|总监|工程师|专员|主管|顾问|架构师|助理|会计|HR|开发|设计|运营|测试|运维|组长|主任|书记|部长|负责人|总管|CEO|CTO|COO|CFO|VP|合伙人|实习生|专家|研究员', re.IGNORECASE)

    @classmethod
    def parse_text(cls, input_text):
        if not input_text or not input_text.strip():
            return []

        lines = input_text.splitlines()
        results = []

        for raw_line in lines:
            line = raw_line.strip()
            if not line:
                continue

            match = cls._phone_regex.search(line)
            if not match:
                continue

            raw_phone_str = match.group(0)
            clean_digits = re.sub(r'\D', '', raw_phone_str)
            phone = clean_digits
            if phone.startswith('86') and len(phone) == 13:
                phone = phone[2:]

            remaining_text = line.replace(raw_phone_str, ' ', 1)
            raw_tokens = [t.strip() for t in re.split(r'[\t,，;；|/ ]+', remaining_text) if t.strip()]

            if not raw_tokens:
                results.append({'name': '', 'phone': phone, 'department': '', 'title': ''})
                continue

            name = ''
            department = ''
            title = ''
            unassigned_tokens = []

            for token in raw_tokens:
                if not department and cls._dept_keyword_regex.search(token):
                    department = token
                elif not title and cls._title_keyword_regex.search(token):
                    title = token
                else:
                    unassigned_tokens.append(token)

            if unassigned_tokens:
                name = unassigned_tokens.pop(0)
            if not department and unassigned_tokens:
                department = unassigned_tokens.pop(0)
            if not title and unassigned_tokens:
                title = unassigned_tokens.pop(0)

            results.append({
                'name': name,
                'phone': phone,
                'department': department,
                'title': title
            })
        return results

def test_runner():
    print("Running Ticket 02 Verification Suite...")

    # Case 1: Tab separated
    c1 = TextParserService.parse_text('张三\t13800138000\t技术研发部\t高级架构师')
    assert len(c1) == 1, f"Expected 1, got {len(c1)}"
    assert c1[0]['name'] == '张三'
    assert c1[0]['phone'] == '13800138000'
    assert c1[0]['department'] == '技术研发部'
    assert c1[0]['title'] == '高级架构师'
    print("[PASS] Case 1: Tab separated")

    # Case 2: +86 and dashes
    c2 = TextParserService.parse_text('李四, +86 139-1234-5678, 市场运营部, 运营总监')
    assert len(c2) == 1
    assert c2[0]['name'] == '李四'
    assert c2[0]['phone'] == '13912345678'
    assert c2[0]['department'] == '市场运营部'
    assert c2[0]['title'] == '运营总监'
    print("[PASS] Case 2: +86 and dashes")

    # Case 3: Reordered keywords
    c3 = TextParserService.parse_text('财务部 王五 13788889999 会计主管')
    assert len(c3) == 1
    assert c3[0]['name'] == '王五'
    assert c3[0]['phone'] == '13788889999'
    assert c3[0]['department'] == '财务部'
    assert c3[0]['title'] == '会计主管'
    print("[PASS] Case 3: Keyword reordering")

    # Case 4: Minimal input
    c4 = TextParserService.parse_text('赵六 13611112222')
    assert len(c4) == 1
    assert c4[0]['name'] == '赵六'
    assert c4[0]['phone'] == '13611112222'
    assert c4[0]['department'] == ''
    assert c4[0]['title'] == ''
    print("[PASS] Case 4: Minimal input")

    # Case 5: Noise and empty lines
    noise_input = """
        通知：请各部门查收小号
        孙七 13500001111
        
        无电话测试人员
        周八 13422223333 客服部
    """
    c5 = TextParserService.parse_text(noise_input)
    assert len(c5) == 2
    assert c5[0]['name'] == '孙七'
    assert c5[0]['phone'] == '13500001111'
    assert c5[1]['name'] == '周八'
    assert c5[1]['phone'] == '13422223333'
    assert c5[1]['department'] == '客服部'
    print("[PASS] Case 5: Noise filtering")

    print("\nALL TICKET 02 TESTS PASSED PERFECTLY!\n")

if __name__ == '__main__':
    test_runner()
