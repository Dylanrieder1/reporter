# 通讯录导入助手 (Contacts Importer) - 需求与技术规范 (Spec)

## Problem Statement

现代企业办公中，员工经常需要对接大量同事或外部合作方的手机小号、虚拟号。这些信息通常分散在微信群公告、钉钉通知、Excel 表格或 CSV 文件中（包含姓名、手机小号、部门、职位等信息）。手动逐条录入手机通讯录耗时费力，且存在以下痛点：
1. **来电无法识别部门**：部分国产安卓系统（HyperOS、OriginOS、ColorOS 等）来电弹窗默认仅展示联系人姓名，不展示组织/部门字段，导致接听时无法直观识别来电者部门。
2. **重复与冲突风险**：直接导入可能覆盖或污染手机已有的个人/好友联系人。
3. **格式多样繁杂**：表格列顺序不固定，或直接从聊天软件复制的文本排版不规则（含有制表符、空格、逗号混合等）。

用户需要一款轻便、安全、纯本地运行的 Android 手机 App，能够智能解析 Excel/CSV 文件及剪贴板文本，严格查重，并支持来电显示优化，将联系人批量导入手机通讯录。

---

## Solution

开发基于 Flutter 跨平台架构的**通讯录导入助手** Android App，提供以下核心解决方案：
1. **双通道数据输入**：支持选取本地 Excel (.xlsx/.xls) 与 CSV 文件，同时支持从剪贴板直接粘贴多行文本。
2. **智能列匹配与容错解析**：
   - 表格文件自动识别包含“姓名、手机/电话、部门、职位”的表头，支持界面手动微调下拉映射。
   - 剪贴板文本采用基于手机号正则的容错切分算法，自适应空格、制表符、逗号混排文本。
3. **严格跳过查重机制**：导入前检索手机本地通讯录，只要“手机号”或“姓名”任意一项已存在，自动标记跳过，绝不修改、覆盖或重复创建既有联系人。
4. **来电显示优化开关**：在写入标准 Android 组织（部门、职位）字段的同时，提供“来电显示优化：姓名后附加部门/职位”开关（如生成：`张三-技术部-架构师`）。
5. **导入前交互式核对与进度呈现**：解析后先进入预览页面，清晰标识有效条数与跳过原因；确认导入后显示实时进度条（百分比与计数），完成后输出统计报告。
6. **极简独立存储**：直接写入系统默认通讯录，不强制创建冗余分组，无需网络连接，完全离线保护隐私。

---

## User Stories

1. 作为一名企业员工，我希望能够选择本地的 Excel (.xlsx / .xls) 或 CSV 文件进行解析，以便将部门批量下发的人员名单一键载入。
2. 作为一名手机用户，我希望能够直接粘贴从微信或钉钉复制的通讯录文本，以便无需额外制作表格文件也能快速导入。
3. 作为一名用户，我希望 App 能够自动识别表格中哪一列是姓名、手机号、部门和职位，以便减少繁琐的手动配置。
4. 作为一名用户，当表格表头命名不规则时，我希望能在界面上通过下拉框手动指定每一列的对应关系，以便适配各种自定义模板。
5. 作为一名用户，我希望在文本粘贴模式下，即使列之间混合使用了空格、Tab 制表符或逗号，App 也能准确提取出手机号与姓名，以便容忍随意排版的文本。
6. 作为一名用户，我希望在数据写入手机前能够进入“预览核对页面”，查看总共解析出多少条、有效多少条、跳过多少条，以便心中有数。
7. 作为一名用户，我希望在预览页面看到每条联系人的跳过原因（例如“手机号已存在”、“姓名已存在”、“手机号格式不合法”），以便排查异常数据。
8. 作为一名用户，我希望系统严格执行跳过策略，只要手机号或姓名已存在就绝不重复写入，以便保护我现有的个人通讯录不被破坏。
9. 作为一名经常接听内部来电的用户，我希望可以开启“姓名后附加部门/职位”选项（如 `张三-研发部`），以便在手机来电界面第一眼看清对方身份。
10. 作为一名注重隐私的用户，我希望在首次导入时 App 明确提示通讯录权限用途，并且整个处理在本地离线完成，以便确保通讯录数据不泄漏。
11. 作为一名用户，在导入大量联系人时，我希望看到动态百分比进度条（如 `正在导入: 35/120 (29%)`），以便感知导入进度。
12. 作为一名用户，在导入完成后我希望看到统计弹窗（成功导入 X 条，跳过 Y 条），并可点击返回主界面，以便确认操作结果。
13. 作为一名用户，我希望输入的手机号如果带有 `+86` 或横杠空格（如 `138-0000-0000`），系统能自动格式化为标准 11 位数字，以便正常拨号。

---

## Implementation Decisions

### 1. 技术栈与模块架构
- **技术框架**：Flutter 3.x + Dart 3.x（Material 3 设计规范）。
- **平台支持**：Android (minSdkVersion 24, targetSdkVersion 34+)。
- **核心依赖包**：
  - `flutter_contacts`: 负责通讯录权限检查、联系人查询（查重）与组织架构（部门/职位）原生字段写入。
  - `excel`: 解析 `.xlsx` 和 `.xls` 二进制工作簿。
  - `csv`: 解析 RFC 4180 及松散格式 CSV 文本。
  - `file_picker`: 遵循 Android Storage Access Framework (SAF) 进行安全文件选择。
  - `permission_handler`: 运行时权限申请与状态管理。

### 2. 核心模块与接口设计

#### 2.1 数据模型 (Models)
- `RawContactData`: 包含原始字符串 `name`, `phone`, `department`, `title`。
- `ContactValidationItem`: 封装待导入项，包含：
  - `contact`: `RawContactData`
  - `status`: `valid` | `skippedDuplicatePhone` | `skippedDuplicateName` | `skippedInvalidPhone` | `skippedEmptyName`
  - `formattedDisplayName`: 根据用户配置生成的最终姓名（例如原名或附加部门/职位后的名称）
- `ColumnMapping`: 记录 Excel/CSV 中 `nameColumnIndex`, `phoneColumnIndex`, `deptColumnIndex`, `titleColumnIndex`。

#### 2.2 文本与文件解析服务 (Parsers)
- `TextParserService`:
  - 核心接口：`List<RawContactData> parseText(String input)`
  - 规则：按行切分；对每行使用中国标准手机号正则 `(?:(?:\+|00)86)?\s*(1[3-9]\d{9})` 提取手机号；剩余分段按空格/制表符/逗号拆分，匹配姓名、部门、职位。
- `ExcelParserService`:
  - 核心接口：
    - `Future<ParsedTableResult> parseFileBytes(Uint8List bytes, String fileName)`
    - `ColumnMapping detectHeaderMapping(List<String> headers)`
    - `List<RawContactData> extractRows(List<List<dynamic>> rows, ColumnMapping mapping)`
  - 匹配关键词权重：
    - 姓名：`姓名`, `名字`, `联系人`, `员工姓名`, `name`
    - 手机号：`手机`, `电话`, `小号`, `联系电话`, `移动电话`, `phone`, `mobile`
    - 部门：`部门`, `科室`, `机构`, `单位`, `所属部门`, `department`, `dept`
    - 职位：`职位`, `职务`, `岗位`, `工种`, `title`, `position`

#### 2.3 查重校验引擎 (ContactValidator)
- 核心接口：
  - `List<ContactValidationItem> validateAndDeduplicate({required List<RawContactData> rawList, required Set<String> existingPhones, required Set<String> existingNames, required bool appendDeptTitleToName})`
- 规则：
  - 清洗手机号：去除非数字字符，去除开头的 `86` 或 `+86`。若清洗后不满足 11 位数字，标记为 `skippedInvalidPhone`。
  - 姓名为空，标记为 `skippedEmptyName`。
  - 手机号存在于 `existingPhones`，标记为 `skippedDuplicatePhone`。
  - 姓名存在于 `existingNames`，标记为 `skippedDuplicateName`。
  - 同一批次内部去重：若前文已出现同手机号，后续重复项同样标记为 `skippedDuplicatePhone`。

#### 2.4 通讯录写入服务 (ContactsService)
- 核心接口：
  - `Future<bool> requestPermission()`
  - `Future<ExistingContactsCache> fetchExistingContacts()`
  - `Stream<ImportProgress> importContactsStream(List<ContactValidationItem> validItems)`
- 写入字段映射：
  - `DisplayName`: 格式化后的姓名。
  - `Phone`: `CommonDataKinds.Phone.NUMBER`，标签设为 `mobile`。
  - `Organization`: `CommonDataKinds.Organization.DEPARTMENT` 存部门，`TITLE` 存职位。

---

## Testing Decisions

### 1. 测试原则与要求
- 遵循测试驱动开发（TDD）原则，测试公共行为边界与核心逻辑，不耦合私有实现。
- 断言基于独立已知的真实数据基准，杜绝重算型同义反复断言。

### 2. 核心测试接缝 (Seams)
- **Seam 1: `TextParserService`（纯函数逻辑接缝）**
  - 测试用例：标准制表符粘贴、逗号分隔、多空格混排、带+86手机号、带横线手机号、乱序字段、空行与异常行。
- **Seam 2: `ExcelParserService`（表头推断与行提取接缝）**
  - 测试用例：标准列头识别、反转列顺序识别、同义词列头识别、无表头默认退化处理、缺失部门/职位的行提取。
- **Seam 3: `ContactValidator`（查重与来电格式化接缝）**
  - 测试用例：手机号重复跳过、姓名重复跳过、批次内自我重复跳过、非法号码跳过、来电姓名拼接开关测试（开/关）。

---

## Out of Scope

1. **联系人分组/群组维护**：用户明确选择极简独立联系人导入，不创建自定义通讯录群组。
2. **导入历史与一键撤销删除**：不维护本地数据库与历史删除功能，避免增加系统复杂度和存储占用。
3. **覆盖修改已有联系人**：严格跳过，不主动修改手机上已有的同名或同号码联系人。
4. **云端账号同步与网络接口**：纯离线运行，不连接任何第三方网络服务。

---

## Further Notes

- 项目代码将按照标准 Flutter 目录结构组织，附带完备的纯 Dart 单元测试套件，可直接使用 `dart test` 验证。
- 考虑到本地未配置全局 Flutter CLI，我们将配套提供独立的 Dart/Python 验证驱动脚本及自动化测试用例，确保每一个垂直切片在当前环境下均可 100% 验证通过。
