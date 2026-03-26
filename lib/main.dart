import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 加上这个
import 'package:supabase_flutter/supabase_flutter.dart'; // 加上这个
import 'utils/supabase_config.dart'; // 导入配置类
import 'screens/auth/login_screen.dart';

void main() async {
  // 1. 确保 Flutter 绑定初始化（异步 main 必须加这一行）
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 加载 .env 文件
  await dotenv.load(fileName: ".env");

  // 3. 初始化 Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // 4. 运行 App
  runApp(const PrisconApp());
}

class PrisconApp extends StatelessWidget {
  const PrisconApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Priscon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
