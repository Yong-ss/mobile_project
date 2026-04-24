import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 加上这个
import 'package:supabase_flutter/supabase_flutter.dart'; // 加上这个
import 'package:flutter_stripe/flutter_stripe.dart';
import 'utils/supabase_config.dart'; // 导入配置类
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/globals.dart';
import 'utils/theme_manager.dart';
import 'utils/language_manager.dart';
import 'utils/snackbar_helper.dart'; // 导入全局 snackbar key
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/auth/login_screen.dart';
import 'screens/core/home_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/core/splash_screen.dart';

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

    // Sync theme and language from database immediately if user is restored
    if (currentUser != null) {
      if (currentUser!['appearance'] != null) {
        themeManager.updateThemeFromDatabase(currentUser!['appearance'] as int);
      }
      if (currentUser!['language'] != null) {
        languageManager.updateLanguageFromDatabase(currentUser!['language'] as int);
      }
    }
  }

  // 4. 运行 App
  runApp(const PrisconApp());
}

class PrisconApp extends StatelessWidget {
  const PrisconApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeManager, languageManager]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Priscon',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: snackbarKey,
          locale: languageManager.locale,
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('zh', 'CN'),
            Locale('ms', 'MY'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Isolation Logic: Use user preference only if logged in, otherwise follow System Theme
          themeMode: currentUser != null ? themeManager.themeMode : ThemeMode.system,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.lightBlue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              titleTextStyle: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.lightBlue,
              brightness: Brightness.dark,
              surface: const Color(0xFF212121),
            ),
            scaffoldBackgroundColor: const Color(0xFF212121),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF212121),
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              iconTheme: IconThemeData(color: Colors.white),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}