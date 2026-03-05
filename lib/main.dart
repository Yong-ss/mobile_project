import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';

void main() {
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
      // Navigation: all screens use Navigator.push, home is LoginScreen
      home: const LoginScreen(),
    );
  }
}sdjfsfjsjkfsdjkfsdjkfsdjkfsdjksdjkfsjknfsjkfsdjkfsjhknfsjkh