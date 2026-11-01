import asyncio
import sys

class ExistingContactsCache:
    def __init__(self, phones, names):
        self.phones = set(phones)
        self.names = set(names)

class MockContactsProvider:
    def __init__(self, initial_phones=None, initial_names=None):
        self.phones = set(initial_phones or [])
        self.names = set(initial_names or [])
        self.inserted_records = []

    async def get_existing_contacts(self):
        return ExistingContactsCache(self.phones, self.names)

    async def insert_contact(self, display_name, phone, department, title):
        self.inserted_records.append({
            'name': display_name,
            'phone': phone,
            'department': department,
            'title': title
        })
        self.phones.add(phone)
        self.names.add(display_name)

class ContactsService:
    def __init__(self, provider):
        self.provider = provider

    async def fetch_existing_contacts(self):
        return await self.provider.get_existing_contacts()

    async def import_contacts_stream(self, valid_items):
        total = len(valid_items)
        if total == 0:
            yield {'current': 0, 'total': 0, 'percentage': 0}
            return

        for i, item in enumerate(valid_items):
            await self.provider.insert_contact(
                display_name=item['formatted_name'],
                phone=item['raw']['phone'],
                department=item['raw'].get('department', ''),
                title=item['raw'].get('title', '')
            )
            current = i + 1
            yield {
                'current': current,
                'total': total,
                'percentage': int((current / total) * 100),
                'name': item['formatted_name']
            }
            await asyncio.sleep(0.001)

async def test_runner():
    print("Running Ticket 05 Verification Suite...")

    # Case 1: Cache fetching
    mock = MockContactsProvider(initial_phones=['13800000000'], initial_names=['张三'])
    service = ContactsService(mock)
    cache = await service.fetch_existing_contacts()
    assert '13800000000' in cache.phones
    assert '张三' in cache.names
    print("[PASS] Case 1: Existing cache query")

    # Case 2: Batch stream insertion
    items = [
        {'raw': {'name': '李四', 'phone': '13911112222', 'department': '研发部'}, 'formatted_name': '李四-研发部'},
        {'raw': {'name': '王五', 'phone': '13933334444', 'department': '财务部'}, 'formatted_name': '王五-财务部'}
    ]

    progress_steps = []
    async for p in service.import_contacts_stream(items):
        progress_steps.append(p['current'])

    assert progress_steps == [1, 2]
    assert len(mock.inserted_records) == 2
    assert mock.inserted_records[0]['name'] == '李四-研发部'
    assert mock.inserted_records[0]['phone'] == '13911112222'
    assert mock.inserted_records[1]['name'] == '王五-财务部'
    assert mock.inserted_records[1]['phone'] == '13933334444'
    print("[PASS] Case 2: Streaming batch insertion")

    print("\nALL TICKET 05 TESTS PASSED PERFECTLY!\n")

if __name__ == '__main__':
    asyncio.run(test_runner())
