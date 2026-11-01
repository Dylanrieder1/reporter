# 04: Strict-Skip Validation & Incoming Call Name Formatter

**What to build:**
A validation and deduplication engine that sanitizes phone numbers (stripping non-digits and leading `86`/`+86`), checks against existing device contacts (by phone number and name), tags items with specific skip reasons (`skippedDuplicatePhone`, `skippedDuplicateName`, `skippedInvalidPhone`, `skippedEmptyName`), performs intra-batch deduplication, and computes the display name according to the "Incoming Call Optimization" toggle (e.g. `张三-研发部-架构师` vs `张三`). Includes full TDD test suite.

**Blocked by:** 02-text-parser, 03-excel-parser

**Status:** ready-for-agent

- [ ] Phone number normalization (clean digits, +86 removal)
- [ ] Strict skip check against existing phone numbers and names
- [ ] Intra-batch duplicate detection (second occurrence skipped)
- [ ] Incoming call display name generation (`name-dept-title` or standard `name`)
- [ ] Comprehensive unit tests verifying each skip reason and name format
