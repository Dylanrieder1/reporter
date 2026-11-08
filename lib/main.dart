import 'dart:ui';
import 'package:flutter/material.dart';
import 'views/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局异常拦截，防止任何未捕获异常导致 App 意外闪退
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error caught by dispatcher: $error');
    return true; // 告知系统已处理，防止进程直接被系统杀死
  };

  runApp(const ContactsImporterApp());
}

class ContactsImporterApp extends StatelessWidget {
  const ContactsImporterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '通讯录导入助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
      ),
      home: const HomePage(),
    );
  }
}
