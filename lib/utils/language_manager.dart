import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'globals.dart';

/// Manages the application language/locale and persists selection.
class LanguageManager extends ChangeNotifier {
  Locale _locale = const Locale('en', 'US');

  Locale get locale => _locale;

  // Convenient display names and codes
  static const List<Map<String, dynamic>> languages = [
    {'name': 'English (US)', 'code': 'en', 'country': 'US', 'label': '🇺🇸 Eng (US)'},
    {'name': 'Chinese 中国(CN)', 'code': 'zh', 'country': 'CN', 'label': '🇨🇳 中文 (CN)'},
    {'name': 'Bahasa Malaysia (BM)', 'code': 'ms', 'country': 'MY', 'label': '🇲🇾 Bahasa (BM)'},
  ];

  LanguageManager() {
    _loadLanguage();
  }

  /// Loads the saved language index from SharedPreferences.
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langIndex = prefs.getInt('language_index') ?? 0;
    
    if (langIndex >= 0 && langIndex < languages.length) {
      final lang = languages[langIndex];
      _locale = Locale(lang['code'], lang['country']);
      notifyListeners();
    }
  }

  /// Updates the language and persists the choice (Local + Supabase).
  Future<void> setLanguage(int index) async {
    if (index < 0 || index >= languages.length) return;
    
    final lang = languages[index];
    final newLocale = Locale(lang['code'], lang['country']);
    
    if (_locale == newLocale) return;
    
    _locale = newLocale;
    notifyListeners();

    // 1. Local Persistence
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('language_index', index);

    // 2. Database Persistence
    if (currentUser != null && currentUser!['id'] != null) {
      try {
        final supabase = Supabase.instance.client;
        await supabase
            .from('user')
            .update({'language': index})
            .eq('id', currentUser!['id']);

        // Update local memory map to keep it in sync
        currentUser!['language'] = index;
      } catch (e) {
        debugPrint('Error syncing language to Supabase: $e');
      }
    }
  }

  /// Direct sync from database (called after login/restore)
  void updateLanguageFromDatabase(int index) {
    if (index >= 0 && index < languages.length) {
      final lang = languages[index];
      _locale = Locale(lang['code'], lang['country']);
      notifyListeners();
    }
  }

  /// Reset to English (called after logout)
  Future<void> resetToDefault() async {
    _locale = const Locale('en', 'US');
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('language_index');
  }
}

// Global instance
final languageManager = LanguageManager();
