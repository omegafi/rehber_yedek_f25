import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../services/backup_service.dart';
import '../services/contacts_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';

// Backup servisini provider olarak tanımla
final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

// Tüm yedek dosyalarını getiren provider
final backupFilesProvider = FutureProvider<List<BackupFile>>((ref) async {
  final backupService = ref.watch(backupServiceProvider);
  return await backupService.getAllBackupFiles();
});

class BackupFilesScreen extends ConsumerStatefulWidget {
  const BackupFilesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BackupFilesScreen> createState() => _BackupFilesScreenState();
}

class _BackupFilesScreenState extends ConsumerState<BackupFilesScreen> {
  final ContactsManager _contactsManager = ContactsManager();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  Widget build(BuildContext context) {
    final backupFilesAsync = ref.watch(backupFilesProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.backup_files ?? 'Yedek Dosyaları'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Ana içerik
          backupFilesAsync.when(
            data: (backupFiles) {
              if (backupFiles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 80,
                        color: isDarkMode ? Colors.white54 : Colors.black38,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.no_backup_files ??
                            'Henüz yedek dosyanız bulunmuyor.',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/export'),
                        icon: const Icon(Icons.backup),
                        label:
                            Text(context.l10n.create_backup ?? 'Yedek Oluştur'),
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

              return Column(
                children: [
                  // Bilgi metni
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      context.l10n.backup_files_info ??
                          'Yedeklenen ve dışarı aktarılan dosyalarınız. Geri yüklemek için dosyanın yanındaki butona tıklayın.',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  // Dosya listesi
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.refresh(backupFilesProvider);
                      },
                      child: ListView.builder(
                        itemCount: backupFiles.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final file = backupFiles[index];
                          return _buildFileItem(file, context, isDarkMode);
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Hata: $error',
                style: const TextStyle(color: Colors.red),
              ),
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDarkMode ? const Color(0xFF252525) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode ? Colors.white24 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst kısım - Dosya adı ve format
            Row(
              children: [
                Container(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        '${file.formatName} - ${file.formattedSize}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showFileOptions(context, file),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Orta kısım - Dosya bilgileri
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Text(
                'Oluşturulma tarihi: ${file.formattedDate}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Alt kısım - Butonlar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Paylaş'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDarkMode ? Colors.white70 : AppTheme.primaryColor,
                    side: BorderSide(
                      color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  onPressed: () => _shareFile(file),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Geri Yükle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _restoreFile(file),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFileOptions(BuildContext context, BackupFile file) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.of(context).size.width - 48, // 24 dp her iki taraftan
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Geri Yükle'),
                onTap: () {
                  Navigator.pop(context);
                  _restoreFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Paylaş'),
                onTap: () {
                  Navigator.pop(context);
                  _shareFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Sil', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteFile(file);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _restoreFile(BackupFile file) async {
    // Dosya formatı uygun mu kontrol et
    if (file.format != file.format) {
      setState(() {
        _errorMessage = 'Bu dosya formatı geri yükleme için desteklenmiyor.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      int importedCount = 0;

      // Dosya formatına göre geri yükleme işlemini yap
      if (file.format == file.format) {
        importedCount =
            await _contactsManager.importContactsFromVCard(file.path);
      }

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

  Future<void> _shareFile(BackupFile file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Rehber yedeğimi sizinle paylaşıyorum: ${file.name}',
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Dosya paylaşılırken bir hata oluştu: $e';
      });
    }
  }

  Future<void> _deleteFile(BackupFile file) async {
    // Silme işlemi için onay al
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Text('Dosya Silinecek'),
        content:
            Text('${file.name} dosyasını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final backupService = ref.read(backupServiceProvider);
      final success = await backupService.deleteBackupFile(file.path);

      setState(() {
        _isLoading = false;
        if (success) {
          _successMessage = '${file.name} başarıyla silindi.';
          // Listeyi yenile
          ref.refresh(backupFilesProvider);
        } else {
          _errorMessage = 'Dosya silinirken bir hata oluştu.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Dosya silinirken bir hata oluştu: $e';
      });
    }
  }
}
