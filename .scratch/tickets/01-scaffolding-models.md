# 01: Project Scaffolding & Core Domain Models

**What to build:**
A standard Flutter 3 project structure with full Android configuration (including runtime permissions in AndroidManifest.xml, Gradle build configs, Material 3 theming), along with the complete set of core domain models (`RawContactData`, `ContactValidationItem`, `ValidationStatus`, `ColumnMapping`, `ImportProgress`, `ImportSummary`).

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] `pubspec.yaml` configured with required dependencies (`flutter_contacts`, `excel`, `csv`, `file_picker`, `permission_handler`)
- [ ] `AndroidManifest.xml` configured with `READ_CONTACTS` and `WRITE_CONTACTS` permissions
- [ ] Core domain models implemented with full serialization, copyWith, and equality methods
- [ ] Base entry point `lib/main.dart` with Material 3 theme initialized
