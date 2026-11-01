import 'package:permission_handler/permission_handler.dart';

/// 通讯录权限申请与状态检测服务
class PermissionService {
  /// 检查是否已授予通讯录读写权限
  static Future<bool> hasContactsPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  /// 申请通讯录读写权限
  static Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// 引导用户打开系统应用设置（若权限被永久拒绝）
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
