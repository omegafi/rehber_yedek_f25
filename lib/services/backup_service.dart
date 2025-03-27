import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/contact_format.dart';

/// Yedeklenen veya dışarı aktarılan bir dosyayı temsil eden sınıf
class BackupFile {
  final String path;
  final String name;
  final DateTime dateCreated;
  final String format; // 'vcf', 'csv', 'json', vb.
  final int size; // byte cinsinden

  BackupFile({
    required this.path,
    required this.name,
    required this.dateCreated,
    required this.format,
    required this.size,
  });

  /// Dosya boyutunu formatlar (KB, MB, vb.)
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Oluşturulma tarihini formatlar
  String get formattedDate {
    return DateFormat('dd.MM.yyyy HH:mm').format(dateCreated);
  }

  /// Dosya formatının adını döndürür
  String get formatName {
    switch (format.toLowerCase()) {
      case 'vcf':
        return 'vCard';
      case 'csv':
        return 'CSV';
      case 'json':
        return 'JSON';
      default:
        return format.toUpperCase();
    }
  }

  /// Dosya formatına göre simge döndürür
  IconData get icon {
    switch (format.toLowerCase()) {
      case 'vcf':
        return Icons.contact_page;
      case 'csv':
        return Icons.table_chart;
      case 'json':
        return Icons.data_object;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Dosya formatına göre renk döndürür
  Color get color {
    switch (format.toLowerCase()) {
      case 'vcf':
        return Colors.blue;
      case 'csv':
        return Colors.green;
      case 'json':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Dosya adından biçim çıkarma
  static String getFormatFromFilename(String filename) {
    final extension = filename.split('.').last;
    return extension;
  }

  /// Dosya yolundan BackupFile nesnesi oluşturma
  static Future<BackupFile> fromFile(File file) async {
    try {
      final stats = await file.stat();
      final filename = file.path.split('/').last;

      debugPrint('Dosya istatistikleri alındı: ${file.path}');
      debugPrint(
          'Dosya boyutu: ${stats.size}, Değiştirilme tarihi: ${stats.changed}');

      // Format bilgisini al
      String format = '';
      try {
        format = getFormatFromFilename(filename);
        debugPrint('Dosya formatı: $format');
      } catch (e) {
        debugPrint('Format alınırken hata: $e');
        // Varsayılan bir değer ata
        format = 'unknown';
      }

      return BackupFile(
        path: file.path,
        name: filename,
        dateCreated: stats.changed,
        format: format,
        size: stats.size,
      );
    } catch (e) {
      debugPrint('BackupFile oluşturulurken hata: $e');
      // Hata durumunda varsayılan değerlerle oluştur
      return BackupFile(
        path: file.path,
        name: file.path.split('/').last,
        dateCreated: DateTime.now(),
        format: 'unknown',
        size: 0,
      );
    }
  }
}

/// Yedekleme işlemlerini yöneten servis sınıfı
class BackupService {
  /// Yedekleme dizinini al
  Future<Directory> get backupDirectory async {
    try {
      debugPrint('Yedekleme dizini alınıyor...');

      // Uygulama belgeler dizinini al
      final appDocDir = await getApplicationDocumentsDirectory();
      debugPrint('Uygulama belgeler dizini: ${appDocDir.path}');

      // Yedekleme dizini
      final backupDir = Directory('${appDocDir.path}/backups');
      debugPrint('Oluşturulacak yedekleme dizini: ${backupDir.path}');

      // Dizinin var olup olmadığını kontrol et
      final exists = await backupDir.exists();
      debugPrint('Yedekleme dizini var mı: $exists');

      if (!exists) {
        debugPrint('Yedekleme dizini oluşturuluyor...');
        await backupDir.create(recursive: true);
        debugPrint('Yedekleme dizini oluşturuldu: ${backupDir.path}');

        // Dizin oluşturulduktan sonra tekrar kontrol et
        final existsAfterCreate = await backupDir.exists();
        debugPrint(
            'Oluşturma sonrası yedekleme dizini var mı: $existsAfterCreate');

        if (!existsAfterCreate) {
          debugPrint('UYARI: Yedekleme dizini oluşturulamadı!');
          // Alternatif konum dene (geçici dizin)
          final tempDir = await getTemporaryDirectory();
          final tempBackupDir = Directory('${tempDir.path}/backups');
          await tempBackupDir.create(recursive: true);
          debugPrint(
              'Alternatif geçici yedekleme dizini oluşturuldu: ${tempBackupDir.path}');
          return tempBackupDir;
        }
      }

      return backupDir;
    } catch (e) {
      debugPrint('Yedekleme dizini alınırken hata: $e');
      // Hata durumunda geçici dizin döndür
      final tempDir = await getTemporaryDirectory();
      final tempBackupDir = Directory('${tempDir.path}/backups');
      try {
        await tempBackupDir.create(recursive: true);
      } catch (e) {
        debugPrint('Geçici yedekleme dizini oluşturma hatası: $e');
      }
      return tempBackupDir;
    }
  }

  /// Dışa aktarma dizinini al
  Future<Directory> get exportDirectory async {
    try {
      debugPrint('Dışa aktarma dizini alınıyor...');

      // Uygulama belgeler dizinini al
      final appDocDir = await getApplicationDocumentsDirectory();
      debugPrint('Uygulama belgeler dizini: ${appDocDir.path}');

      // Dışa aktarma dizini
      final exportDir = Directory('${appDocDir.path}/exports');
      debugPrint('Oluşturulacak dışa aktarma dizini: ${exportDir.path}');

      // Dizinin var olup olmadığını kontrol et
      final exists = await exportDir.exists();
      debugPrint('Dışa aktarma dizini var mı: $exists');

      if (!exists) {
        debugPrint('Dışa aktarma dizini oluşturuluyor...');
        await exportDir.create(recursive: true);
        debugPrint('Dışa aktarma dizini oluşturuldu: ${exportDir.path}');

        // Dizin oluşturulduktan sonra tekrar kontrol et
        final existsAfterCreate = await exportDir.exists();
        debugPrint(
            'Oluşturma sonrası dışa aktarma dizini var mı: $existsAfterCreate');

        if (!existsAfterCreate) {
          debugPrint('UYARI: Dışa aktarma dizini oluşturulamadı!');
          // Alternatif konum dene (geçici dizin)
          final tempDir = await getTemporaryDirectory();
          final tempExportDir = Directory('${tempDir.path}/exports');
          await tempExportDir.create(recursive: true);
          debugPrint(
              'Alternatif geçici dışa aktarma dizini oluşturuldu: ${tempExportDir.path}');
          return tempExportDir;
        }
      }

      return exportDir;
    } catch (e) {
      debugPrint('Dışa aktarma dizini alınırken hata: $e');
      // Hata durumunda geçici dizin döndür
      final tempDir = await getTemporaryDirectory();
      final tempExportDir = Directory('${tempDir.path}/exports');
      try {
        await tempExportDir.create(recursive: true);
      } catch (e) {
        debugPrint('Geçici dışa aktarma dizini oluşturma hatası: $e');
      }
      return tempExportDir;
    }
  }

  /// Tüm yedek dosyalarını getir (hem yedekler hem dışa aktarılanlar)
  Future<List<BackupFile>> getAllBackupFiles() async {
    List<BackupFile> files = [];

    debugPrint('===== YEDEK DOSYALARI GETİRİLİYOR =====');

    try {
      // Yedek dizinini kontrol et
      final backupDir = await backupDirectory;
      debugPrint('Yedek dizini: ${backupDir.path}');

      if (await backupDir.exists()) {
        debugPrint('Yedek dizini mevcut, dosyalar listeleniyor...');

        try {
          // Önce dizindeki tüm entitileri listele
          final allEntities = await backupDir.list().toList();
          debugPrint('Yedek dizininde toplam: ${allEntities.length} öğe var');

          // Dosya olanları filtrele
          final backupFiles = await backupDir
              .list()
              .where((entity) => entity is File)
              .cast<File>()
              .toList();

          debugPrint('Yedek dizininde ${backupFiles.length} dosya bulundu');

          for (final file in backupFiles) {
            try {
              debugPrint('Dosya işleniyor: ${file.path}');
              final backupFile = await BackupFile.fromFile(file);
              files.add(backupFile);
              debugPrint(
                  'Dosya eklendi: ${backupFile.name}, ${backupFile.formattedSize}');
            } catch (e) {
              debugPrint('Dosya işlenirken hata: ${file.path} - $e');
            }
          }
        } catch (e) {
          debugPrint('Yedek dizini listelenirken hata: $e');
        }
      } else {
        debugPrint('Yedek dizini mevcut değil!');
        // Dizini oluşturmayı dene
        await backupDir.create(recursive: true);
        debugPrint('Yedek dizini oluşturuldu: ${backupDir.path}');
      }

      // Dışa aktarma dizinini kontrol et
      final exportDir = await exportDirectory;
      debugPrint('Dışa aktarma dizini: ${exportDir.path}');

      if (await exportDir.exists()) {
        debugPrint('Dışa aktarma dizini mevcut, dosyalar listeleniyor...');

        try {
          // Önce dizindeki tüm entitileri listele
          final allEntities = await exportDir.list().toList();
          debugPrint(
              'Dışa aktarma dizininde toplam: ${allEntities.length} öğe var');

          // Dosya olanları filtrele
          final exportFiles = await exportDir
              .list()
              .where((entity) => entity is File)
              .cast<File>()
              .toList();

          debugPrint(
              'Dışa aktarma dizininde ${exportFiles.length} dosya bulundu');

          for (final file in exportFiles) {
            try {
              debugPrint('Dosya işleniyor: ${file.path}');
              final backupFile = await BackupFile.fromFile(file);
              files.add(backupFile);
              debugPrint(
                  'Dosya eklendi: ${backupFile.name}, ${backupFile.formattedSize}');
            } catch (e) {
              debugPrint('Dosya işlenirken hata: ${file.path} - $e');
            }
          }
        } catch (e) {
          debugPrint('Dışa aktarma dizini listelenirken hata: $e');
        }
      } else {
        debugPrint('Dışa aktarma dizini mevcut değil!');
        // Dizini oluşturmayı dene
        await exportDir.create(recursive: true);
        debugPrint('Dışa aktarma dizini oluşturuldu: ${exportDir.path}');
      }

      // Dosyaları tarihe göre sırala (en yeniden en eskiye)
      files.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));

      debugPrint('Toplam ${files.length} yedek dosyası bulundu');

      return files;
    } catch (e) {
      debugPrint('Yedek dosyalarını getirirken genel hata: $e');
      return [];
    }
  }

  /// Belirli bir formattaki tüm yedek dosyalarını getir
  Future<List<BackupFile>> getBackupFilesByFormat(String format) async {
    final allFiles = await getAllBackupFiles();
    return allFiles
        .where((file) => file.format.toLowerCase() == format.toLowerCase())
        .toList();
  }

  /// Yedek dosyasını sil
  Future<bool> deleteBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Dosya silinirken hata oluştu: $e');
      return false;
    }
  }

  /// Yeni bir yedek dosyası oluştur
  Future<File> createBackupFile(String data, String format,
      {String? customName}) async {
    final dir = await backupDirectory;
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = customName ?? 'backup_$timestamp.$format';

    final file = File('${dir.path}/$filename');
    return await file.writeAsString(data);
  }

  /// Yeni bir dışa aktarma dosyası oluştur
  Future<File> createExportFile(String data, String format,
      {String? customName}) async {
    final dir = await exportDirectory;
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = customName ?? 'export_$timestamp.$format';

    final file = File('${dir.path}/$filename');
    return await file.writeAsString(data);
  }

  /// Dosyanın adını değiştir
  Future<bool> renameFile(String filePath, String newName) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final dir = filePath.substring(0, filePath.lastIndexOf('/'));
        final newPath = '$dir/$newName';
        await file.rename(newPath);
        return true;
      }
      return false;
    } catch (e) {
      print('Dosya adı değiştirilirken hata oluştu: $e');
      return false;
    }
  }

  // Yedek dosyalarını liste olarak getir
  Future<List<File>> getBackupFiles() async {
    try {
      // Yedekleme dizinine eriş
      final backupDir = await backupDirectory;

      // Dizinin içerdiği dosyaları kontrol et
      if (!await backupDir.exists()) {
        // Dizin yoksa oluştur
        await backupDir.create(recursive: true);
        return []; // Boş liste döndür
      }

      // Dizindeki tüm dosyaları listele
      final entities = await backupDir.list().toList();

      // Sadece dosyaları filtrele ve geriye kalan dosyaları döndür
      final files = entities.whereType<File>().where((file) {
        // Sadece desteklenen formattaki dosyaları filtrele
        final ext = file.path.split('.').last.toLowerCase();
        return ['vcf', 'csv', 'xlsx', 'pdf', 'json'].contains(ext);
      }).toList();

      // Dosyaları değiştirilme tarihine göre sırala (en yeniden eskiye)
      files.sort((a, b) {
        final aStats = a.statSync();
        final bStats = b.statSync();
        return bStats.modified.compareTo(aStats.modified);
      });

      return files;
    } catch (e) {
      debugPrint('Yedek dosyalarını getirme hatası: $e');
      return [];
    }
  }
}
