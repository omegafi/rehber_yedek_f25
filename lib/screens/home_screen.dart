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
import 'package:shared_preferences/shared_preferences.dart';

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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Seçili sekme indeksi
  int _selectedIndex = 0;

  // Arama metni
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

    // Arama kontrolü
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
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

    // Filtreleme ayarlarını izle
    final includeContactsWithoutNumber =
        ref.watch(includeContactsWithoutNumberProvider);
    final includeNumbersWithoutName =
        ref.watch(includeNumbersWithoutNameProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? context.l10n.home_screen_title : 'Kişilerim',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: _selectedIndex == 1
            ? [
                // Kişiler ekranında seçim işlemleri için butonlar
                IconButton(
                  icon: const Icon(Icons.select_all),
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
                    icon: const Icon(Icons.backup),
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
                : _buildContactsScreen(
                    isDarkMode, textColor, cardColor, textSecondaryColor)
            : _buildPermissionRequest(isDarkMode, textColor, cardColor),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(isDarkMode),
      floatingActionButton:
          _selectedIndex == 1 && ref.watch(selectedContactsProvider).isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () {
                    // Seçili kişileri yedekle
                    final selectedIds = ref.read(selectedContactsProvider);
                    Navigator.pushNamed(
                      context,
                      '/export',
                      arguments: {'selectedContactIds': selectedIds},
                    );
                  },
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.backup),
                  label: Text(
                      '${ref.watch(selectedContactsProvider).length} Kişiyi Yedekle'),
                )
              : null,
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

  Widget _buildHomeScreen(bool isDarkMode, Color textColor, Color cardColor) {
    // Rehber sayısını izle
    final contactsCountAsync = ref.watch(contactsCountProvider);

    // Filtrelenmiş kişi sayısını izle
    final filteredContactsCountAsync = ref.watch(filteredContactsCountProvider);

    // Filtreleme ayarlarını izle
    final includeContactsWithoutNumber =
        ref.watch(includeContactsWithoutNumberProvider);
    final includeNumbersWithoutName =
        ref.watch(includeNumbersWithoutNameProvider);

    // Son yedekleme tarihi
    final lastBackupDate = ref.watch(lastBackupDateProvider);

    // Premium durumu
    final isPremium = ref.watch(isPremiumProvider);
    final maxFreeContacts = ref.watch(maxFreeContactsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium butonu (sağ üstte)
          Align(
            alignment: Alignment.topRight,
            child: _buildPremiumButton(isDarkMode),
          ),

          // Rehber Bilgileriniz (yeniden tasarlanmış)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
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
                // Başlık
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.contacts,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.contacts_title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          if (!includeContactsWithoutNumber ||
                              !includeNumbersWithoutName)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.filter_list,
                                    size: 12,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Filtreler aktif',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Filtreleme ayarları butonu
                    InkWell(
                      onTap: () =>
                          _showFilteringOptions(context, isDarkMode, textColor),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (!includeContactsWithoutNumber ||
                                  !includeNumbersWithoutName)
                              ? Colors.amber.withOpacity(0.2)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (!includeContactsWithoutNumber ||
                                    !includeNumbersWithoutName)
                                ? Colors.amber
                                : Colors.grey.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.filter_alt,
                          size: 18,
                          color: (!includeContactsWithoutNumber ||
                                  !includeNumbersWithoutName)
                              ? Colors.amber
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Kişi sayısı bilgisi
                contactsCountAsync.when(
                  data: (totalCount) {
                    return filteredContactsCountAsync.when(
                      data: (filteredCount) {
                        final isFiltered = !includeContactsWithoutNumber ||
                            !includeNumbersWithoutName;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kişi sayısı
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: AnimatedCounter(
                                    count:
                                        isFiltered ? filteredCount : totalCount,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isFiltered
                                            ? 'Filtrelenmiş Kişi'
                                            : 'Toplam Kişi',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      if (isFiltered)
                                        Text(
                                          'Toplam $totalCount kişiden',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: textColor.withOpacity(0.7),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Aktif filtreler (minimal gösterim)
                            if (isFiltered) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (!includeContactsWithoutNumber)
                                    _buildFilterChip(
                                      label: 'Numarasız kişiler hariç',
                                      color: Colors.amber,
                                    ),
                                  if (!includeNumbersWithoutName)
                                    _buildFilterChip(
                                      label: 'İsimsiz numaralar hariç',
                                      color: Colors.amber,
                                    ),
                                ],
                              ),
                            ],

                            // Premium uyarısı (ücretsiz kullanıcılar için)
                            if (!isPremium && totalCount > maxFreeContacts) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF8A2BE2).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        Icons.info_outline,
                                        color: const Color(0xFF8A2BE2),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ücretsiz sürümde yalnızca $maxFreeContacts kişiyi yedekleyebilirsiniz',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Premium\'a geçerek sınırsız kişi yedekleyebilirsiniz',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: textColor.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Son güncelleme ve yedekleme bilgisi
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.update,
                                      size: 12,
                                      color: textColor.withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Güncelleme: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textColor.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                                if (lastBackupDate != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.backup,
                                        size: 12,
                                        color: textColor.withOpacity(0.5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Yedekleme: ${lastBackupDate.day}/${lastBackupDate.month}/${lastBackupDate.year}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: textColor.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            // Yedekleme butonu
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/export'),
                              icon: const Icon(Icons.backup),
                              label: const Text('Rehberi Yedekle ve Paylaş'),
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
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Text(
                        'Hata: $error',
                        style: TextStyle(color: textColor),
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Text(
                    'Hata: $error',
                    style: TextStyle(color: textColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsScreen(bool isDarkMode, Color textColor, Color cardColor,
      Color textSecondaryColor) {
    return Column(
      children: [
        // Arama çubuğu
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Kişi ara...',
              hintStyle: TextStyle(color: textSecondaryColor),
              prefixIcon: Icon(Icons.search, color: textSecondaryColor),
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Seçim bilgisi
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kişileri seçin',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${ref.watch(selectedContactsProvider).length} kişi seçildi',
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Kişiler listesi
        Expanded(
          child: _buildContactsList(isDarkMode, textColor, cardColor),
        ),
      ],
    );
  }

  Widget _buildContactsList(bool isDarkMode, Color textColor, Color cardColor) {
    final selectedContacts = ref.watch(selectedContactsProvider);
    final allSelected = ref.watch(allContactsSelectedProvider);

    return ref.watch(contactsListProvider).when(
          data: (contacts) {
            // Arama filtresini uygula
            final filteredContacts = contacts.where((contact) {
              final searchText = _searchQuery.toLowerCase();
              final name =
                  '${contact.name.first} ${contact.name.last}'.toLowerCase();
              return name.contains(searchText);
            }).toList();

            if (filteredContacts.isEmpty) {
              return Center(
                child: Text(
                  'Kişi bulunamadı',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredContacts.length,
              itemBuilder: (context, index) {
                final contact = filteredContacts[index];
                final isSelected = selectedContacts.contains(contact.id);

                return Card(
                  color: cardColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDarkMode
                          ? AppTheme.darkDividerColor
                          : AppTheme.lightDividerColor,
                      width: 1,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      final selectedIds = Set<String>.from(selectedContacts);
                      if (value == true) {
                        selectedIds.add(contact.id);
                      } else {
                        selectedIds.remove(contact.id);
                      }
                      ref.read(selectedContactsProvider.notifier).state =
                          selectedIds;

                      // Tüm kişiler seçili mi kontrolü
                      ref.read(allContactsSelectedProvider.notifier).state =
                          selectedIds.length == contacts.length;
                    },
                    title: Text(
                      _getDisplayName(contact),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: contact.phones.isNotEmpty
                        ? Text(
                            contact.phones.first.number,
                            style: TextStyle(
                              color: textColor.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          )
                        : null,
                    secondary: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      child: Text(
                        _getInitials(contact),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    activeColor: AppTheme.primaryColor,
                    checkColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(
              'Hata: $error',
              style: TextStyle(color: textColor),
            ),
          ),
        );
  }

  String _getInitials(Contact contact) {
    if (contact.name.first.isEmpty && contact.name.last.isEmpty) {
      return '?';
    }
    final firstInitial = contact.name.first.isNotEmpty
        ? contact.name.first[0].toUpperCase()
        : '';
    final lastInitial =
        contact.name.last.isNotEmpty ? contact.name.last[0].toUpperCase() : '';
    return '$firstInitial$lastInitial';
  }

  String _getDisplayName(Contact contact) {
    if (contact.name.first.isEmpty && contact.name.last.isEmpty) {
      return contact.phones.isNotEmpty
          ? contact.phones.first.number
          : 'İsimsiz Kişi';
    }
    return '${contact.name.first} ${contact.name.last}'.trim();
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
          icon: Icon(Icons.people),
          label: 'Kişilerim',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Ayarlar',
        ),
      ],
    );
  }

  Widget _buildPremiumButton(bool isDarkMode) {
    final isPremium = ref.watch(isPremiumProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/premium'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4CAF50), // Yeşil
                const Color(0xFF2E7D32), // Koyu yeşil
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isPremium ? 'Premium Aktif' : 'Premium\'a Yükselt',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt_outlined,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilteringOptions(
      BuildContext context, bool isDarkMode, Color textColor) {
    final includeContactsWithoutNumber =
        ref.read(includeContactsWithoutNumberProvider);
    final includeNumbersWithoutName =
        ref.read(includeNumbersWithoutNameProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Rehber Filtreleme',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Numarası olmayan kişileri dahil etme
            StatefulBuilder(
              builder: (context, setState) => SwitchListTile(
                title: Text(
                  'Numarası olmayan kişileri dahil et',
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  'Telefon numarası olmayan kişileri yedeklemeye dahil et',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                value: ref.read(includeContactsWithoutNumberProvider),
                onChanged: (value) async {
                  ref
                      .read(includeContactsWithoutNumberProvider.notifier)
                      .state = value;

                  // Değişikliği kaydet
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('include_contacts_without_number', value);

                  setState(() {});
                },
                activeColor: AppTheme.primaryColor,
              ),
            ),

            // İsmi olmayan numaraları dahil etme
            StatefulBuilder(
              builder: (context, setState) => SwitchListTile(
                title: Text(
                  'İsmi olmayan numaraları dahil et',
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  'İsim bilgisi olmayan telefon numaralarını yedeklemeye dahil et',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                value: ref.read(includeNumbersWithoutNameProvider),
                onChanged: (value) async {
                  ref.read(includeNumbersWithoutNameProvider.notifier).state =
                      value;

                  // Değişikliği kaydet
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('include_numbers_without_name', value);

                  setState(() {});
                },
                activeColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tamam',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Animasyonlu sayaç widget'ı
class AnimatedCounter extends StatefulWidget {
  final int count;
  final TextStyle style;
  final Duration duration;

  const AnimatedCounter({
    Key? key,
    required this.count,
    required this.style,
    this.duration = const Duration(seconds: 1),
  }) : super(key: key);

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  int _oldCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = IntTween(begin: 0, end: widget.count).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _oldCount = oldWidget.count;
      _animation = IntTween(begin: _oldCount, end: widget.count).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${_animation.value}',
          style: widget.style,
        );
      },
    );
  }
}
