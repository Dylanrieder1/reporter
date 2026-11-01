# 05: Contacts Batch Writer & Permission Service

**What to build:**
A device contacts integration service that requests and verifies `READ_CONTACTS` and `WRITE_CONTACTS` permissions, queries existing device contacts (building phone/name cache for deduplication), and writes valid contacts into the Android Contacts provider in batches with `flutter_contacts`. Writes structured `DisplayName`, `Phone`, `Organization.DEPARTMENT`, and `Organization.TITLE`, and emits real-time progress events over a Dart stream.

**Blocked by:** 04-dedup-validator

**Status:** ready-for-agent

- [ ] Permission request handling with graceful rationale callback
- [ ] Existing contacts query optimizing for phone and name extraction
- [ ] Batch insertion engine avoiding UI thread freeze
- [ ] Progress reporting stream emitting current count, total count, and percentage
- [ ] Mock contacts adapter seam for testing on environments without physical phone
