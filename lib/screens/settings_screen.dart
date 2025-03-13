import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Provider'lar için
import '../screens/premium_screen.dart';
import '../screens/onboarding_screen.dart';
import '../utils/app_localizations.dart';
import '../theme/app_theme.dart';
import '../providers/localization_provider.dart';

// Numarası olmayan kişileri dahil etme durumu
final includeContactsWithoutNumberProvider = StateProvider<bool>((ref) => true);

// İsmi olmayan numaraları dahil etme durumu
final includeNumbersWithoutNameProvider = StateProvider<bool>((ref) => true);

// Ayarlar ekranı
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    // Rehber filtreleme ayarları
    final includeContactsWithoutNumber =
        ref.watch(includeContactsWithoutNumberProvider);
    final includeNumbersWithoutName =
        ref.watch(includeNumbersWithoutNameProvider);

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
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme:
            IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
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
              onTap: () => _showLanguageSelectionDialog(context, ref),
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

          // Rehber Filtreleme Ayarları
          _buildSection(
            context,
            title: 'Rehber Filtreleme',
            icon: Icons.filter_list,
            color: primaryColor,
            textColor: textColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Numarası olmayan kişileri dahil etme
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Numarası olmayan kişileri dahil et',
                            style: TextStyle(
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Telefon numarası olmayan kişileri yedeklemeye dahil et',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: includeContactsWithoutNumber,
                      onChanged: (value) async {
                        ref
                            .read(includeContactsWithoutNumberProvider.notifier)
                            .state = value;

                        // Değişikliği kaydet
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(
                            'include_contacts_without_number', value);
                      },
                      activeColor: primaryColor,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // İsmi olmayan numaraları dahil etme
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'İsmi olmayan numaraları dahil et',
                            style: TextStyle(
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'İsim bilgisi olmayan telefon numaralarını yedeklemeye dahil et',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: includeNumbersWithoutName,
                      onChanged: (value) async {
                        ref
                            .read(includeNumbersWithoutNameProvider.notifier)
                            .state = value;

                        // Değişikliği kaydet
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(
                            'include_numbers_without_name', value);
                      },
                      activeColor: primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Premium Seçeneği
          _buildSection(
            context,
            title: context.l10n.premium_title,
            icon: Icons.workspace_premium,
            color: AppTheme.primaryColor,
            textColor: textColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Premium\'a Yükselt',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Sınırsız kişi yedekleme ve daha fazla özellik',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: textColor.withOpacity(0.7),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/premium');
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Premium üyelik ile tüm kişilerinizi yedekleyebilir ve ek özelliklerden faydalanabilirsiniz.',
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? Color(0xFF1E1E1E)
            : Color(
                0xFFFCE4EC), // Dark tema için koyu, light tema için açık pembe
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
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

  // Dil seçim dialogunu gösteren metodu düzenliyorum
  void _showLanguageSelectionDialog(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Color(0xFF1E1E1E)
                  : Color(
                      0xFFFCE4EC), // Dark tema için koyu, light tema için açık pembe
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0, left: 8.0),
                  child: Text(
                    'Dil Ayarları',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Divider(
                    height: 1,
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                _buildLanguageOption(context, ref, 'Sistem Dili', 'system',
                    currentLocale, 'Cihaz dil ayarlarını kullan'),
                Divider(
                    height: 1,
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                _buildLanguageOption(
                    context, ref, 'English', 'en', currentLocale, 'İngilizce'),
                Divider(
                    height: 1,
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                _buildLanguageOption(
                    context, ref, 'Türkçe', 'tr', currentLocale, 'Türkçe'),
                Divider(
                    height: 1,
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                _buildLanguageOption(
                    context, ref, 'Español', 'es', currentLocale, 'İspanyolca'),
                Divider(
                    height: 1,
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                _buildLanguageOption(
                    context, ref, '日本語', 'ja', currentLocale, 'Japonca'),
                Divider(
                    height: 1,
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'İptal',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(BuildContext context, WidgetRef ref, String title,
      String localeCode, Locale currentLocale, String subtitle) {
    final isSelected = currentLocale.languageCode == localeCode;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        // Dili değiştir
        ref.read(localeProvider.notifier).state = Locale(localeCode);

        // Değişikliği SharedPreferences'a kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language_code', localeCode);

        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD32F2F), // Kırmızı onay işareti
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
