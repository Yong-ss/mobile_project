import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../utils/snackbar_helper.dart';
import 'edit_profile.dart';
import '../../utils/theme_manager.dart';
import '../../utils/language_manager.dart';
import '../../utils/translations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _profileUpdated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Premium reveal strategy
    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('settings'), style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _profileUpdated),
        ),
      ),
      body: _isLoading
          ? const SettingsSkeleton()
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                t('account'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Colors.grey,
                ),
              ),
            ),
            _buildSettingTile(
              icon: Icons.person_outline,
              color: Colors.blue,
              title: t('edit_profile'),
              subtitle: t('edit_profile_sub'),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                );
                if (result == true) {
                  setState(() => _profileUpdated = true);
                }
              },
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
              child: Text(
                t('appearance'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Colors.grey,
                ),
              ),
            ),

            // Premium Segmented Appearance Selector
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white24
                      : Colors.grey.shade200,
                  width: 1.2,
                ),
              ),
              child: ListenableBuilder(
                  listenable: themeManager,
                  builder: (context, _) {
                    return Row(
                      children: [
                        _buildAppearanceOption(
                          mode: ThemeMode.light,
                          label: t('light'),
                          icon: Icons.light_mode_outlined,
                        ),
                        _buildAppearanceOption(
                          mode: ThemeMode.system,
                          label: t('system'),
                          icon: Icons.brightness_auto_outlined,
                        ),
                        _buildAppearanceOption(
                          mode: ThemeMode.dark,
                          label: t('dark'),
                          icon: Icons.dark_mode_outlined,
                        ),
                      ],
                    );
                  }
              ),
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
                listenable: languageManager,
                builder: (context, _) {
                  final currentLang = LanguageManager.languages.firstWhere(
                        (l) => l['code'] == languageManager.locale.languageCode,
                    orElse: () => LanguageManager.languages.first,
                  );
                  return _buildSettingTile(
                    icon: Icons.language,
                    color: Colors.orange,
                    title: t('language'),
                    subtitle: currentLang['label'],
                    onTap: _showLanguageSelector,
                  );
                }
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceOption({
    required ThemeMode mode,
    required String label,
    required IconData icon,
  }) {
    final bool isSelected = themeManager.themeMode == mode;
    final Color activeColor = Colors.lightBlue.shade600;

    return Expanded(
      child: GestureDetector(
        onTap: () => themeManager.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : Colors.grey.shade400,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white24
              : Colors.grey.shade200,
          width: 1.2,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('choose_language'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ...List.generate(LanguageManager.languages.length, (index) {
                final lang = LanguageManager.languages[index];
                final isSelected = languageManager.locale.languageCode == lang['code'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.lightBlue.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.lightBlue : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: ListTile(
                    leading: Text(lang['label'].split(' ').first, style: const TextStyle(fontSize: 24)),
                    title: Text(lang['name'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.lightBlue) : null,
                    onTap: () {
                      languageManager.setLanguage(index);
                      Navigator.pop(context);
                    },
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}