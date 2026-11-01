# 03: Excel & CSV Table Parser with Smart Header Detection

**What to build:**
A table parser service that handles `.xlsx`, `.xls`, and `.csv` byte streams, infers header column mappings via weighted Chinese keyword matching for "姓名", "手机号", "部门", and "职位", supports manual fallback overrides via `ColumnMapping`, and extracts clean `RawContactData` rows. Includes unit test suite for table reading and header scoring.

**Blocked by:** 01-scaffolding-models

**Status:** ready-for-agent

- [ ] Smart header scoring engine recognizing synonymous terms for Name, Phone, Dept, and Title
- [ ] Fallback column mapping selector logic for unmapped or custom headers
- [ ] Multi-sheet and blank row handling in Excel workbooks
- [ ] CSV parsing with RFC 4180 delimiter handling
- [ ] Unit tests for header detection and row extraction
