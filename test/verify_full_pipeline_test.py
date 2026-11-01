import asyncio
import re
import time
import sys

# ==========================================
# 完整链路业务逻辑（端到端集成测试沙箱）
# ==========================================

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
            # 过滤注释
            comment_match = re.search(r'(?:#|//).*$', line)
            if comment_match:
                line = line[:comment_match.start()].strip()
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
            raw_tokens = [re.sub(r'^[#*:\-—]+|[#*:\-—]+$', '', t).strip() for t in re.split(r'[\t,，;；|/ ]+', remaining_text)]
            raw_tokens = [t for t in raw_tokens if t]

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
                results.append({'raw': raw, 'status': 'skippedEmptyName', 'formatted_name': formatted_name, 'is_valid': False})
                continue

            if not cls.is_valid_mobile(clean_phone):
                results.append({'raw': raw, 'status': 'skippedInvalidPhone', 'formatted_name': formatted_name, 'is_valid': False})
                continue

            if clean_phone in normalized_existing_phones:
                results.append({'raw': raw, 'status': 'skippedDuplicatePhone', 'formatted_name': formatted_name, 'is_valid': False})
                continue

            if name in normalized_existing_names:
                results.append({'raw': raw, 'status': 'skippedDuplicateName', 'formatted_name': formatted_name, 'is_valid': False})
                continue

            if clean_phone in seen_phones_in_batch:
                results.append({'raw': raw, 'status': 'skippedDuplicatePhone', 'formatted_name': formatted_name, 'is_valid': False})
                continue

            if name in seen_names_in_batch:
                results.append({'raw': raw, 'status': 'skippedDuplicateName', 'formatted_name': formatted_name, 'is_valid': False})
                continue

            seen_phones_in_batch.add(clean_phone)
            seen_names_in_batch.add(name)

            updated_raw = dict(raw)
            updated_raw['phone'] = clean_phone
            results.append({'raw': updated_raw, 'status': 'valid', 'formatted_name': formatted_name, 'is_valid': True})

        return results


class MockContactsService:
    def __init__(self, initial_phones=None, initial_names=None):
        self.phones = set(initial_phones or [])
        self.names = set(initial_names or [])
        self.inserted = []

    async def import_stream(self, valid_items):
        total = len(valid_items)
        for i, item in enumerate(valid_items):
            self.inserted.append(item)
            self.phones.add(item['raw']['phone'])
            self.names.add(item['formatted_name'])
            yield i + 1, total


# ==========================================
# 完整测试执行
# ==========================================
async def run_full_pipeline_tests():
    print("==================================================")
    print(" 开始端到端全链路与边界 Case 集成测试 ")
    print("==================================================")

    # 1. 模拟真实混合业务输入场景
    sample_text = """
    # 部门通讯录通知
    张三\t13800000001\t技术研发部\t首席架构师
    李四, +86 138-0000-0002, 市场运营中心, 市场总监
    王五 13800000003 财务部 会计主管
    赵六 13800000004   # 仅人名+电话
    老张 13800000005 综合部  # 姓名在通讯录已存在（待跳过）
    新员工 13800009999 人事部 # 手机号在通讯录已存在（待跳过）
    批次重复者A 13800000008 运营部 专员
    批次重复者B 13800000008 运营部 专员 # 号码同上（批次内待跳过）
    
    12345678901 无效手机号部门
    """

    # 步骤 A：文本智能切分
    raw_contacts = TextParserService.parse_text(sample_text)
    print(f"[Step A] 成功解析出 {len(raw_contacts)} 条原始联系人记录")
    assert len(raw_contacts) == 8, f"Expected 8, got {len(raw_contacts)}"

    # 步骤 B：模拟手机已有联系人环境（触发跳过逻辑）
    existing_phones = {'13800009999'} # 新员工的电话已存在
    existing_names = {'老张'}          # 老张的名字已存在

    # 步骤 C：执行严格校验与来电格式化 (开启来电显示优化: 张三-部门-职位)
    validated_items = ContactValidator.validate(
        raw_list=raw_contacts,
        existing_phones=existing_phones,
        existing_names=existing_names,
        append_dept_title_to_name=True
    )

    valid_list = [item for item in validated_items if item['is_valid']]
    skipped_list = [item for item in validated_items if not item['is_valid']]

    print(f"[Step C] 校验结果: 有效 {len(valid_list)} 条，自动跳过 {len(skipped_list)} 条")
    assert len(valid_list) == 5, f"Expected 5 valid, got {len(valid_list)}"
    assert len(skipped_list) == 3, f"Expected 3 skipped, got {len(skipped_list)}"

    # 验证具体跳过原因
    skip_reasons = {item['raw']['name']: item['status'] for item in skipped_list}
    assert skip_reasons['老张'] == 'skippedDuplicateName', "老张应该因姓名已存在被跳过"
    assert skip_reasons['新员工'] == 'skippedDuplicatePhone', "新员工应该因号码已存在被跳过"
    assert skip_reasons['批次重复者B'] == 'skippedDuplicatePhone', "批次重复者B应该因批次内重复被跳过"
    print("[PASS] 严格跳过策略逻辑完全符合预期")

    # 验证来电显示优化生成格式
    zhang_san = next(item for item in valid_list if item['raw']['name'] == '张三')
    assert zhang_san['formatted_name'] == '张三-技术研发部-首席架构师'
    zhao_liu = next(item for item in valid_list if item['raw']['name'] == '赵六')
    assert zhao_liu['formatted_name'] == '赵六'
    print("[PASS] 来电显示格式化（自动拼接与缺省处理）完全符合预期")

    # 步骤 D：模拟流式批量写入
    mock_service = MockContactsService(initial_phones=existing_phones, initial_names=existing_names)
    progress_count = 0
    async for cur, tot in mock_service.import_stream(valid_list):
        progress_count = cur
    assert progress_count == 5
    assert len(mock_service.inserted) == 5
    print("[PASS] 批量流式写入引擎完成，总计写入 5 条")

    # 步骤 E：高压力 1000+ 条大数据性能边界测试
    print("\n--- 执行 1000 条大数据性能测试 ---")
    start_time = time.time()
    large_batch = [
        {'name': f'员工_{i}', 'phone': f'138{i:08d}', 'department': '云原生架构部', 'title': '资深工程师'}
        for i in range(1000)
    ]
    large_validated = ContactValidator.validate(large_batch, set(), set(), True)
    duration = time.time() - start_time
    assert len(large_validated) == 1000
    assert all(item['is_valid'] for item in large_validated)
    print(f"[PASS] 1000 条数据去重与格式化耗时: {duration:.3f} 秒 (极其快速高效)")

    print("\n==================================================")
    print(" 全链路端到端集成测试全部通过 (ALL GREEN!) ")
    print("==================================================")

if __name__ == '__main__':
    asyncio.run(run_full_pipeline_tests())
