import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/contact_format.dart';
import '../services/contacts_service.dart';
import '../services/file_sharing_service.dart';
import '../theme/app_theme.dart';
import '../main.dart'; // Provider'lar için
import '../screens/home_screen.dart'; // contactsCountProvider için
import '../utils/app_localizations.dart'; // Lokalizasyon için

// Premium durumu ve maksimum ücretsiz kişi sayısı için import
import '../main.dart' show isPremiumProvider, maxFreeContactsProvider;

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
  Widget build(BuildContext context) {
    // Tema modunu izle
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    // Tema renkleri
    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.lightBackgroundColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.lightTextColor;
    final cardColor =
        isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor;

    // Seçili formatı izle
    final selectedFormat = ref.watch(selectedFormatProvider);

    // İşlem durumunu izle
    final exportState = ref.watch(exportStateProvider);
    final isExporting = exportState == ExportState.loading;

    // Premium durumunu kontrol et
    final isPremium = ref.watch(isPremiumProvider);

    // Maksimum ücretsiz kişi sayısını al
    final maxFreeContacts = ref.watch(maxFreeContactsProvider);

    // Kişi sayısını kontrol et
    final contactsCountAsync = ref.watch(contactsCountProvider);
    final int contactsCount = contactsCountAsync.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );

    // Premium ihtiyacı var mı?
    final bool needsPremium = contactsCount > maxFreeContacts && !isPremium;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedContactIds != null
              ? context.l10n.backup_selected_contacts
                  .replaceAll('{count}', _selectedContactIds!.length.toString())
              : context.l10n.export_screen_title,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        elevation: 0,
        backgroundColor: backgroundColor,
        iconTheme:
            IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
      ),
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Ana içerik
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seçili kişi bilgisi
                  if (_selectedContactIds != null)
                    _buildInfoCard(
                      icon: Icons.people,
                      title: context.l10n.contacts_selected.replaceAll(
                          '{count}', _selectedContactIds!.length.toString()),
                      color: AppTheme.primaryColor,
                    ),

                  // Format seçimi
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.export_format,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildFormatSelector(selectedFormat, cardColor, textColor),

                  // Hedef seçimi
                  const SizedBox(height: 12),
                  Text(
                    'Yedekleme Hedefi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildDestinationSelector(cardColor, textColor),

                  // Premium uyarısı
                  if (needsPremium) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.warning_amber_rounded,
                      title: context.l10n.premium_required,
                      subtitle: context.l10n.premium_limit_message
                          .replaceAll('{count}', contactsCount.toString())
                          .replaceAll('{limit}', maxFreeContacts.toString()),
                      color: Colors.orange,
                      actionText: context.l10n.premium_button,
                      onAction: () => Navigator.pushNamed(context, '/premium'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Alt buton bölümü
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: isExporting
                  ? null
                  : () => _exportContacts(
                        selectedFormat,
                        isPremium,
                        maxFreeContacts,
                        contactsCount,
                      ),
              icon: isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(_exportDestination == ExportDestination.share
                      ? Icons.share
                      : Icons.save),
              label: Text(
                isExporting
                    ? context.l10n.exporting
                    : _exportDestination == ExportDestination.share
                        ? context.l10n.export_and_share
                        : 'Telefona Kaydet',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bilgi kartı widget'ı
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionText, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  // Format seçici
  Widget _buildFormatSelector(
      ContactFormat selectedFormat, Color cardColor, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: ContactFormat.values.map((format) {
          final isSelected = selectedFormat == format;
          return InkWell(
            onTap: () {
              ref.read(selectedFormatProvider.notifier).state = format;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _getFormatIcon(format),
                    color: isSelected ? AppTheme.primaryColor : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          format.displayName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: textColor,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _getFormatDescription(format, context),
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Hedef seçici
  Widget _buildDestinationSelector(Color cardColor, Color textColor) {
    return Row(
      children: [
        Expanded(
          child: _buildDestinationOption(
            title: 'Paylaş',
            icon: Icons.share,
            isSelected: _exportDestination == ExportDestination.share,
            cardColor: cardColor,
            textColor: textColor,
            onTap: () {
              setState(() {
                _exportDestination = ExportDestination.share;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildDestinationOption(
            title: 'Telefona Kaydet',
            icon: Icons.save,
            isSelected: _exportDestination == ExportDestination.saveToPhone,
            cardColor: cardColor,
            textColor: textColor,
            onTap: () {
              setState(() {
                _exportDestination = ExportDestination.saveToPhone;
              });
            },
          ),
        ),
      ],
    );
  }

  // Hedef seçeneği
  Widget _buildDestinationOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color cardColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: textColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Format için ikon seç
  IconData _getFormatIcon(ContactFormat format) {
    switch (format) {
      case ContactFormat.vCard:
        return Icons.contact_phone;
      case ContactFormat.csv:
        return Icons.table_chart;
      case ContactFormat.excel:
        return Icons.table_view;
      case ContactFormat.pdf:
        return Icons.picture_as_pdf;
      case ContactFormat.json:
        return Icons.code;
    }
  }

  // Format açıklaması
  String _getFormatDescription(ContactFormat format, BuildContext context) {
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

  // Dışa aktarma işlemi
  Future<void> _exportContacts(
    ContactFormat format,
    bool isPremium,
    int maxFreeContacts,
    int contactsCount,
  ) async {
    // Premium kontrolü
    if (!isPremium &&
        contactsCount > maxFreeContacts &&
        _selectedContactIds == null) {
      // Premium olmayan kullanıcılar için sınırlama
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ücretsiz sürümde yalnızca ilk $maxFreeContacts kişiyi dışa aktarabilirsiniz. Premium\'a yükseltin!',
          ),
          action: SnackBarAction(
            label: 'Premium',
            onPressed: () {
              Navigator.pushNamed(context, '/premium');
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });

    ref.read(exportStateProvider.notifier).state = ExportState.loading;
    ref.read(exportStatusMessageProvider.notifier).state =
        'Kişiler hazırlanıyor...';

    try {
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

      if (exportedFile != null) {
        ref.read(exportedFileProvider.notifier).state = exportedFile;
        ref.read(exportStateProvider.notifier).state = ExportState.success;

        if (_exportDestination == ExportDestination.share) {
          // Dosyayı paylaş
          await _fileSharingService.shareFile(
            exportedFile,
            format,
          );
        } else {
          // Telefona kaydet
          await _saveToPhone(exportedFile, format);
        }

        // Son yedekleme tarihini güncelle
        ref.read(lastBackupDateProvider.notifier).state = DateTime.now();
      } else {
        ref.read(exportStateProvider.notifier).state = ExportState.error;
        setState(() {
          _errorMessage = 'Dışa aktarma başarısız oldu';
        });
      }
    } catch (e) {
      ref.read(exportStateProvider.notifier).state = ExportState.error;
      setState(() {
        _errorMessage = 'Hata: $e';
      });
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
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
