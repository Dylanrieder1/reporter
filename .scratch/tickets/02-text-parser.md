# 02: Clipboard Text Intelligent Splitter & Parser

**What to build:**
A robust, fault-tolerant text parser that takes multi-line strings copied from clipboard (WeChat, DingTalk, text files) with irregular spacing, tabs (`\t`), or commas (`,`), automatically identifies Chinese mobile numbers (11 digits, handling `+86`, prefixes, dashes, spaces), separates personal name, department, and title, and converts them into `RawContactData` items. Includes comprehensive unit tests.

**Blocked by:** 01-scaffolding-models

**Status:** ready-for-agent

- [ ] Phone regex matching 11-digit Chinese numbers with optional country code (+86/0086) and formatting symbols
- [ ] Delimiter parsing supporting mixed tabs, spaces, and commas
- [ ] Name, department, and title extraction logic tolerant of varying field ordering
- [ ] Empty line and noise line filtering
- [ ] Unit test suite covering all dirty text edge cases
