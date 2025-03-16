import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../services/contacts_service.dart';
import '../services/backup_service.dart';
import '../models/contact_format.dart';
import '../theme/app_theme.dart';
import 'package:flutter/foundation.dart';

// İçe aktarma işlem durumları
enum ImportState { initial, loading, success, error }

// İçe aktarma durumu sağlayıcısı
final importStateProvider =
    StateProvider<ImportState>((ref) => ImportState.initial);

// İçe aktarılan kişi sayısı sağlayıcısı
final importedCountProvider = StateProvider<int>((ref) => 0);

// Seçili dosya formatı sağlayıcısı
final selectedFormatProvider =
    StateProvider<ContactFormat>((ref) => ContactFormat.vCard);

// Backup servisini provider olarak tanımla
final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

// Tüm yedek dosyalarını getiren provider
final backupFilesProvider = FutureProvider<List<BackupFile>>((ref) async {
  final backupService = ref.watch(backupServiceProvider);

  // Debug: Dizinleri ve dosyaları kontrol et
  final backupDir = await backupService.backupDirectory;
  final exportDir = await backupService.exportDirectory;

  debugPrint('Yedek dizini: ${backupDir.path}');
  debugPrint('Yedek dizini mevcut mu: ${await backupDir.exists()}');

  debugPrint('Dışa aktarma dizini: ${exportDir.path}');
  debugPrint('Dışa aktarma dizini mevcut mu: ${await exportDir.exists()}');

  // Dizinleri manuel olarak oluştur
  if (!await backupDir.exists()) {
    debugPrint('Yedek dizini oluşturuluyor...');
    await backupDir.create(recursive: true);
  }

  if (!await exportDir.exists()) {
    debugPrint('Dışa aktarma dizini oluşturuluyor...');
    await exportDir.create(recursive: true);
  }

  // Test dosyası oluştur (eğer hiç dosya yoksa)
  final testBackupDir = await backupService.backupDirectory;
  final testFiles = await testBackupDir.list().toList();

  if (testFiles.isEmpty) {
    debugPrint('Test dosyaları oluşturuluyor...');
    try {
      // Test vCard dosyası oluştur
      final testVcardPath = '${testBackupDir.path}/test_backup.vcf';
      final testVcardFile = File(testVcardPath);
      await testVcardFile.writeAsString(
          'BEGIN:VCARD\nVERSION:3.0\nFN:Test Kişi\nTEL:+905551234567\nEND:VCARD');
      debugPrint('Test vCard dosyası oluşturuldu: ${testVcardFile.path}');
    } catch (e) {
      debugPrint('Test dosyası oluşturma hatası: $e');
    }
  }

  // Tüm dosyaları getir
  final files = await backupService.getAllBackupFiles();
  debugPrint('Bulunan toplam dosya sayısı: ${files.length}');
  for (final file in files) {
    debugPrint(
        'Dosya: ${file.path}, Boyut: ${file.formattedSize}, Format: ${file.format}');
  }

  return files;
});

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _contactsManager = ContactsManager();
  String? _selectedFilePath;
  String? _selectedFileName;
  String? _errorMessage;
  bool _isLoading = false;
  String? _successMessage;

  @override
  Widget build(BuildContext context) {
    final importState = ref.watch(importStateProvider);
    final importedCount = ref.watch(importedCountProvider);
    final selectedFormat = ref.watch(selectedFormatProvider);
    final backupFilesAsync = ref.watch(backupFilesProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yedeği Geri Yükle'),
      ),
      body: Stack(
        children: [
          // Ana içerik
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFormatSelector(selectedFormat),
                const SizedBox(height: 16),

                Text(
                  'Mevcut Yedek Dosyaları',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                // Dosya listesi
                Expanded(
                  child: backupFilesAsync.when(
                    data: (backupFiles) {
                      if (backupFiles.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_off_outlined,
                                size: 80,
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.black38,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz yedek dosyanız bulunmuyor.',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.black54,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/export'),
                                icon: const Icon(Icons.backup),
                                label: const Text('Yedek Oluştur'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Dosya formatına göre filtreleme yap
                      final filteredFiles = backupFiles.where((file) {
                        switch (selectedFormat) {
                          case ContactFormat.vCard:
                            return file.format.toLowerCase() == 'vcf';
                          case ContactFormat.csv:
                            return file.format.toLowerCase() == 'csv';
                          case ContactFormat.excel:
                            return file.format.toLowerCase() == 'xlsx';
                          case ContactFormat.json:
                            return file.format.toLowerCase() == 'json';
                          default:
                            return true;
                        }
                      }).toList();

                      if (filteredFiles.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.filter_list_off,
                                size: 60,
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.black38,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Seçili formatta yedek dosya bulunamadı.',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.black54,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () => _pickFile(),
                                icon: const Icon(Icons.file_open),
                                label: const Text('Başka Bir Dosya Seç'),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.refresh(backupFilesProvider);
                        },
                        child: ListView.builder(
                          itemCount: filteredFiles.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            final file = filteredFiles[index];
                            return _buildFileItem(file, context, isDarkMode);
                          },
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Text(
                        'Dosyalar yüklenirken hata oluştu: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Divider(),
                const SizedBox(height: 16),

                Text(
                  'Harici Dosya Seçimi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Başka Bir Dosya Seç'),
                ),

                if (_selectedFilePath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.description,
                                    color: Colors.blue),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedFileName ?? 'Seçili Dosya',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _selectedFilePath = null;
                              _selectedFileName = null;
                            });
                          },
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _restoreFile(_selectedFilePath!),
                          icon: const Icon(Icons.restore),
                          label: const Text('Geri Yükle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Yükleniyor göstergesi
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // Hata mesajı
          if (_errorMessage != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),
            ),

          // Başarı mesajı
          if (_successMessage != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.green),
                      onPressed: () => setState(() => _successMessage = null),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileItem(
      BackupFile file, BuildContext context, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      color: isDarkMode ? const Color(0xFF252525) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode ? Colors.white24 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: file.color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            file.icon,
            color: file.color,
            size: 24,
          ),
        ),
        title: Text(
          file.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${file.formatName} - ${file.formattedSize}',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            Text(
              'Oluşturulma: ${file.formattedDate}',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _restoreFile(file.path),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('Geri Yükle'),
        ),
        onTap: () => _showFileDetails(file),
      ),
    );
  }

  void _showFileDetails(BackupFile file) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  file.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(file.path),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Geri Yükle'),
                onTap: () {
                  Navigator.pop(context);
                  _restoreFile(file.path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text('Dosya Formatı: ${file.formatName}'),
                subtitle: Text('Boyut: ${file.formattedSize}'),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text('Oluşturulma Tarihi'),
                subtitle: Text(file.formattedDate),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormatSelector(ContactFormat selectedFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dosya Formatı Filtresi',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildFormatChip(ContactFormat.vCard, 'vCard (.vcf)'),
            _buildFormatChip(ContactFormat.csv, 'CSV (.csv)'),
            _buildFormatChip(ContactFormat.excel, 'Excel (.xlsx)'),
            _buildFormatChip(ContactFormat.json, 'JSON (.json)'),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatChip(ContactFormat format, String label) {
    final selectedFormat = ref.watch(selectedFormatProvider);
    final isSelected = format == selectedFormat;

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey.shade200,
      selectedColor: Colors.blue,
      onSelected: (value) {
        if (value) {
          ref.read(selectedFormatProvider.notifier).state = format;
        }
      },
    );
  }

  Future<void> _pickFile() async {
    final selectedFormat = ref.read(selectedFormatProvider);
    String fileExtension;

    switch (selectedFormat) {
      case ContactFormat.vCard:
        fileExtension = 'vcf';
        break;
      case ContactFormat.csv:
        fileExtension = 'csv';
        break;
      case ContactFormat.excel:
        fileExtension = 'xlsx';
        break;
      case ContactFormat.json:
        fileExtension = 'json';
        break;
      default:
        fileExtension = '*';
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [fileExtension],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFilePath = file.path;
          _selectedFileName = file.name;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Dosya seçimi sırasında bir hata oluştu: $e';
      });
    }
  }

  Future<void> _restoreFile(String filePath) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (!filePath.toLowerCase().endsWith('.vcf')) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Şu anda sadece vCard (.vcf) dosyaları geri yüklenebilir.';
        });
        return;
      }

      final importedCount =
          await _contactsManager.importContactsFromVCard(filePath);

      setState(() {
        _isLoading = false;
        _successMessage =
            '$importedCount kişi rehberinize başarıyla geri yüklendi.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Geri yükleme sırasında bir hata oluştu: $e';
      });
    }
  }
}
