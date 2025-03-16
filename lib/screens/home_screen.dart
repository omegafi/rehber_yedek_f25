import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'; // Clipboard için
import 'dart:math'; // min fonksiyonu için
import 'dart:async'; // Timer için
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_share/flutter_share.dart';
import '../services/backup_service.dart';
import '../screens/settings_screen.dart'
    show
        includeContactsWithoutNumberProvider,
        includeNumbersWithoutNameProvider,
        refreshContactsCacheProvider; // Filtreleme ve önbellek yenileme provider'ları
import '../screens/splash_screen.dart'
    show contactsLoadingProvider; // Kişilerin yüklenme durumu provider'ı
// import 'package:flutter_native_timezone/flutter_native_timezone.dart'; // Geçici olarak devre dışı bırakıldı

// Rehber izin durumu sağlayıcısı - main.dart'tan geliyor
import '../main.dart' show contactsPermissionProvider;

// Ana renk - eski Google mavisi
const Color appPrimaryColor =
    Color(0xFF4285F4); // Google mavisi (turkuaz yerine)

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

// Seçili kişiler sağlayıcısı
final selectedContactsProvider = StateProvider<Set<String>>((ref) => {});

// Tüm kişilerin seçili olup olmadığını kontrol eden sağlayıcı
final allContactsSelectedProvider = StateProvider<bool>((ref) => false);

// Filtrelenmiş kişi sayısı sağlayıcısı
final filteredContactsCountProvider = FutureProvider<int>((ref) async {
  // İzin durumunu kontrol et
  final permissionStatus = ref.watch(contactsPermissionProvider);

  if (permissionStatus != PermissionStatus.granted) {
    return 0; // İzin yoksa 0 döndür
  }

  // Önbellek güncelleme tetikleyicisini dinle (bu değer değişince önbellek yenilenecek)
  ref.watch(refreshContactsCacheProvider);

  // Filtreleme ayarlarını al
  final includeContactsWithoutNumber =
      ref.watch(includeContactsWithoutNumberProvider);
  final includeNumbersWithoutName =
      ref.watch(includeNumbersWithoutNameProvider);

  final contactsManager = ContactsManager();
  final contacts = await contactsManager.getAllContacts();

  // Filtreleme uygula
  final filteredContacts = contacts.where((contact) {
    // Numarası olmayan kişileri filtrele
    if (!includeContactsWithoutNumber && contact.phones.isEmpty) {
      return false;
    }

    // İsmi olmayan numaraları filtrele
    if (!includeNumbersWithoutName &&
        contact.name.first.isEmpty &&
        contact.name.last.isEmpty) {
      return false;
    }

    return true;
  }).toList();

  return filteredContacts.length;
});

// Tekrar eden kişileri tespit eden sağlayıcı
final duplicateContactsProvider =
    FutureProvider<List<List<Contact>>>((ref) async {
  final permissionStatus = ref.watch(contactsPermissionProvider);

  if (permissionStatus != PermissionStatus.granted) {
    return []; // İzin yoksa boş liste döndür
  }

  final contactsManager = ContactsManager();
  final contacts = await contactsManager.getAllContacts();

  // Aynı isme sahip kişileri grupla
  final Map<String, List<Contact>> nameGroups = {};

  for (final contact in contacts) {
    final name =
        '${contact.name.first} ${contact.name.last}'.trim().toLowerCase();
    if (name.isNotEmpty) {
      nameGroups.putIfAbsent(name, () => []).add(contact);
    }
  }

  // Sadece birden fazla kişi içeren grupları al
  return nameGroups.values.where((group) => group.length > 1).toList();
});

// Tekrar eden numaraları tespit eden sağlayıcı
final duplicateNumbersProvider =
    FutureProvider<List<List<Contact>>>((ref) async {
  final permissionStatus = ref.watch(contactsPermissionProvider);

  if (permissionStatus != PermissionStatus.granted) {
    return []; // İzin yoksa boş liste döndür
  }

  final contactsManager = ContactsManager();
  final contacts = await contactsManager.getAllContacts();

  // Aynı telefon numarasına sahip kişileri grupla
  final Map<String, List<Contact>> numberGroups = {};

  for (final contact in contacts) {
    for (final phone in contact.phones) {
      // Numarayı normalize et (sadece rakamlar kalsın)
      final normalizedNumber = phone.number.replaceAll(RegExp(r'\D'), '');
      if (normalizedNumber.isNotEmpty) {
        numberGroups.putIfAbsent(normalizedNumber, () => []).add(contact);
      }
    }
  }

  // Sadece birden fazla kişi içeren grupları al
  return numberGroups.values.where((group) => group.length > 1).toList();
});

// Tekrar eden kişilerin birleştirilmesi için seçili kişiler
final selectedDuplicatesProvider = StateProvider<Set<String>>((ref) => {});

// Tekrarlayan telefon numaralı kişiler sağlayıcısı
final duplicateNumbersPhoneProvider =
    FutureProvider<List<Contact>>((ref) async {
  final contactsList = await ref.watch(contactsListProvider.future);

  // Telefon numaralarına göre kişileri grupla
  final phoneMap = <String, List<Contact>>{};

  for (final contact in contactsList) {
    for (final phone in contact.phones) {
      final normalizedNumber = _normalizePhoneNumber(phone.number);
      if (!phoneMap.containsKey(normalizedNumber)) {
        phoneMap[normalizedNumber] = [];
      }
      phoneMap[normalizedNumber]!.add(contact);
    }
  }

  // Birden fazla kişiye ait olan numaraları bul
  final duplicateContacts = <Contact>{};
  phoneMap.forEach((number, contacts) {
    if (contacts.length > 1) {
      duplicateContacts.addAll(contacts);
    }
  });

  return duplicateContacts.toList();
});

// Tekrarlayan isimlere sahip kişiler sağlayıcısı
final duplicateNamesProvider = FutureProvider<List<Contact>>((ref) async {
  final contactsList = await ref.watch(contactsListProvider.future);

  // İsimlere göre kişileri grupla
  final namesMap = <String, List<Contact>>{};

  for (final contact in contactsList) {
    if (contact.displayName.isNotEmpty) {
      final normalizedName = contact.displayName.toLowerCase().trim();
      if (!namesMap.containsKey(normalizedName)) {
        namesMap[normalizedName] = [];
      }
      namesMap[normalizedName]!.add(contact);
    }
  }

  // Birden fazla kişiye ait olan isimleri bul
  final duplicateContacts = <Contact>{};
  namesMap.forEach((name, contacts) {
    if (contacts.length > 1) {
      duplicateContacts.addAll(contacts);
    }
  });

  return duplicateContacts.toList();
});

// Tekrarlayan e-postalara sahip kişiler sağlayıcısı
final duplicateEmailsProvider = FutureProvider<List<Contact>>((ref) async {
  final contactsList = await ref.watch(contactsListProvider.future);

  // E-posta adreslerine göre kişileri grupla
  final emailMap = <String, List<Contact>>{};

  for (final contact in contactsList) {
    for (final email in contact.emails) {
      final normalizedEmail = email.address.toLowerCase().trim();
      if (!emailMap.containsKey(normalizedEmail)) {
        emailMap[normalizedEmail] = [];
      }
      emailMap[normalizedEmail]!.add(contact);
    }
  }

  // Birden fazla kişiye ait olan e-postaları bul
  final duplicateContacts = <Contact>{};
  emailMap.forEach((email, contacts) {
    if (contacts.length > 1) {
      duplicateContacts.addAll(contacts);
    }
  });

  return duplicateContacts.toList();
});

// Eksik bilgiye sahip kişiler sağlayıcısı
final missingInfoContactsProvider = FutureProvider<List<Contact>>((ref) async {
  final contactsList = await ref.watch(contactsListProvider.future);

  // Eksik bilgiye sahip kişileri filtrele
  final missingInfoContacts = contactsList
      .where((contact) =>
              contact.displayName.isEmpty || // İsim yok
              (contact.phones.isEmpty &&
                  contact.emails.isEmpty) // Ne telefon ne email var
          )
      .toList();

  return missingInfoContacts;
});

// Yay çizen CustomPainter sınıfı
class ArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double
      sweepAngle; // Çemberin ne kadarının çizileceği (derece cinsinden)
  final double startAngle; // Başlangıç açısı (derece cinsinden)

  ArcPainter({
    required this.color,
    required this.strokeWidth,
    required this.sweepAngle,
    required this.startAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: size.height,
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Açıları radyana çevir
    final startRadians = startAngle * (3.14159 / 180);
    final sweepRadians = sweepAngle * (3.14159 / 180);

    canvas.drawArc(
      rect,
      startRadians,
      sweepRadians,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(ArcPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.sweepAngle != sweepAngle ||
      oldDelegate.startAngle != startAngle;
}

// Yükleme animasyonu için dönen yay çizen CustomPainter
class LoadingArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double startAngle; // Başlangıç açısı
  final AnimationController?
      repaintController; // Yeniden çizimi tetiklemek için

  LoadingArcPainter({
    required this.color,
    required this.strokeWidth,
    required this.startAngle,
    this.repaintController,
  }) : super(repaint: repaintController);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: size.height,
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Şu anki zaman bilgisini al, animasyon için
    final now = DateTime.now().millisecondsSinceEpoch / 300;
    final startRadians = (startAngle + now % 360) * (3.14159 / 180);

    // 90 derecelik bir yay çiz, dönen animasyon için
    canvas.drawArc(
      rect,
      startRadians,
      120 * (3.14159 / 180), // 90 yerine 120 derecelik yay (daha uzun)
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      true; // Her kare yeniden çiz
}

// Telefon numarasını normalleştirme yardımcı fonksiyonu
String _normalizePhoneNumber(String phoneNumber) {
  // Sadece rakamları tut
  final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  // + işaretini koru ama başta değilse kaldır
  final normalizedNumber =
      digitsOnly.startsWith('+') ? digitsOnly : digitsOnly.replaceAll('+', '');
  return normalizedNumber;
}

// Rehber sayma animasyonu için durum sağlayıcıları
final countingStartedProvider = StateProvider<bool>((ref) => false);
final animationCompletedProvider = StateProvider<bool>((ref) => false);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Seçili sekme indeksi
  int _selectedIndex = 0;

  // Arama metni
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // LoadingArcPainter için animasyon kontrolcüsü
  late AnimationController _arcAnimationController;

  // Değişken tanımlamaları - sınıf seviyesinde
  int _totalContacts = 0;
  int _processedContacts = 0;
  int _duplicatePhoneCount = 0;
  int _duplicateNameCount = 0;
  int _duplicateEmailCount = 0;
  int _missingInfoCount = 0;
  bool _isProcessing = false;
  late AnimationController _loadingAnimationController;

  // Global bir değişken olarak isDarkMode tanımı
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  // Sekme değiştiğinde çağrılacak metod
  void _onItemTapped(int index) {
    if (index == _selectedIndex) {
      // Zaten seçiliyse bir şey yapma
      return;
    }

    if (index == 3) {
      // Ayarlar sekmesi
      Navigator.pushNamed(context, '/settings');
      return;
    }

      setState(() {
        _selectedIndex = index;
      });
  }

  @override
  void initState() {
    super.initState();

    // Yay animasyonu için kontrolcü
    _arcAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat(); // Sürekli dönme animasyonu

    // Uygulama başladığında izin kontrolü
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestPermissionIfNeeded();
      _loadFilterSettings(); // Filtreleme ayarlarını yükle
    });

    // Arama kontrolü
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _arcAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
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

    // Tema renkleri - AppTheme'den al, doğrudan tema değerlerini kullan
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

    // Kişi yükleme durumu (Splash ekrandan)
    final contactsLoading = ref.watch(contactsLoadingProvider);

    // Arka plan gradyanı
    final backgroundGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        backgroundColor,
        surfaceColor,
      ],
    );

    // Filtreleme ayarlarını izle
    final includeContactsWithoutNumber =
        ref.watch(includeContactsWithoutNumberProvider);
    final includeNumbersWithoutName =
        ref.watch(includeNumbersWithoutNameProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? context.l10n.home_screen_title
              : _selectedIndex == 1
                  ? 'Kişilerim'
                  : _selectedIndex == 2
                      ? 'Yedekler'
                      : 'Ayarlar',
          style: TextStyle(color: textColor), // Metin rengi tema ile uyumlu
        ),
        backgroundColor:
            backgroundColor, // AppBar arka plan rengi tema ile uyumlu
        elevation: 0,
        iconTheme:
            IconThemeData(color: textColor), // İkon rengi tema ile uyumlu
        actions: _selectedIndex == 1
            ? [
                // Kişiler ekranında seçim işlemleri için butonlar
                IconButton(
                  icon: Icon(Icons.select_all, color: textColor),
                  onPressed: () {
                    final allSelected = ref.read(allContactsSelectedProvider);
                    ref.read(allContactsSelectedProvider.notifier).state =
                        !allSelected;

                    if (!allSelected) {
                      // Tüm kişileri seç
                      final contacts =
                          ref.read(contactsListProvider).value ?? [];
                      final selectedIds = contacts.map((c) => c.id).toSet();
                      ref.read(selectedContactsProvider.notifier).state =
                          selectedIds;
                    } else {
                      // Tüm seçimleri kaldır
                      ref.read(selectedContactsProvider.notifier).state = {};
                    }
                  },
                ),
                if (ref.watch(selectedContactsProvider).isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.backup, color: textColor),
                    onPressed: () {
                      // Seçili kişileri yedekle
                      final selectedIds = ref.read(selectedContactsProvider);
                      Navigator.pushNamed(
                        context,
                        '/export',
                        arguments: {'selectedContactIds': selectedIds},
                      );
                    },
                  ),
              ]
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: permissionStatus == PermissionStatus.granted
            ? _selectedIndex == 0
                ? _buildHomeScreen(isDarkMode, textColor, cardColor)
                : _selectedIndex == 1
                    ? _buildContactsScreen(
                    isDarkMode, textColor, cardColor, textSecondaryColor)
                    : _selectedIndex == 2
                        ? _buildBackupsScreen(isDarkMode, textColor, cardColor)
                        : Center(
                            child: Text('Ayarlar',
                                style:
                                    TextStyle(color: textColor, fontSize: 24)))
            : _buildPermissionRequest(isDarkMode, textColor, cardColor),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(isDarkMode, textColor),
    );
  }

  // Yükleniyor göstergesi
  Widget _buildContactsLoadingIndicator(bool isDarkMode, Color textColor) {
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.primaryColor,
            ),
          ),
          SizedBox(height: 20),
            Text(
            "Kişileriniz Yükleniyor...",
              style: TextStyle(
                fontSize: 16,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // Alt navigasyon çubuğu - tema uyumluluğu için güncellendi
  Widget _buildBottomNavigationBar(bool isDarkMode, Color textColor) {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor:
          isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: textColor.withOpacity(0.6),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Ana Sayfa',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.contacts_outlined),
          activeIcon: Icon(Icons.contacts),
          label: 'Kişilerim',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.backup_outlined),
          activeIcon: Icon(Icons.backup),
          label: 'Yedekler',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Ayarlar',
        ),
      ],
    );
  }

  // Ana sayfa ekranını oluşturan fonksiyon
  Widget _buildHomeScreen(bool isDarkMode, Color textColor, Color cardColor) {
    // Kişi sayısı asenkron sağlayıcısı
    final contactsCountAsync = ref.watch(contactsCountProvider);

    // Filtrelenmiş kişi sayısı sağlayıcısı - Filtreleme ayarlarını dikkate alır
    final filteredCountAsync = ref.watch(filteredContactsCountProvider);

    // Kişilerin yüklendiğini ve sayma animasyonunu kontrol eden state
    final countingStarted = ref.watch(countingStartedProvider);
    final animationCompleted = ref.watch(animationCompletedProvider);

    // Duplicate contacts sağlayıcıları
    final duplicateNumbersAsync = ref.watch(duplicateNumbersProvider);
    final duplicateEmailsAsync = ref.watch(duplicateEmailsProvider);
    final duplicateNamesAsync = ref.watch(duplicateNamesProvider);

    // Eksik bilgileri olan kişiler sağlayıcısı
    final missingInfoContactsAsync = ref.watch(missingInfoContactsProvider);

    // Sayaçlar için değişkenler
    _totalContacts =
        filteredCountAsync.value ?? 0; // Filtrelenmiş kişi sayısını kullan
    _processedContacts = _totalContacts;
    _duplicatePhoneCount = duplicateNumbersAsync.value?.length ?? 0;
    _duplicateNameCount = duplicateNamesAsync.value?.length ?? 0;
    _duplicateEmailCount = duplicateEmailsAsync.value?.length ?? 0;
    _missingInfoCount = missingInfoContactsAsync.value?.length ?? 0;

    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: _buildProgressCircle(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildStatCardsHorizontalLayout(),
                ],
              ),
            ),
                              ),
                            ],
                          ),
    );
  }

  // İlerleme çemberini oluşturan fonksiyon
  Widget _buildProgressCircle() {
    // Tema modunu kontrol et
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // İlerleme animasyonu için değişkenler
    final animationStarted = ref.watch(countingStartedProvider);
    final animationCompleted = ref.watch(animationCompletedProvider);

    // İlerleme yüzdesi (0-100 arası)
    double progressPercent = 0;

    // Animasyon başladıysa ve tamamlanmadıysa ilerleme hesapla
    if (animationStarted && !animationCompleted) {
      // Başlangıç zamanı ve şu anki zamanı kullanarak yüzde hesapla
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = (now - _animationStartTime) / _animationDuration;
      progressPercent = (elapsed * 100).clamp(0, 100) / 100;

      // Animasyon tamamlandı mı kontrol et
      if (progressPercent >= 1.0) {
        // Build içinde provider değiştirme hatasını önlemek için Future kullanıyoruz
        Future.microtask(() {
          ref.read(animationCompletedProvider.notifier).state = true;
        });
        progressPercent = 1.0;
      }
    } else if (animationCompleted) {
      progressPercent = 1.0; // Tamamlandıysa %100
    }

    // Çember açısını hesapla (0-360 derece)
    final sweepAngle = progressPercent * 360;

    return Container(
      height: 180,
      width: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arka plan çemberi - tam daire (360 derece)
          CustomPaint(
            size: const Size(180, 180),
            painter: ArcPainter(
              color: Colors.grey.shade300,
              strokeWidth: 12,
              sweepAngle: 360,
                                        startAngle: 0,
            ),
          ),
          // İlerleme çemberi - ilerleme yüzdesine göre
          CustomPaint(
            size: const Size(180, 180),
            painter: ArcPainter(
              color: appPrimaryColor,
              strokeWidth: 12,
              sweepAngle: sweepAngle,
              startAngle: 0,
            ),
          ),
          // Eğer işlem devam ediyorsa, yükleme animasyonu göster
          if (_isProcessing)
            CustomPaint(
              size: const Size(180, 180),
              painter: LoadingArcPainter(
                color: appPrimaryColor.withOpacity(0.5),
                strokeWidth: 4,
                startAngle: 0,
                repaintController: _arcAnimationController,
              ),
            ),

          // İçeriği ortala
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
                                children: [
              if (_isProcessing)
                Text(
                  'Taranıyor...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                animationStarted && !animationCompleted
                    ? '%${(progressPercent * 100).toInt()}'
                    : '$_totalContacts',
                                          style: TextStyle(
                  fontSize: 24,
                                            fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
                                      Text(
                "kişi",
                                        style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 40,
                height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                  color: appPrimaryColor,
                                      boxShadow: [
                                        BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                child: _showSuccessIcon
                    ? Icon(
                        Icons.check,
                                            color: Colors.white,
                        size: 20,
                      )
                    : IconButton(
                        icon: Icon(
                          _isProcessing ? Icons.sync : Icons.backup,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _isProcessing ? null : _startCountAnimation,
                        tooltip: 'Yedekle',
                                          ),
                                        ),
                                      ],
                              ),
                      ],
                    ),
    );
  }

  // Animasyonu başlatma fonksiyonu
  int _animationStartTime = 0;
  final _animationDuration = 3000; // 3 saniye
  bool _animationInProgress = false; // Çift çalışmayı önlemek için flag
  bool _showSuccessIcon = false; // Başarı ikonu gösterme durumu

  void _startCountAnimation() {
    // Halihazırda animasyon çalışıyorsa işlemi iptal et
    if (_animationInProgress) return;

    // Animasyon durumunu işaretle
    _animationInProgress = true;
    _showSuccessIcon = false; // Başarı ikonunu gizle

    // Animasyon durumunu sıfırla
    ref.read(countingStartedProvider.notifier).state = true;
    ref.read(animationCompletedProvider.notifier).state = false;

    // Animasyon başlangıç zamanını kaydet
    _animationStartTime = DateTime.now().millisecondsSinceEpoch;

    // Animasyon ilerlemesini takip etmek için timer başlat
    Future.delayed(Duration(milliseconds: 50), () {
      if (mounted) setState(() {});
    });

    // Her 50ms'de bir ekranı güncelle
    Timer.periodic(Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {});

        // Animasyon tamamlandıysa timer'ı durdur
        if (ref.read(animationCompletedProvider)) {
          timer.cancel();

          // Animasyon tamamlandığında başarı ikonunu göster
          setState(() {
            _showSuccessIcon = true;
          });

          // 1 saniye bekledikten sonra yedekleme işlemini başlat
          Future.delayed(Duration(seconds: 1), () {
            if (mounted) {
              _startBackup();
            }
          });
        }
      } else {
        timer.cancel();
      }
    });

    // Animasyon süresi kadar bekle ve animasyonu tamamla
    Future.delayed(Duration(milliseconds: _animationDuration), () {
      if (mounted) {
        ref.read(animationCompletedProvider.notifier).state = true;
      }
    });
  }

  // Yedekleme işlemini başlatan fonksiyon
  void _startBackup() {
    try {
      setState(() {
        _isProcessing = true;
        _showSuccessIcon = false; // Yedekleme başlarken başarı ikonunu kaldır
      });

      // Yedekleme ekranına git
      Navigator.pushNamed(context, '/export').then((_) {
        // Geri döndükten sonra işlemi tamamla
        setState(() {
          _isProcessing = false;
          _animationInProgress = false; // Animasyon durumunu sıfırla
        });

        // Animasyon durumunu sıfırla
        ref.read(countingStartedProvider.notifier).state = false;
        ref.read(animationCompletedProvider.notifier).state = false;
      });
    } catch (e) {
      // Hata durumunda
      setState(() {
        _isProcessing = false;
        _animationInProgress = false; // Animasyon durumunu sıfırla
      });

      // Animasyon durumunu sıfırla
      ref.read(countingStartedProvider.notifier).state = false;
      ref.read(animationCompletedProvider.notifier).state = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yedekleme başlatılırken hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Kutuları oluşturan fonksiyon
  Widget _buildStatCardsHorizontalLayout() {
    return Column(
                children: [
        // Tekrar eden numaralar kutusu
        _buildImprovedStatCard(
          icon: Icons.call_merge,
          title: 'Tekrar Eden Numaralar',
          value: _duplicatePhoneCount,
          onTap: () {
            // Telefon rehberi yerine diyalogu göster
            _showDuplicateNumbersDialog();
          },
        ),
        const SizedBox(height: 12),

        // Tekrar eden isimler kutusu
        _buildImprovedStatCard(
          icon: Icons.person_add_disabled,
          title: 'Tekrar Eden İsimler',
          value: _duplicateNameCount,
          onTap: () {
            // Telefon rehberi yerine diyalogu göster
            _showDuplicateNamesDialog();
          },
        ),
        const SizedBox(height: 12),

        // Tekrar eden e-postalar kutusu
        _buildImprovedStatCard(
          icon: Icons.email,
          title: 'Tekrar Eden E-postalar',
          value: _duplicateEmailCount,
          onTap: () {
            // Telefon rehberi yerine diyalogu göster
            _showDuplicateEmailsDialog();
          },
        ),
        const SizedBox(height: 12),

        // Eksik bilgili kişiler kutusu
        _buildImprovedStatCard(
          icon: Icons.error_outline,
          title: 'Eksik Bilgili Kişiler',
          value: _missingInfoCount,
          onTap: () {
            // Telefon rehberi yerine diyalogu göster
            _showMissingInfoDialog();
          },
        ),
      ],
    );
  }

  // Basitleştirilmiş diyalog gösterme fonksiyonları
  void _showDuplicateNumbersDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Tekrar eden numaralar sayfası henüz aktif değil')),
    );
  }

  void _showDuplicateNamesDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tekrar eden isimler sayfası henüz aktif değil')),
    );
  }

  void _showDuplicateEmailsDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Tekrar eden e-postalar sayfası henüz aktif değil')),
    );
  }

  void _showMissingInfoDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Eksik bilgili kişiler sayfası henüz aktif değil')),
    );
  }

  // Telefonun rehber uygulamasını açan yardımcı fonksiyon
  Future<void> _openContactsApp() async {
    try {
      if (Platform.isAndroid) {
        // Android'de rehber uygulamasını aç
        await launch('content://com.android.contacts/contacts');
      } else if (Platform.isIOS) {
        // iOS için rehber uygulamasını aç
        await launch('tel://');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bu platformda rehber uygulaması açılamıyor')),
        );
      }
    } catch (e) {
      // Hata durumunda bizim diyaloglarımızı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rehber uygulaması açılamadı: ${e.toString()}')),
      );
    }
  }

  // İyileştirilmiş kart tasarımı
  Widget _buildImprovedStatCard({
    required IconData icon,
    required String title,
    required int value,
    required VoidCallback onTap,
  }) {
    // Tema modunu kontrol et
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Renkleri belirle - Google mavisi
    final cardColor = Colors.white; // Her zaman beyaz arka plan
    final textColor = isDarkMode ? Colors.white70 : Colors.black87;
    final iconColor = appPrimaryColor; // Google mavisi

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: appPrimaryColor.withOpacity(0.5),
          width: 2.0,
      ),
      ),
      color: cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: appPrimaryColor.withOpacity(0.1),
        highlightColor: appPrimaryColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
                  children: [
                    // İkon kısmı
                    Container(
                padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                  color: appPrimaryColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                  color: iconColor,
                  size: 20,
                      ),
                    ),
              SizedBox(width: 14),

              // Başlık
                    Expanded(
                child: Text(
                            title,
                            style: TextStyle(
                    fontSize: 16,
                              fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),

              // Sağ tarafta değer ve ok
              Row(
                      children: [
                  // Değer
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: appPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                          child: Text(
                      value == -1
                          ? '...'
                          : value == -2
                              ? '!'
                              : value.toString(),
                            style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: appPrimaryColor,
                            ),
                          ),
                        ),
                  SizedBox(width: 8),
                  // Ok
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
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

  // Kişiler ekranını oluştur
  Widget _buildContactsScreen(bool isDarkMode, Color textColor, Color cardColor,
      Color textSecondaryColor) {
    return Column(
      children: [
        // Arama alanı
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Kişi ara...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.white30 : Colors.black26,
                ),
              ),
              filled: true,
              fillColor: isDarkMode ? Colors.white10 : Colors.grey.shade50,
            ),
            style: TextStyle(
              color: textColor,
            ),
          ),
        ),

        // Kişi listesi
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              // Kişiler listesini al
              final contactsAsync = ref.watch(contactsListProvider);

              // Yükleme durumu
              if (contactsAsync.isLoading) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                );
              }

              // Hata durumu
              if (contactsAsync.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
            children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      SizedBox(height: 16),
              Text(
                        'Kişiler yüklenirken hata oluştu',
                style: TextStyle(
                  color: textColor,
                          fontSize: 16,
                ),
              ),
                      SizedBox(height: 8),
              Text(
                        contactsAsync.error.toString(),
                style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 14,
                ),
              ),
            ],
          ),
                );
              }

        // Kişiler listesi
              final contacts = contactsAsync.value ?? [];

              // Kişi yoksa
              if (contacts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
            children: [
                      Icon(
                        Icons.person_off,
                        size: 64,
                        color: textColor.withOpacity(0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Rehberde kişi bulunamadı',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
    );
  }

              // Seçili kişileri izle
    final selectedContacts = ref.watch(selectedContactsProvider);
    final allSelected = ref.watch(allContactsSelectedProvider);

              // Arama filtresi uygula
              final filteredContacts = _searchQuery.isEmpty
                  ? contacts
                  : contacts.where((contact) {
                      final name = '${contact.displayName}'.toLowerCase();
                      return name.contains(_searchQuery);
            }).toList();

              // Boş arama sonucu
              if (filteredContacts.isEmpty && _searchQuery.isNotEmpty) {
              return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: textColor.withOpacity(0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Arama sonucu bulunamadı',
                  style: TextStyle(
                    color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '"$_searchQuery" araması için sonuç yok',
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                ),
              );
            }

            return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: filteredContacts.length,
              itemBuilder: (context, index) {
                final contact = filteredContacts[index];
                final isSelected = selectedContacts.contains(contact.id);

                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? BorderSide(color: AppTheme.primaryColor, width: 2)
                          : BorderSide.none,
                    ),
                    elevation: 1,
                    color: cardColor,
                  child: InkWell(
                    onTap: () {
                        // Kişi seçme işlemi
                        if (selectedContacts.contains(contact.id)) {
                          ref.read(selectedContactsProvider.notifier).state =
                              Set.from(selectedContacts)..remove(contact.id);
                      } else {
                      ref.read(selectedContactsProvider.notifier).state =
                              Set.from(selectedContacts)..add(contact.id);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                    child: Padding(
                        padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Avatar
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade300,
                              child: isSelected
                                  ? Icon(Icons.check, color: Colors.white)
                                  : Text(
                                      _getInitials(contact.displayName),
                                style: TextStyle(
                                        color: Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),

                          // Kişi bilgileri
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    contact.displayName,
                                  style: TextStyle(
                                      color: textColor,
                                    fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                  ),
                                ),
                                  SizedBox(height: 4),
                                  if (contact.phones.isNotEmpty)
                                  Text(
                                    contact.phones.first.number,
                                    style: TextStyle(
                                        color: textColor.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                            // Checkbox
                            Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                if (value == true) {
                                  ref
                                      .read(selectedContactsProvider.notifier)
                                      .state = Set.from(selectedContacts)
                                    ..add(contact.id);
                                } else {
                                  ref
                                      .read(selectedContactsProvider.notifier)
                                      .state = Set.from(selectedContacts)
                                    ..remove(contact.id);
                                }
                              },
                              activeColor: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          ),
        ),
      ],
    );
  }

  // Kişinin baş harflerini almak için yardımcı fonksiyon
  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final nameParts = name.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else {
      return name[0].toUpperCase();
    }
  }

  // ContactsManager önbelleğini temizleme fonksiyonu
  void _clearContactsCache() {
    final contactsManager = ContactsManager();
    contactsManager.clearCache();

    // Önbellek yenileme sayacını artır
    ref.read(refreshContactsCacheProvider.notifier).state++;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Kişi önbelleği temizlendi, veriler yeniden yükleniyor...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Yedekler ekranını oluştur
  Widget _buildBackupsScreen(
      bool isDarkMode, Color textColor, Color cardColor) {
    // BackupService'e erişim için
    final backupService = BackupService();

    return FutureBuilder<List<File>>(
      future: backupService.getBackupFiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
              Text(
                  'Yedek dosyaları yüklenirken hata oluştu',
                style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
          Text(
                  snapshot.error.toString(),
            style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

        final backupFiles = snapshot.data ?? [];

        if (backupFiles.isEmpty) {
          return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Icon(
                  Icons.backup_outlined,
                  size: 64,
                  color: textColor.withOpacity(0.5),
                ),
                SizedBox(height: 16),
                Text(
                  'Henüz yedekleme yapılmamış',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ana sayfada yedekleme yaparak başlayabilirsiniz',
                    style: TextStyle(
                    color: textColor.withOpacity(0.7),
                      fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 0; // Ana sayfaya git
                    });
                  },
                  icon: Icon(Icons.backup),
                  label: Text('Yedekleme Yap'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
      ),
    );
  }

        return Column(
            children: [
            // Yedekleri geri yükleme butonu
                Padding(
                  padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => _showImportDialog(context),
                icon: Icon(Icons.restore),
                label: Text('Yedek Dosyasından Geri Yükle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            // Yedek dosyaları listesi
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: backupFiles.length,
                itemBuilder: (context, index) {
                  final file = backupFiles[index];
                  final fileName = file.path.split('/').last;

                  // Dosya bilgilerini al
                  final fileStats = file.statSync();
                  final fileDate = DateTime.fromMillisecondsSinceEpoch(
                      fileStats.modified.millisecondsSinceEpoch);
                  final formattedDate =
                      DateFormat('dd.MM.yyyy HH:mm').format(fileDate);

                  // Dosya uzantısını belirle
                  final String fileExt = fileName.split('.').last.toLowerCase();

                  // Dosya simgesini belirle
                  IconData fileIcon;
                  String fileType;

                  switch (fileExt) {
                    case 'vcf':
                      fileIcon = Icons.contact_phone;
                      fileType = 'vCard';
                      break;
                    case 'csv':
                      fileIcon = Icons.table_chart;
                      fileType = 'CSV';
                      break;
                    case 'xlsx':
                      fileIcon = Icons.table_view;
                      fileType = 'Excel';
                      break;
                    case 'pdf':
                      fileIcon = Icons.picture_as_pdf;
                      fileType = 'PDF';
                      break;
                    case 'json':
                      fileIcon = Icons.code;
                      fileType = 'JSON';
                      break;
                    default:
                      fileIcon = Icons.insert_drive_file;
                      fileType = fileExt.toUpperCase();
                  }

    return Card(
                    margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    color: cardColor,
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                          color: appPrimaryColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          fileIcon,
                          color: appPrimaryColor,
                        ),
                      ),
                      title: Text(
                        fileName,
                style: TextStyle(
                          color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
                      subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                          SizedBox(height: 4),
                  Text(
                            'Tarih: $formattedDate',
                    style: TextStyle(
                              color: textColor.withOpacity(0.7),
                              fontSize: 12,
                    ),
                  ),
                    Text(
                            'Format: $fileType',
                      style: TextStyle(
                              color: textColor.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
                      trailing: IconButton(
                        icon: Icon(Icons.restore_from_trash),
                        color: AppTheme.primaryColor,
                        onPressed: () =>
                            _showRestoreConfirmDialog(context, file),
                        tooltip: 'Geri Yükle',
        ),
      ),
    );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Yedek dosyasından import yapma dialog'u
  Future<void> _showImportDialog(BuildContext context) async {
    Navigator.pushNamed(context, '/import');
  }

  // Yedek dosyasından geri yükleme onay dialog'u
  Future<void> _showRestoreConfirmDialog(
      BuildContext context, File file) async {
    // Tema modunu kontrol et
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final fileName = file.path.split('/').last;
    final fileExt = fileName.split('.').last.toLowerCase();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Yedeği Geri Yükle'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$fileName dosyasından kişileri geri yüklemek istiyor musunuz?'),
              SizedBox(height: 8),
              Text(
              'Bu işlem mevcut kişilerinizi değiştirmez, yedekteki kişileri rehberinize ekler.',
                style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 12,
            ),
          ),
        ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _restoreFromBackup(file);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text('Geri Yükle'),
          ),
        ],
      ),
    );
  }

  // Yedekten geri yükleme fonksiyonu
  Future<void> _restoreFromBackup(File file) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kişiler geri yükleniyor...')),
      );

      final contactsManager = ContactsManager();
      final fileExt = file.path.split('.').last.toLowerCase();

      if (fileExt == 'vcf') {
        final importedCount =
            await contactsManager.importContactsFromVCard(file.path);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$importedCount kişi başarıyla geri yüklendi')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('$fileExt formatında geri yükleme henüz desteklenmiyor'),
            backgroundColor: Colors.orange,
      ),
    );
  }
    } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Geri yükleme sırasında hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Filtreleme ayarlarını yükleme fonksiyonu
  Future<void> _loadFilterSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final includeContactsWithoutNumber =
        prefs.getBool('include_contacts_without_number');
    final includeNumbersWithoutName =
        prefs.getBool('include_numbers_without_name');

    if (includeContactsWithoutNumber != null) {
      ref.read(includeContactsWithoutNumberProvider.notifier).state =
          includeContactsWithoutNumber;
    }

    if (includeNumbersWithoutName != null) {
      ref.read(includeNumbersWithoutNameProvider.notifier).state =
          includeNumbersWithoutName;
    }
  }
}
