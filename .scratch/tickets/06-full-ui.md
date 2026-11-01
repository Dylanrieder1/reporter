# 06: Interactive Material 3 UI & Complete User Flow

**What to build:**
The complete user interface built with Flutter Material 3, including:
1. `HomePage`: Tabbed layout between "Excel/CSV 文件导入" and "剪贴板快速粘贴", file picker integration, pasted text preview, and dynamic column mapping dropdowns.
2. `PreviewPage`: Visual summary of valid items vs skipped items, detailed badge-coded list of contacts with skip reasons, toggle switch for "来电显示优化：姓名后附加部门/职位", and "开始导入" action button.
3. `ImportProgressDialog`: Real-time animated progress bar (`X / Total (Y%)`), completion report summary dialog.

**Blocked by:** 05-contacts-service

**Status:** ready-for-agent

- [ ] Material 3 responsive styling and clean Chinese UI typography
- [ ] File selection and raw text paste view with auto-trigger parser
- [ ] Header column mapping dropdown selector
- [ ] Preview verification page with skip status tags
- [ ] Import progress modal and final result summary dialog
