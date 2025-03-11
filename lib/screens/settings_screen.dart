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
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final dividerColor =
        isDarkMode ? AppTheme.darkDividerColor : Colors.grey.withOpacity(0.2);
    final primaryColor = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: Colors.red,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red,
              Colors.red.shade800,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Ayarlar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Otomatik geçiş bilgisi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Otomatik geçiş şu anda aktif',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Ayarlar Listesi
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Dil Ayarları
                    _buildSettingsCard(
                      context,
                      title: 'Dil Ayarları',
                      icon: Icons.language,
                      onTap: () => _showLanguageDialog(context, ref),
                      content: _buildLanguageContent(context, locale),
                    ),

                    SizedBox(height: 16),

                    // Tema Ayarları
                    _buildSettingsCard(
                      context,
                      title: 'Tema Ayarları',
                      icon: Icons.palette,
                      onTap: () {},
                      content: _buildThemeContent(context, isDarkMode, ref),
                    ),

                    SizedBox(height: 16),

                    // Ses Ayarları
                    _buildSettingsCard(
                      context,
                      title: 'Ses Ayarları',
                      icon: Icons.volume_up,
                      onTap: () {},
                      content: _buildSoundContent(context),
                    ),

                    SizedBox(height: 24),

                    // Varsayılanlara Sıfırla Butonu
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextButton.icon(
                        onPressed: () => _resetToDefaults(context, ref),
                        icon: Icon(
                          Icons.refresh,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Varsayılanlara Sıfırla',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        style: ButtonStyle(
                          padding: MaterialStateProperty.all(
                            EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Ayarlar kartı widget'ı
  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Dil içeriği
  Widget _buildLanguageContent(BuildContext context, Locale locale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getLanguageName(context, locale.languageCode),
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Dili değiştirmek için dokun',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
        Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 20,
        ),
      ],
    );
  }

  // Tema içeriği
  Widget _buildThemeContent(
      BuildContext context, bool isDarkMode, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDarkMode ? 'Koyu Tema' : 'Açık Tema',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Temayı değiştirmek için dokun',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
        Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 20,
        ),
      ],
    );
  }

  // Ses içeriği
  Widget _buildSoundContent(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sesler Açık',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Sesleri ayarlamak için dokun',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
        Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 20,
        ),
      ],
    );
  }

  // Dil seçim diyaloğu
  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.read(localeProvider);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.pink.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  'Dil Ayarları',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              _buildLanguageOption(
                context,
                ref,
                title: 'Sistem Dili',
                subtitle: 'Cihaz dil ayarlarını kullan',
                locale: null,
                currentLocale: currentLocale,
              ),
              _buildLanguageOption(
                context,
                ref,
                title: 'English',
                subtitle: 'İngilizce',
                locale: const Locale('en'),
                currentLocale: currentLocale,
              ),
              _buildLanguageOption(
                context,
                ref,
                title: 'Türkçe',
                subtitle: 'Türkçe',
                locale: const Locale('tr'),
                currentLocale: currentLocale,
                isSelected: true,
              ),
              _buildLanguageOption(
                context,
                ref,
                title: 'Español',
                subtitle: 'İspanyolca',
                locale: const Locale('es'),
                currentLocale: currentLocale,
              ),
              _buildLanguageOption(
                context,
                ref,
                title: '日本語',
                subtitle: 'Japonca',
                locale: const Locale('ja'),
                currentLocale: currentLocale,
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'İptal',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Dil seçeneği
  Widget _buildLanguageOption(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required Locale? locale,
    required Locale currentLocale,
    bool isSelected = false,
  }) {
    final isCurrentLocale = locale?.languageCode == currentLocale.languageCode;

    return InkWell(
      onTap: () {
        if (locale != null) {
          ref.read(localeProvider.notifier).state = locale;
        }
        Navigator.pop(context);
      },
      child: Container(
        color: isSelected ? Colors.red.withOpacity(0.1) : null,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.red,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  // Tema değiştirme
  void _toggleTheme(WidgetRef ref, BuildContext context) {
    final currentTheme = ref.read(themeProvider);
    final newTheme =
        currentTheme == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    ref.read(themeProvider.notifier).state = newTheme;
  }

  // Varsayılanlara sıfırlama
  void _resetToDefaults(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Varsayılanlara Sıfırla'),
        content: Text(
            'Tüm ayarlar varsayılan değerlerine sıfırlanacak. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              // Tema sıfırlama
              ref.read(themeProvider.notifier).state = ThemeMode.light;

              // Dil sıfırlama
              ref.read(localeProvider.notifier).state = const Locale('tr');

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ayarlar varsayılanlara sıfırlandı'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Sıfırla'),
          ),
        ],
      ),
    );
  }

  // Dil adını getir
  String _getLanguageName(BuildContext context, String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'tr':
        return 'Türkçe';
      case 'es':
        return 'Español';
      case 'ja':
        return '日本語';
      default:
        return 'Unknown';
    }
  }
}
