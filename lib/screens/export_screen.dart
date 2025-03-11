import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_format.dart';
import '../services/contacts_service.dart';
import '../services/file_sharing_service.dart';
import '../theme/app_theme.dart';
import '../main.dart'; // Provider'lar için
import '../screens/home_screen.dart'; // contactsCountProvider için
import '../utils/app_localizations.dart'; // Lokalizasyon için

// Premium durumu ve maksimum ücretsiz kişi sayısı için import
import '../main.dart' show isPremiumProvider, maxFreeContactsProvider;

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

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen>
    with SingleTickerProviderStateMixin {
  final _contactsManager = ContactsManager();
  final _fileSharingService = FileSharingService();
  String? _errorMessage;
  bool _isExporting = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
          context.l10n.export_screen_title,
          style: TextStyle(color: textColor),
        ),
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
      ),
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Format seçim bölümü
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.export_format,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFormatOptions(selectedFormat, cardColor, textColor),
                  ],
                ),
              ),
            ),

            // Alt bölüm (Premium uyarısı ve buton)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (needsPremium) ...[
                    _buildPremiumWarning(maxFreeContacts, contactsCount),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton.icon(
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
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.share),
                    label: Text(
                      isExporting
                          ? context.l10n.exporting
                          : context.l10n.export_and_share,
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
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
      ),
    );
  }

  // Format seçenekleri
  Widget _buildFormatOptions(
      ContactFormat selectedFormat, Color cardColor, Color textColor) {
    return Column(
      children: [
        // vCard formatı (tam genişlikte)
        _buildFormatOption(
          format: ContactFormat.vCard,
          title: 'vCard (.vcf)',
          description: context.l10n.vcard_desc,
          isSelected: selectedFormat == ContactFormat.vCard,
          cardColor: cardColor,
          textColor: textColor,
          isFullWidth: true,
        ),
        const SizedBox(height: 16),

        // Diğer formatlar (ikişerli grid)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _buildFormatOption(
              format: ContactFormat.csv,
              title: 'CSV (.csv)',
              description: context.l10n.csv_desc,
              isSelected: selectedFormat == ContactFormat.csv,
              cardColor: cardColor,
              textColor: textColor,
              isFullWidth: false,
            ),
            _buildFormatOption(
              format: ContactFormat.excel,
              title: 'Excel (.xlsx)',
              description: context.l10n.excel_desc,
              isSelected: selectedFormat == ContactFormat.excel,
              cardColor: cardColor,
              textColor: textColor,
              isFullWidth: false,
            ),
            _buildFormatOption(
              format: ContactFormat.pdf,
              title: 'PDF (.pdf)',
              description: context.l10n.pdf_desc,
              isSelected: selectedFormat == ContactFormat.pdf,
              cardColor: cardColor,
              textColor: textColor,
              isFullWidth: false,
            ),
            _buildFormatOption(
              format: ContactFormat.json,
              title: 'JSON (.json)',
              description: context.l10n.json_desc,
              isSelected: selectedFormat == ContactFormat.json,
              cardColor: cardColor,
              textColor: textColor,
              isFullWidth: false,
            ),
          ],
        ),
      ],
    );
  }

  // Format seçeneği
  Widget _buildFormatOption({
    required ContactFormat format,
    required String title,
    required String description,
    required bool isSelected,
    required Color cardColor,
    required Color textColor,
    required bool isFullWidth,
  }) {
    return InkWell(
      onTap: () {
        ref.read(selectedFormatProvider.notifier).state = format;
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: isFullWidth
            ? _buildFullWidthFormat(
                format, title, description, isSelected, textColor)
            : _buildGridFormat(
                format, title, description, isSelected, textColor),
      ),
    );
  }

  // Tam genişlikte format (vCard için)
  Widget _buildFullWidthFormat(ContactFormat format, String title,
      String description, bool isSelected, Color textColor) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getFormatIcon(format),
            color: isSelected ? AppTheme.primaryColor : Colors.grey,
            size: 24,
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
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        if (isSelected)
          const Icon(
            Icons.check_circle,
            color: AppTheme.primaryColor,
          ),
      ],
    );
  }

  // Grid format (diğer formatlar için)
  Widget _buildGridFormat(ContactFormat format, String title,
      String description, bool isSelected, Color textColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getFormatIcon(format),
            color: isSelected ? AppTheme.primaryColor : Colors.grey,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  // Premium uyarısı
  Widget _buildPremiumWarning(int maxFreeContacts, int contactsCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Premium gerekli',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.lightTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rehberinizde $contactsCount kişi var, ancak ücretsiz sürüm yalnızca ilk $maxFreeContacts kişiyi dışa aktarmanıza izin verir.',
            style: TextStyle(
              color: AppTheme.lightTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/premium');
            },
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Premium\'a Yükselt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
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

  // Dışa aktarma işlemi
  Future<void> _exportContacts(
    ContactFormat format,
    bool isPremium,
    int maxFreeContacts,
    int contactsCount,
  ) async {
    // Premium kontrolü
    if (!isPremium && contactsCount > maxFreeContacts) {
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
      // Kişileri al
      final contacts = await _contactsManager.getAllContacts();

      // Premium olmayan kullanıcılar için sınırlama
      final limitedContacts =
          isPremium ? contacts : contacts.take(maxFreeContacts).toList();

      // Dışa aktar
      final exportedFile = await _contactsManager.exportContacts(
        format,
        limitContacts: isPremium ? null : maxFreeContacts,
      );

      if (exportedFile != null) {
        ref.read(exportedFileProvider.notifier).state = exportedFile;
        ref.read(exportStateProvider.notifier).state = ExportState.success;

        // Dosyayı paylaş
        await _fileSharingService.shareFile(
          exportedFile,
          format,
        );
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
}
