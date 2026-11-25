/// 手机系统通讯录中的联系人（带系统分配 id，用于通讯录管理与批量删除）
class ManagedContact {
  /// 系统通讯录分配的唯一 id（删除时使用）
  final String id;
  final String displayName;
  final String phone;
  final String department;

  const ManagedContact({
    required this.id,
    required this.displayName,
    this.phone = '',
    this.department = '',
  });

  @override
  String toString() => 'ManagedContact($id, $displayName, $phone)';
}
