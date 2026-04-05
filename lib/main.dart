import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 加上这个
import 'package:supabase_flutter/supabase_flutter.dart'; // 加上这个
import 'package:flutter_stripe/flutter_stripe.dart';
import 'utils/supabase_config.dart'; // 导入配置类
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/globals.dart';
import 'utils/snackbar_helper.dart'; // 导入全局 snackbar key
import 'screens/auth/login_screen.dart';
import 'screens/core/home_screen.dart';

void main() async {
  // 1. 确保 Flutter 绑定初始化（异步 main 必须加这一行）
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 加载 .env 文件
  await dotenv.load(fileName: ".env");

  // 3. 初始化 Stripe
  Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  Stripe.urlScheme = 'flutterstripe';
  await Stripe.instance.applySettings();

  // 4. 初始化 Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  // 4. Persistence check
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('user_id');
  
  if (userId != null) {
     final supabase = Supabase.instance.client;
     currentUser = await supabase.from('user').select().eq('id', userId).maybeSingle();
  }

  // 4. 运行 App
  runApp(const PrisconApp());
}

class PrisconApp extends StatelessWidget {
  const PrisconApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Priscon',
      debugShowCheckedModeBanner: false, // hide debug function
      scaffoldMessengerKey: snackbarKey, // 注册全局 key
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true, // Use modern M3 UI
      ),
      home: currentUser != null ? const HomeScreen() : const LoginScreen(),
    );
  }
}
