# 通讯录导入助手 (Contacts Importer App)

一款轻便、安全、纯本地运行的 Android 手机 App，支持将已知的**手机小号、部门、姓名、职位**一键批量导入到手机系统通讯录中。

---

## 🌟 核心特性

1. **双通道数据导入**：
   - **Excel (.xlsx / .xls) / CSV 表格**：通过安全文件选择器读取，支持自动识别常见表头与手动下拉微调列映射。
   - **剪贴板文本粘贴**：支持从微信群、钉钉等直接复制多行文本粘贴，自动容错制表符（`\t`）、逗号（`,`）及空格混排。
2. **来电显示优化（特色功能）**：
   - 提供开关 **“来电显示优化：在姓名后附带部门/职位”**（例如：`张三-技术部-架构师`）。
   - 解决部分安卓手机（如小米 HyperOS、vivo OriginOS、OPPO ColorOS 等）来电弹窗默认不展示部门字段的痛点，确保来电时第一眼看清对方身份与部门。
3. **严格跳过查重机制**：
   - 导入前智能检索本机已有通讯录。
   - 只要系统通讯录中**手机号**或**姓名**已存在，自动标记为“跳过”，绝不破坏或覆盖既有个人联系人，防止重复冗余。
4. **导入前交互式核对与进度呈现**：
   - 导入前提供清晰的核对列表，直观展示就绪数量、跳过原因（号码已存在、姓名已存在、格式异常等）。
   - 点击“开始写入”后带平滑进度条（百分比与计数）异步写入，完成后弹出导入统计报告。
5. **极简安全与隐私**：
   - 不强制创建分组，直接写入系统原生通讯录。
   - 全程纯本地离线运行，无需连网，绝对保护通讯录隐私。

---

## 🛠️ 项目工程结构

```text
通讯录系统/
├── .scratch/
│   └── tickets/                     # 垂直切片任务卡（Tracer Bullet Tickets）
├── android/
│   └── app/src/main/AndroidManifest.xml # 声明 READ_CONTACTS 与 WRITE_CONTACTS 权限
├── lib/
│   ├── main.dart                    # App 入口与 Material 3 主题配置
│   ├── models/                      # 核心数据模型
│   │   ├── raw_contact_data.dart    # 原始解析联系人
│   │   ├── column_mapping.dart      # 表格列映射模型
│   │   ├── contact_validation_item.dart # 校验条目与状态枚举
│   │   ├── import_progress.dart     # 实时写入进度
│   │   └── import_summary.dart      # 最终结果统计
│   ├── services/                    # 核心业务服务
│   │   ├── permission_service.dart  # 通讯录运行时权限处理
│   │   ├── excel_parser_service.dart# Excel 与 CSV 表格解析及智能表头识别
│   │   ├── text_parser_service.dart # 剪贴板文本正则智能提取与注释过滤
│   │   ├── contact_validator.dart   # 严格查重引擎与来电姓名生成器
│   │   └── contacts_service.dart    # 通讯录异步批量流式写入（支持 Mock 接口）
│   └── views/                       # UI 页面与组件
│       ├── home_page.dart           # 首页（文件导入 Tab / 剪贴板粘贴 Tab）
│       ├── preview_page.dart        # 预览核对页（来电开关、统计卡片、分类筛选）
│       └── import_progress_dialog.dart # 实时写入进度与完成结果弹窗
├── test/                            # 自动化测试套件
│   ├── text_parser_service_test.dart
│   ├── excel_parser_service_test.dart
│   ├── contact_validator_test.dart
│   ├── contacts_service_test.dart
│   ├── widget_test.dart
│   └── verify_full_pipeline_test.py # 端到端集成验证与 1000 条大数据边界测试
├── pubspec.yaml                     # 项目依赖与元数据配置
├── SPEC.md                          # 需求与技术规范说明书
└── README.md                        # 项目使用与部署文档
```

---

## 🚀 运行与构建指引

### 1. 环境准备
若本机尚未安装 Flutter SDK，请前往官网下载：
- **Flutter 官方下载**：[https://docs.flutter.cn/get-started/install/windows/mobile](https://docs.flutter.cn/get-started/install/windows/mobile)
- 解压后将 `flutter/bin` 目录添加到系统环境变量 `Path` 中。
- 确认安装：打开终端运行 `flutter doctor`。

### 2. 获取依赖包
在本项目根目录下运行：
```bash
flutter pub get
```

### 3. 运行自动化测试
执行单元测试与 Widget 界面测试：
```bash
flutter test
```
执行独立的全链路与 1000 条大数据边界回归测试：
```bash
python test/verify_full_pipeline_test.py
```

### 4. 连接真机/模拟器调试运行
开启手机的“开发者模式”和“USB 调试”，通过 USB 连接电脑：
```bash
flutter run
```

### 5. 编译正式发布版 APK
如需生成直接安装在手机上的 APK 安装包：
```bash
flutter build apk --release
```
编译生成的 APK 文件路径位于：
`build/app/outputs/flutter-apk/app-release.apk`
直接将该 APK 发送到安卓手机安装即可使用。

---

## 🔒 权限说明

应用在 `android/app/src/main/AndroidManifest.xml` 中声明了以下必要权限：
- `android.permission.READ_CONTACTS`: 用于在导入前读取现有通讯录中的电话和姓名，执行严格查重跳过。
- `android.permission.WRITE_CONTACTS`: 用于将确认无误的联系人批量写入系统通讯录。
- 文件读取采用了现代 Android 的 SAF (Storage Access Framework) 机制，无需申请敏感的全局外部存储管理权限，完全符合 Google Play 及国内各大应用市场安全合规要求。
