import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'globals.dart';

/// Manages the application theme mode (Light, Dark, System) and persists selection.
class ThemeManager extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeManager() {
    _loadTheme();
  }

  /// Loads the saved theme mode from SharedPreferences.
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0; // 0: system, 1: light, 2: dark
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  /// Updates the theme mode and persists the choice (Local + Supabase).
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    // 1. Local Persistence
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);

    // 2. Database Persistence
    if (currentUser != null && currentUser!['id'] != null) {
      try {
        final supabase = Supabase.instance.client;
        await supabase
            .from('user')
            .update({'appearance': mode.index})
            .eq('id', currentUser!['id']);

        // Update local memory map to keep it in sync
        currentUser!['appearance'] = mode.index;
      } catch (e) {
        debugPrint('Error syncing appearance to Supabase: $e');
      }
    }
  }

  /// Direct sync from database (called after login/restore)
  void updateThemeFromDatabase(int index) {
    if (index >= 0 && index < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[index];
      notifyListeners();
    }
  }

  /// Reset to system theme (called after logout)
  Future<void> resetToSystem() async {
    _themeMode = ThemeMode.system;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('theme_mode');
  }
}

// Global instance
final themeManager = ThemeManager();