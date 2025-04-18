import 'dart:io';
import 'dart:math'; // min fonksiyonu için import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart'; // PermissionStatus için import
import '../models/contact_format.dart';
import '../services/contacts_service.dart';
import '../services/file_sharing_service.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../main.dart'; // Provider'lar için
import '../screens/home_screen.dart'; // contactsCountProvider için
import '../utils/app_localizations.dart'; // Lokalizasyon için
import 'package:intl/intl.dart';

// Premium durumu ve maksimum ücretsiz kişi sayısı için import
import '../main.dart'
    show isPremiumProvider, maxFreeContactsProvider, themeProvider;

// Rehber filtreleme ayarları için import
import '../screens/settings_screen.dart'
    show
        includeContactsWithoutNumberProvider,
        includeNumbersWithoutNameProvider;

// İşlem durumu mesajı için provider
final exportStatusMessageProvider = StateProvider<String>((ref) => '');

// Seçili format sağlayıcısı
final selectedFormatProvider =
    StateProvider<ContactFormat>((ref) => ContactFormat.vCard);

// Dosya adı provider'ı
final fileNameProvider = StateProvider<String>((ref) => 'contacts_backup');

// İşlem durumu sağlayıcısı
final exportStateProvider =
    StateProvider<ExportState>((ref) => ExportState.initial);

// Dışa aktarılmış dosya sağlayıcısı
final exportedFileProvider = StateProvider<String?>((ref) => null);

// Dışa aktarma işlem durumları
enum ExportState { initial, loading, success, error }

// Dışa aktarma hedefi
enum ExportDestination { share, saveToPhone }

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  final _contactsManager = ContactsManager();
  final _fileSharingService = FileSharingService();
  String? _errorMessage;
  bool _isExporting = false;
  final TextEditingController _fileNameController =
      TextEditingController(text: "contacts_backup");

  // Dışa aktarma hedefi
  ExportDestination _exportDestination = ExportDestination.share;

  // Seçili kişi ID'leri
  Set<String>? _selectedContactIds;

  @override
  void initState() {
    super.initState();

    // Seçili kişileri al (varsa)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        final selectedIds = args['selectedContactIds'];
        if (selectedIds != null && selectedIds is Set<String>) {
          setState(() {
            _selectedContactIds = selectedIds;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tema modunu kontrol et
    final isDarkMode = ref.watch(themeProvider) == ThemeMode.dark;

    // Tema renkleri
    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.lightBackgroundColor;
    final cardColor =
        isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondaryColor
        : AppTheme.lightTextSecondaryColor;

    // İçerik alanı arka plan rengi
    final contentBackgroundColor = backgroundColor;

    // Seçilen format ve dosya adı
    final selectedFormat = ref.watch(selectedFormatProvider);
    final fileName = ref.watch(fileNameProvider);

    // Premium kullanıcı durumu
    final isPremium = ref.watch(isPremiumProvider);

    // Ücretsiz sınır
    final maxFreeContacts = ref.watch(maxFreeContactsProvider);

    // Rehber izin durumu
    final permissionState = ref.watch(contactsPermissionProvider);

    // Kişi sayısı bilgisi
    final contactsCountAsync = ref.watch(contactsCountProvider);
    final filteredCountAsync = ref.watch(filteredContactsCountProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          context.l10n.export_screen_title,
          style: TextStyle(color: textColor),
        ),
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        backgroundColor: backgroundColor,
      ),
      body: permissionState == PermissionStatus.granted
          ? Container(
              color: contentBackgroundColor,
              child: contactsCountAsync.when(
                loading: () => Center(
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
                        context.l10n.loading_contacts,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                error: (error, stack) => Center(
                  child: Text(
                    'Kişileri yüklerken hata oluştu: $error',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                data: (totalContacts) {
                  // Filtrelenmiş kişi sayısını al
                  final filteredCount = filteredCountAsync.maybeWhen(
                    data: (count) => count,
                    orElse: () => totalContacts,
                  );

                  // Maksimum dışa aktarılabilecek kişi sayısı
                  final maxExportableContacts = isPremium
                      ? filteredCount
                      : min(filteredCount, maxFreeContacts);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dışa Aktarma Formatı
                        Text(
                          context.l10n.export_format,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 16),

                        // Format seçenekleri
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isDarkMode ? Colors.white24 : Colors.black12,
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: ContactFormat.values.map((format) {
                                return InkWell(
                                  onTap: () {
                                    ref
                                        .read(selectedFormatProvider.notifier)
                                        .state = format;
                                  },
                                  child: Container(
                                    width: 56,
                                    decoration: BoxDecoration(
                                      color: selectedFormat == format
                                          ? AppTheme.primaryColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: selectedFormat == format
                                            ? Colors.transparent
                                            : isDarkMode
                                                ? Colors.white30
                                                : Colors.black12,
                                        width: 1,
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _getFormatIcon(format),
                                          color: selectedFormat == format
                                              ? Colors.white
                                              : textColor,
                                          size: 24,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          format.displayName,
                                          style: TextStyle(
                                            color: selectedFormat == format
                                                ? Colors.white
                                                : textColor,
                                            fontWeight: selectedFormat == format
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                        SizedBox(height: 24),

                        // Seçili format bilgisi
                        Container(
                          padding: EdgeInsets.all(16),
                          height: 110, // Sabit yükseklik
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getFormatIcon(selectedFormat),
                                    color: AppTheme.primaryColor,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${selectedFormat.displayName}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${selectedFormat.fileExtension} Dosyası',
                                    style: TextStyle(
                                      color: textSecondaryColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  _getFormatDescription(selectedFormat),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textSecondaryColor,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24),

                        // Yedekleme Hedefi
                        Text(
                          context.l10n.export_destination,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),

                        SizedBox(height: 16),

                        // Paylaş veya Kaydet seçenekleri
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isDarkMode ? Colors.white24 : Colors.black12,
                              width: 1,
                            ),
                          ),
                          padding: EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Paylaş seçeneği
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _exportDestination =
                                          ExportDestination.share;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _exportDestination ==
                                                ExportDestination.share
                                            ? AppTheme.primaryColor
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.share,
                                          color: AppTheme.primaryColor,
                                          size: 24,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          context.l10n.share,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(width: 16),

                              // Kaydet seçeneği
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _exportDestination =
                                          ExportDestination.saveToPhone;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _exportDestination ==
                                                ExportDestination.saveToPhone
                                            ? AppTheme.primaryColor
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.save,
                                          color: AppTheme.primaryColor,
                                          size: 24,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          context.l10n.save_to_phone,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20),

                        // Dışa aktarma butonu
                        _isExporting
                            ? Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      ref.watch(exportStatusMessageProvider),
                                      style: TextStyle(color: textColor),
                                    ),
                                  ],
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: filteredCount > 0
                                    ? () => _exportContacts()
                                    : null,
                                icon: Icon(
                                  _exportDestination == ExportDestination.share
                                      ? Icons.share
                                      : Icons.save,
                                ),
                                label: Text(
                                  _exportDestination == ExportDestination.share
                                      ? context.l10n.export_and_share
                                      : context.l10n.save_share,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  elevation: 2,
                                ),
                              ),

                        SizedBox(height: 16),

                        // Premium butonu
                        if (!isPremium)
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/premium');
                            },
                            icon: Icon(
                              Icons.workspace_premium,
                              color: Colors.amber,
                            ),
                            label: Text(
                              context.l10n.premium_button,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(
                                  color: Colors.amber.withOpacity(0.5)),
                              padding: EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),

                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // Premium bilgisi (Sadece sınırı aşıyorsa göster)
                        if (!isPremium && filteredCount > maxFreeContacts)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text(
                              context.l10n.premium_limit_message.replaceAll(
                                  '{limit}', maxFreeContacts.toString()),
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            )
          : _buildPermissionRequestScreen(isDarkMode, textColor),
    );
  }

  // Format açıklaması
  String _getFormatDescription(ContactFormat format) {
    switch (format) {
      case ContactFormat.vCard:
        return context.l10n.vcard_desc;
      case ContactFormat.csv:
        return context.l10n.csv_desc;
      case ContactFormat.excel:
        return context.l10n.excel_desc;
      case ContactFormat.pdf:
        return context.l10n.pdf_desc;
      case ContactFormat.json:
        return context.l10n.json_desc;
    }
  }

  // Format için ikon seç
  IconData _getFormatIcon(ContactFormat format) {
    switch (format) {
      case ContactFormat.vCard:
        return Icons.contacts;
      case ContactFormat.csv:
        return Icons.table_chart;
      case ContactFormat.excel:
        return Icons.insert_chart;
      case ContactFormat.pdf:
        return Icons.picture_as_pdf;
      case ContactFormat.json:
        return Icons.code;
    }
  }

  // İzin isteme ekranı
  Widget _buildPermissionRequestScreen(bool isDarkMode, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contacts,
              size: 64,
              color: AppTheme.primaryColor,
            ),
            SizedBox(height: 16),
            Text(
              context.l10n.permission_required,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 16),
            Text(
              context.l10n.contacts_permission_message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _requestPermission,
              icon: Icon(Icons.security),
              label: Text(context.l10n.grant_permission),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // İzin isteme fonksiyonu
  Future<void> _requestPermission() async {
    try {
      final status = await Permission.contacts.request();
      ref.read(contactsPermissionProvider.notifier).state = status;
    } catch (e) {
      debugPrint('İzin isteme hatası: $e');
    }
  }

  // Dışa aktarma işlemi
  Future<void> _exportContacts() async {
    try {
      // Format bilgisini al
      final format = ref.read(selectedFormatProvider);

      // Premium durumunu al
      final isPremium = ref.read(isPremiumProvider);

      // Ücretsiz sınır
      final maxFreeContacts = ref.read(maxFreeContactsProvider);

      // Filtrelenmiş kişi sayısını al
      final filteredCountAsync = ref.read(filteredContactsCountProvider);
      final int contactsCount = await filteredCountAsync.maybeWhen(
        data: (count) => count,
        orElse: () async {
          final totalCount = await ref.read(contactsCountProvider.future);
          return totalCount;
        },
      );

      // Aktarılacak kişi sayısını belirle
      final int exportContactCount = !isPremium &&
              contactsCount > maxFreeContacts &&
              _selectedContactIds == null
          ? maxFreeContacts
          : contactsCount;

      // Premium kontrolü
      if (!isPremium &&
          contactsCount > maxFreeContacts &&
          _selectedContactIds == null) {
        // Premium olmayan kullanıcılar için sınırlama
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.premium_limit_message
                  .replaceAll('{limit}', maxFreeContacts.toString()),
            ),
            action: SnackBarAction(
              label: context.l10n.premium_title,
              onPressed: () {
                Navigator.pushNamed(context, '/premium');
              },
            ),
          ),
        );
      }

      // Dışa aktarım onayı diyaloğunu göster
      final shouldExport = await _showExportConfirmDialog(
          format: format, contactsCount: exportContactCount);

      if (!shouldExport) {
        return; // Kullanıcı iptal etti
      }

      setState(() {
        _isExporting = true;
        _errorMessage = null;
      });

      // Dışa aktarma durumunu güncelle
      ref.read(exportStateProvider.notifier).state = ExportState.loading;
      ref.read(exportStatusMessageProvider.notifier).state =
          'Kişiler hazırlanıyor...';

      // Filtreleme ayarlarını al
      final includeContactsWithoutNumber =
          ref.read(includeContactsWithoutNumberProvider);
      final includeNumbersWithoutName =
          ref.read(includeNumbersWithoutNameProvider);

      // Dışa aktar
      final exportedFile = await _contactsManager.exportContacts(
        format,
        limitContacts: isPremium ? null : maxFreeContacts,
        selectedContactIds: _selectedContactIds,
        includeContactsWithoutNumber: includeContactsWithoutNumber,
        includeNumbersWithoutName: includeNumbersWithoutName,
      );

      ref.read(exportedFileProvider.notifier).state = exportedFile;
      ref.read(exportStateProvider.notifier).state = ExportState.success;

      setState(() {
        _isExporting = false;
      });

      // Dosyayı paylaş veya kaydet
      if (_exportDestination == ExportDestination.share) {
        ref.read(exportStatusMessageProvider.notifier).state =
            'Dosya paylaşılıyor...';
        await _fileSharingService.shareFile(
          exportedFile,
          format,
        );
      } else {
        // Telefona kaydetme işlemi
        await _saveToPhone(exportedFile, format);
      }

      // BackupService üzerinden otomatik yedeği kaydet
      try {
        final backupService = BackupService();
        final fileExt = format.fileExtension.replaceAll('.', '');

        // Dosya ismini tarih ve kişi sayısı ile birlikte oluştur
        final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
        final filename =
            "${_fileNameController.text}_${dateStr}_${exportContactCount}kisi.$fileExt";

        // Dosya içeriğini oku
        final fileContent = await File(exportedFile).readAsString();

        // Yedek dosyasını oluştur
        final savedFile = await backupService
            .createBackupFile(fileContent, fileExt, customName: filename);

        debugPrint('Dosya kalıcı olarak yedeklendi: ${savedFile.path}');

        // Bu çözüm ekran kapatıldığında dosyanın silinmemesini sağlar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Dosya yedeklendi: ${savedFile.path.split('/').last}'),
            duration: const Duration(seconds: 2),
          ),
        );

        // Kısa bir gecikme ekleyerek ana ekrana dönüş
        await Future.delayed(Duration(milliseconds: 500));
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        debugPrint('Dosya yedekleme hatası: $e');
      }
    } catch (e) {
      ref.read(exportStateProvider.notifier).state = ExportState.error;
      setState(() {
        _isExporting = false;
        _errorMessage = 'Hata: $e';
      });
    }
  }

  // Dışa aktarma onay diyaloğu
  Future<bool> _showExportConfirmDialog({
    required ContactFormat format,
    required int contactsCount,
  }) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Dışa aktarma hedefi
    final destination = _exportDestination == ExportDestination.share
        ? 'paylaşılmak'
        : 'kaydedilmek';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: const Text('Kişileri Dışa Aktar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '$contactsCount kişi ${format.displayName} formatında dışa aktarılacak.'),
            SizedBox(height: 8),
            Text(
              'Oluşturulacak dosya $destination üzere hazırlanacak.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            if (_fileNameController.text.isNotEmpty)
              Text(
                'Dosya adı: ${_fileNameController.text}_${DateFormat('yyyyMMdd').format(DateTime.now())}_${contactsCount}kisi${format.fileExtension}',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                ),
              ),
            if (contactsCount > 200)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  'Not: $contactsCount kişinin dışa aktarılması biraz zaman alabilir.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text('Dışa Aktar'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // Telefona kaydetme işlemi
  Future<void> _saveToPhone(String filePath, ContactFormat format) async {
    try {
      // Dosya varlığını kontrol et
      final file = File(filePath);
      if (!(await file.exists())) {
        throw Exception('Kaydedilecek dosya bulunamadı');
      }

      // Dosya adını al
      final fileName = filePath.split('/').last;

      // Kaydetme konumunu seç
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Yedekleme Konumu Seçin',
      );

      if (selectedDirectory == null) {
        // Kullanıcı iptal etti
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydetme işlemi iptal edildi')),
        );
        return;
      }

      // Hedef dosya yolu
      final targetPath = '$selectedDirectory/$fileName';

      // Dosyayı kopyala
      await file.copy(targetPath);

      // Başarı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya başarıyla kaydedildi: $targetPath'),
          action: SnackBarAction(
            label: 'Göster',
            onPressed: () async {
              await _fileSharingService.openFile(targetPath);
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya kaydedilemedi: $e')),
      );
    }
  }
}
