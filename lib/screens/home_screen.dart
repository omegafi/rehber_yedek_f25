import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/contact_format.dart';
import '../services/contacts_service.dart';
import '../services/file_sharing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/contact_list_item.dart';
import '../main.dart'; // Provider'lar için
import '../utils/app_localizations.dart'; // Lokalizasyon için
import 'export_screen.dart';
import 'import_screen.dart';
import 'settings_screen.dart';

// Rehber izin durumu sağlayıcısı - main.dart'tan geliyor
import '../main.dart' show contactsPermissionProvider;

// Rehber sayısı sağlayıcısı
final contactsCountProvider = FutureProvider<int>((ref) async {
  // İzin durumunu kontrol et
  final permissionStatus = ref.watch(contactsPermissionProvider);

  if (permissionStatus != PermissionStatus.granted) {
    return 0; // İzin yoksa 0 döndür
  }

  final contactsManager = ContactsManager();
  final contacts = await contactsManager.getAllContacts();
  return contacts.length;
});

// Kişiler listesi sağlayıcısı
final contactsListProvider = FutureProvider<List<Contact>>((ref) async {
  // İzin durumunu kontrol et
  final permissionStatus = ref.watch(contactsPermissionProvider);

  if (permissionStatus != PermissionStatus.granted) {
    return []; // İzin yoksa boş liste döndür
  }

  final contactsManager = ContactsManager();
  final contacts = await contactsManager.getAllContacts();
  return contacts;
});

// Son yedekleme tarihi sağlayıcısı (örnek)
final lastBackupDateProvider = StateProvider<DateTime?>((ref) => null);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Seçili sekme indeksi
  int _selectedIndex = 0;

  // Sekme değiştiğinde çağrılacak metod
  void _onItemTapped(int index) {
    if (index == 2) {
      // Ayarlar sekmesi
      Navigator.pushNamed(context, '/settings');
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    // Uygulama başladığında izin kontrolü
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestPermissionIfNeeded();
    });
  }

  // İzin kontrolü ve gerekirse izin isteme
  Future<void> _checkAndRequestPermissionIfNeeded() async {
    // Mobil olmayan platformlarda (masaüstü, web) izin kontrolünü atla
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      debugPrint('İzin kontrolü: Mobil olmayan platform - izin gerekmiyor');
      return;
    }

    final currentStatus = ref.read(contactsPermissionProvider);

    // Debug için izin durumunu yazdır
    debugPrint('Başlangıçta rehber izin durumu: $currentStatus');

    // Android'de özellikle izin isteği için
    if (Platform.isAndroid) {
      // Uygulamayı rehbere erişim isteyen uygulamalar listesinde göstermek için
      // Her durumda izin isteme prosedürünü başlat
      if (currentStatus != PermissionStatus.granted) {
        final status = await Permission.contacts.request();
        ref.read(contactsPermissionProvider.notifier).state = status;
        debugPrint('Android izin isteme sonucu: $status');

        // Eğer kullanıcı reddetmişse, önemi hakkında bilgi ver
        if (status == PermissionStatus.denied ||
            status == PermissionStatus.permanentlyDenied) {
          if (mounted) {
            _showPermissionError();
          }
        }
      }
    }
    // iOS için normal akış
    else if (currentStatus == PermissionStatus.denied) {
      // İzin iste
      final status = await Permission.contacts.request();
      ref.read(contactsPermissionProvider.notifier).state = status;
      debugPrint('İzin kontrolü: Mevcut durum = $status');
    }
  }

  // İzin isteme fonksiyonu
  Future<void> _requestPermission() async {
    // Mobil olmayan platformlarda (masaüstü, web) izin kontrolünü atla
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      debugPrint('İzin isteme: Mobil olmayan platform - izin gerekmiyor');
      ref.read(contactsPermissionProvider.notifier).state =
          PermissionStatus.granted;
      return;
    }

    // Mevcut izin durumunu kontrol et
    final currentStatus = ref.read(contactsPermissionProvider);

    if (currentStatus == PermissionStatus.permanentlyDenied) {
      // Eğer izin kalıcı olarak reddedildiyse, kullanıcıyı ayarlara yönlendir
      await openAppSettings();
    } else {
      // Değilse, izin istemeyi dene
      final status = await Permission.contacts.request();
      ref.read(contactsPermissionProvider.notifier).state = status;

      // Sonucu yazdır
      debugPrint('İzin isteme sonucu: $status');
    }
  }

  void _showPermissionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Kişilere erişim izni olmadan uygulama çalışamaz. '
          'Lütfen izin verin veya Ayarlar > Uygulamalar > Rehber Yedekleme > İzinler kısmından izin ayarlayın',
        ),
        duration: const Duration(seconds: 5),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'ANLADIM',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tema modunu izle
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    // Tema renkleri
    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.lightBackgroundColor;
    final surfaceColor =
        isDarkMode ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor;
    final cardColor =
        isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.lightTextColor;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondaryColor
        : AppTheme.lightTextSecondaryColor;

    // İzin durumunu izle
    final permissionStatus = ref.watch(contactsPermissionProvider);

    // Arka plan gradyanı
    final backgroundGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        backgroundColor,
        surfaceColor,
      ],
    );

    // Rehber sayısını izle
    final contactsCount = ref.watch(contactsCountProvider);
    final isPermissionGranted = permissionStatus == PermissionStatus.granted;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          context.l10n.home_screen_title,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: permissionStatus == PermissionStatus.granted
            ? _buildStatisticsScreen(isDarkMode, textColor, cardColor)
            : _buildPermissionRequest(isDarkMode, textColor, cardColor),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(isDarkMode),
    );
  }

  Widget _buildPermissionRequest(
      bool isDarkMode, Color textColor, Color cardColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contacts_outlined,
              size: 64,
              color: textColor.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.contacts_permission_message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _requestPermission,
              icon: const Icon(Icons.security),
              label: Text(context.l10n.grant_permission),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsScreen(
      bool isDarkMode, Color textColor, Color cardColor) {
    // Rehber sayısını izle
    final contactsCountAsync = ref.watch(contactsCountProvider);

    // Son yedekleme tarihi (örnek)
    final lastBackupDate = ref.watch(lastBackupDateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rehber İstatistikleri
          _buildStatisticsCard(
            isDarkMode,
            textColor,
            cardColor,
            title: context.l10n.contacts_title,
            icon: Icons.contacts,
            child: contactsCountAsync.when(
              data: (count) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.total_contacts
                        .replaceAll('{count}', count.toString()),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Son güncelleme: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text(
                'Hata: $error',
                style: TextStyle(color: textColor),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Son Yedekleme Bilgisi
          _buildStatisticsCard(
            isDarkMode,
            textColor,
            cardColor,
            title: 'Yedekleme Durumu',
            icon: Icons.backup,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lastBackupDate != null
                      ? 'Son yedekleme: ${lastBackupDate.day}/${lastBackupDate.month}/${lastBackupDate.year}'
                      : 'Henüz yedekleme yapılmadı',
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/export'),
                  icon: const Icon(Icons.backup),
                  label: const Text('Rehberi Yedekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Hızlı İşlemler
          _buildStatisticsCard(
            isDarkMode,
            textColor,
            cardColor,
            title: context.l10n.quick_actions,
            icon: Icons.flash_on,
            child: Column(
              children: [
                _buildQuickActionItem(
                  isDarkMode,
                  textColor,
                  icon: Icons.backup,
                  title: context.l10n.backup_contacts,
                  subtitle: context.l10n.backup_contacts_desc,
                  onTap: () => Navigator.pushNamed(context, '/export'),
                ),
                const Divider(),
                _buildQuickActionItem(
                  isDarkMode,
                  textColor,
                  icon: Icons.restore,
                  title: context.l10n.restore_contacts,
                  subtitle: context.l10n.restore_contacts_desc,
                  onTap: () {
                    // İçe aktarma ekranına git
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Premium Bilgisi
          _buildStatisticsCard(
            isDarkMode,
            textColor,
            cardColor,
            title: 'Premium Durum',
            icon: Icons.workspace_premium,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Ücretsiz',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Şu anda ücretsiz sürümü kullanıyorsunuz',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/premium'),
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('Premium\'a Yükselt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // İstatistik kartı widget'ı
  Widget _buildStatisticsCard(
    bool isDarkMode,
    Color textColor,
    Color cardColor, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor),
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

  // Hızlı işlem öğesi
  Widget _buildQuickActionItem(
    bool isDarkMode,
    Color textColor, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: textColor.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(bool isDarkMode) {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: isDarkMode
          ? AppTheme.darkTextSecondaryColor
          : AppTheme.lightTextSecondaryColor,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Ana Sayfa',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Takvim',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Ayarlar',
        ),
      ],
    );
  }
}
