/// 从手机系统通讯录读取出的可导出联系人
class DeviceContact {
  final String displayName;
  final String phone;
  final String department;
  final String title;

  const DeviceContact({
    required this.displayName,
    required this.phone,
    this.department = '',
    this.title = '',
  });

  bool get isEmpty => displayName.trim().isEmpty && phone.trim().isEmpty;

  @override
  String toString() =>
      'DeviceContact($displayName, $phone, $department, $title)';
}
