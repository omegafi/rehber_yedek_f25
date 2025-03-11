import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Provider'lar için
import '../screens/premium_screen.dart';
import '../screens/onboarding_screen.dart';
import '../utils/app_localizations.dart';
import '../theme/app_theme.dart';

// Ayarlar ekranı
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.lightBackgroundColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.lightTextColor;
    final primaryColor = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          context.l10n.settings_screen_title,
          style: TextStyle(color: textColor),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Dil Ayarları - En Üstte
          _buildSection(
            context,
            title: context.l10n.language_title,
            icon: Icons.language,
            color: primaryColor,
            textColor: textColor,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LanguageSelectionScreen(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getLanguageName(context, locale.languageCode),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getLanguageNativeName(locale.languageCode),
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: textColor.withOpacity(0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tema Ayarları
          _buildSection(
            context,
            title: context.l10n.theme_title,
            icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: primaryColor,
            textColor: textColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.dark_theme,
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    Switch(
                      value: isDarkMode,
                      onChanged: (value) => _toggleTheme(ref, context),
                      activeColor: primaryColor,
                    ),
                  ],
                ),
                Text(
                  isDarkMode
                      ? context.l10n.dark_theme_subtitle_on
                      : context.l10n.dark_theme_subtitle_off,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Eğitim ve Yardım
          _buildSection(
            context,
            title: context.l10n.guide_title,
            icon: Icons.help_outline,
            color: primaryColor,
            textColor: textColor,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.l10n.show_tutorial,
                style: TextStyle(color: textColor),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: textColor.withOpacity(0.7),
              ),
              onTap: () async {
                // Onboarding'i göster
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_completed', false);
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/onboarding');
                }
              },
            ),
          ),

          const SizedBox(height: 16),

          // Uygulama Hakkında
          _buildSection(
            context,
            title: context.l10n.about_app,
            icon: Icons.info_outline,
            color: primaryColor,
            textColor: textColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Uygulama Sürümü
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    context.l10n.app_version,
                    style: TextStyle(color: textColor),
                  ),
                ),
                Divider(color: textColor.withOpacity(0.2)),
                // Uygulama Açıklaması
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    context.l10n.app_description,
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
                Divider(color: textColor.withOpacity(0.2)),
                // Telif Hakkı Bilgisi
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    context.l10n.copyright,
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // İletişim Bilgileri
          Center(
            child: TextButton(
              onPressed: () {
                // İletişim sayfasını aç veya iletişim e-postası oluştur
              },
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
              child: Text(context.l10n.contact_us),
            ),
          ),
        ],
      ),
    );
  }

  // Bölüm widget'ı
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Color textColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // Dil adını döndüren yardımcı metod
  String _getLanguageName(BuildContext context, String code) {
    switch (code) {
      case 'en':
        return context.l10n.english;
      case 'tr':
        return context.l10n.turkish;
      case 'es':
        return context.l10n.spanish;
      case 'ja':
        return context.l10n.japanese;
      case 'de':
        return 'Almanca'; // Almanca
      case 'fr':
        return 'Fransızca'; // Fransızca
      default:
        return code;
    }
  }

  // Dil yerel adını döndüren yardımcı metod
  String _getLanguageNativeName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'tr':
        return 'Türkçe';
      case 'es':
        return 'Español';
      case 'ja':
        return '日本語';
      case 'de':
        return 'Deutsch';
      case 'fr':
        return 'Français';
      default:
        return code;
    }
  }

  // Tema değiştirme işlemi
  void _toggleTheme(WidgetRef ref, BuildContext context) async {
    // Tema durumunu değiştir
    ref.read(themeProvider.notifier).toggleTheme();

    // Değişikliği kaydet
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = ref.read(themeProvider) == ThemeMode.dark;
    await prefs.setBool('dark_theme', isDarkMode);
  }
}

// Dil Seçim Ekranı
class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.lightBackgroundColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.lightTextColor;
    final primaryColor = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          context.l10n.change_language,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Sistem dili seçeneği
          _buildLanguageOption(
            context,
            ref,
            'system',
            'Sistem Dili',
            'Cihaz dil ayarlarını kullan',
            currentLocale,
            isDarkMode,
            primaryColor,
            textColor,
            isSystem: true,
          ),

          // Dil seçenekleri
          Expanded(
            child: ListView(
              children: [
                _buildLanguageOption(
                  context,
                  ref,
                  'en',
                  context.l10n.english,
                  'English',
                  currentLocale,
                  isDarkMode,
                  primaryColor,
                  textColor,
                ),
                _buildLanguageOption(
                  context,
                  ref,
                  'tr',
                  context.l10n.turkish,
                  'Türkçe',
                  currentLocale,
                  isDarkMode,
                  primaryColor,
                  textColor,
                ),
                _buildLanguageOption(
                  context,
                  ref,
                  'es',
                  context.l10n.spanish,
                  'Español',
                  currentLocale,
                  isDarkMode,
                  primaryColor,
                  textColor,
                ),
                _buildLanguageOption(
                  context,
                  ref,
                  'ja',
                  context.l10n.japanese,
                  '日本語',
                  currentLocale,
                  isDarkMode,
                  primaryColor,
                  textColor,
                ),
                _buildLanguageOption(
                  context,
                  ref,
                  'de',
                  'Almanca',
                  'Deutsch',
                  currentLocale,
                  isDarkMode,
                  primaryColor,
                  textColor,
                ),
                _buildLanguageOption(
                  context,
                  ref,
                  'fr',
                  'Fransızca',
                  'Français',
                  currentLocale,
                  isDarkMode,
                  primaryColor,
                  textColor,
                ),
              ],
            ),
          ),

          // İptal butonu
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: primaryColor),
                ),
              ),
              child: Text(context.l10n.cancel),
            ),
          ),
        ],
      ),
    );
  }

  // Dil seçenek widget'ı
  Widget _buildLanguageOption(
    BuildContext context,
    WidgetRef ref,
    String code,
    String name,
    String displayName,
    Locale currentLocale,
    bool isDarkMode,
    Color primaryColor,
    Color textColor, {
    bool isSystem = false,
  }) {
    final isSelected = isSystem
        ? false // Sistem dili için özel kontrol
        : currentLocale.languageCode == code;

    return InkWell(
      onTap: () async {
        if (isSystem) {
          // Sistem dili seçildiğinde yapılacak işlemler
          // Şimdilik sadece geri dönelim
          Navigator.pop(context);
          return;
        }

        // Dili değiştir
        ref.read(localeProvider.notifier).state = Locale(code);

        // Değişikliği SharedPreferences'a kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language_code', code);

        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? Colors.white10 : Colors.black12,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? primaryColor : textColor,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
