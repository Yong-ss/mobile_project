import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 加上这个
import 'package:supabase_flutter/supabase_flutter.dart'; // 加上这个
import 'utils/supabase_config.dart'; // 导入配置类
import 'screens/auth/login_screen.dart';
import 'screens/core/home_screen.dart';

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
  final session = Supabase.instance.client.auth.currentSession;

  // 4. 运行 App
  runApp(PrisconApp(initialSession: session));
}

class PrisconApp extends StatelessWidget {
  final Session? initialSession;
  const PrisconApp({super.key, this.initialSession});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Priscon',
      debugShowCheckedModeBanner: false, // hide debug function
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true, // Use modern M3 UI
      ),
      home: initialSession != null ? const HomeScreen() : const LoginScreen(),
    );
  }
}
