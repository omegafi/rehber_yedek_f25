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

// Kişileri göstermeyi kontrol eden durumu sakla
final showContactsProvider = StateProvider<bool>((ref) => false);

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
    setState(() {
      _selectedIndex = index;
    });

    // Ayarlar sekmesine geçiş
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsScreen()),
      );
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
    // İzin durumunu izle
    final permissionStatus = ref.watch(contactsPermissionProvider);

    // Rehber sayısını izle
    final contactsCount = ref.watch(contactsCountProvider);
    final isPermissionGranted = permissionStatus == PermissionStatus.granted;

    return Scaffold(
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
                  'Rehber Yedekleme',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // İzin durumuna göre içerik
              Expanded(
                child: permissionStatus == PermissionStatus.granted
                    ? _buildStatisticsContent()
                    : _buildPermissionRequest(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // İstatistikler içeriği
  Widget _buildStatisticsContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İstatistik kartları
          _buildStatisticsCard(
            title: 'Toplam Kişi Sayısı',
            value: ref.watch(contactsCountProvider).when(
                  data: (count) => count.toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
            icon: Icons.people,
            color: Colors.blue,
          ),

          SizedBox(height: 16),

          _buildStatisticsCard(
            title: 'Son Yedekleme',
            value: '2 gün önce',
            icon: Icons.history,
            color: Colors.green,
          ),

          SizedBox(height: 16),

          _buildStatisticsCard(
            title: 'Yedekleme Boyutu',
            value: '1.2 MB',
            icon: Icons.storage,
            color: Colors.orange,
          ),

          SizedBox(height: 32),

          // Yedekleme butonu
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/export'),
            icon: Icon(Icons.backup),
            label: Text('Rehberi Yedekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              minimumSize: Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),

          SizedBox(height: 16),

          // Geri yükleme butonu
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/import'),
            icon: Icon(Icons.restore),
            label: Text('Yedeği Geri Yükle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white, width: 2),
              minimumSize: Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // İstatistik kartı
  Widget _buildStatisticsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // İzin isteme ekranı
  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contacts_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Rehberinize erişmek için izin gerekiyor',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Kişilerinizi yedeklemek ve geri yüklemek için rehberinize erişim izni vermeniz gerekmektedir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _requestPermission,
              icon: const Icon(Icons.security),
              label: Text('İzin Ver'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
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

  // Alt navigasyon çubuğu
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              icon: Icons.home,
              label: 'Ana Sayfa',
              index: 0,
              isSelected: _selectedIndex == 0,
            ),
            _buildNavItem(
              icon: Icons.calendar_today,
              label: 'Takvim',
              index: 1,
              isSelected: _selectedIndex == 1,
            ),
            _buildNavItem(
              icon: Icons.bar_chart,
              label: 'İstatistikler',
              index: 2,
              isSelected: _selectedIndex == 2,
            ),
            _buildNavItem(
              icon: Icons.settings,
              label: 'Ayarlar',
              index: 3,
              isSelected: _selectedIndex == 3,
            ),
          ],
        ),
      ),
    );
  }

  // Navigasyon öğesi
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.red : Colors.grey,
            size: 24,
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.red : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
