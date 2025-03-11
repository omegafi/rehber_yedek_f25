import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/contact_format.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

class FileSharingService {
  // Dosyayı doğrudan paylaşma (herhangi bir uygulama ile) - kopyalama yapmadan
  Future<void> shareFileDirect(String filePath, ContactFormat format) async {
    try {
      final file = File(filePath);
      if (!(await file.exists())) {
        debugPrint('Dosya bulunamadı: $filePath');
        throw Exception('Paylaşılacak dosya bulunamadı: $filePath');
      }

      // Mime tipleri tanımla (WhatsApp daha iyi uyumluluk için)
      String mimeType;
      switch (format) {
        case ContactFormat.vCard:
          mimeType = 'text/vcard';
          break;
        case ContactFormat.csv:
          mimeType = 'text/csv';
          break;
        case ContactFormat.excel:
          mimeType =
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          break;
        case ContactFormat.pdf:
          mimeType = 'application/pdf';
          break;
        case ContactFormat.json:
          mimeType = 'application/json';
          break;
      }

      // Doğrudan dosyayı paylaş
      debugPrint('Dosya doğrudan paylaşılıyor: $filePath');
      debugPrint('Mime tipi: $mimeType');

      // Paylaşım metni
      final String shareText =
          'Rehber yedeği - ${format.displayName} formatında';

      // XFile oluşturarak mime tipi belirterek paylaş
      final xFile = XFile(filePath, mimeType: mimeType);

      final result = await Share.shareXFiles(
        [xFile],
        text: shareText,
        subject: 'Rehber Yedeği (${format.displayName})',
      );

      debugPrint('Doğrudan paylaşım sonucu: ${result.status}');
    } catch (e) {
      debugPrint('Doğrudan paylaşım hatası: $e');
      throw Exception('Dosya paylaşılamadı: $e');
    }
  }

  // Standart paylaşım metodu (geçici kopyalama ile)
  Future<void> shareFile(String filePath, ContactFormat format) async {
    try {
      final file = File(filePath);
      if (!(await file.exists())) {
        debugPrint('Dosya bulunamadı: $filePath');
        throw Exception('Paylaşılacak dosya bulunamadı: $filePath');
      }

      // Doğrudan dosyayı paylaş, kopyalama yapma
      return await shareFileDirect(filePath, format);
    } catch (e) {
      debugPrint('Standart paylaşım hatası: $e');
      throw Exception('Dosya paylaşılamadı: $e');
    }
  }

  // Genel dosya paylaşım metodunu ekleyelim - paylaşım ekranını tek bir buton ile açar
  Future<void> shareFileWithOptions(
      String filePath, ContactFormat format) async {
    try {
      // Dosya varlığını kontrol et
      final file = File(filePath);
      if (!(await file.exists())) {
        debugPrint('Dosya bulunamadı: $filePath');
        throw Exception('Paylaşılacak dosya bulunamadı: $filePath');
      }

      // Mime tipleri tanımla (WhatsApp daha iyi uyumluluk için)
      String mimeType;
      switch (format) {
        case ContactFormat.vCard:
          mimeType = 'text/vcard';
          break;
        case ContactFormat.csv:
          mimeType = 'text/csv';
          break;
        case ContactFormat.excel:
          mimeType =
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          break;
        case ContactFormat.pdf:
          mimeType = 'application/pdf';
          break;
        case ContactFormat.json:
          mimeType = 'application/json';
          break;
      }

      // Doğrudan paylaşım yap
      debugPrint('Dosya paylaşım ekranı açılıyor: $filePath');
      debugPrint('Mime tipi: $mimeType');

      // Paylaşım metni
      final String shareText =
          'Rehber yedeği - ${format.displayName} formatında';

      // XFile oluşturarak mime tipi belirterek paylaş
      final xFile = XFile(filePath, mimeType: mimeType);

      final result = await Share.shareXFiles(
        [xFile],
        text: shareText,
        subject: 'Rehber Yedeği (${format.displayName})',
      );

      debugPrint('Paylaşım sonucu: ${result.status}');
    } catch (e) {
      debugPrint('Paylaşım hatası: $e');
      throw Exception('Dosya paylaşılamadı: $e');
    }
  }

  // Dosya konumu seçerek kaydet (geliştirilmiş versiyonu)
  Future<String?> saveFileWithDirectoryPicker(String sourceFilePath) async {
    try {
      final fileName = path.basename(sourceFilePath);
      final sourceFile = File(sourceFilePath);

      if (!(await sourceFile.exists())) {
        debugPrint('Kaynak dosya bulunamadı: $sourceFilePath');
        throw Exception('Kaynak dosya bulunamadı');
      }

      String? savedPath;

      // Önce FilePicker ile konum seçmeyi deneyelim
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          // Önce depolama izinlerini kontrol et
          if (Platform.isAndroid) {
            var status = await Permission.storage.status;
            if (!status.isGranted) {
              status = await Permission.storage.request();
              if (!status.isGranted) {
                throw Exception('Depolama izni verilmedi');
              }
            }

            // Android 11+ için yönetilen depolama izni
            var externalStorageStatus =
                await Permission.manageExternalStorage.status;
            if (!externalStorageStatus.isGranted) {
              debugPrint('Yönetilen depolama izni isteniyor');
              externalStorageStatus =
                  await Permission.manageExternalStorage.request();
              debugPrint(
                  'Yönetilen depolama izni durumu: $externalStorageStatus');
            }
          }

          // Dizin seçme
          String? directoryPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'Yedek dosyasını kaydedeceğiniz dizini seçin',
          );

          if (directoryPath != null) {
            final targetPath = '$directoryPath/$fileName';
            debugPrint('Hedef yol: $targetPath');

            // Önce hedef yolda dosya varsa sil
            final targetFile = File(targetPath);
            if (await targetFile.exists()) {
              await targetFile.delete();
              debugPrint('Önceki dosya silindi: $targetPath');
            }

            // Dosyayı kopyala
            final newFile = await sourceFile.copy(targetPath);
            debugPrint('Dosya kopyalandı: ${newFile.path}');
            savedPath = newFile.path;
          } else {
            debugPrint('Dizin seçilmedi');
            // Dizin seçilmediyse alternatif olarak doğrudan paylaşım yap
            throw Exception('Dizin seçilmedi, paylaşım ekranı açılacak');
          }
        } else {
          // Masaüstü veya desteklenmeyen platform için
          throw Exception('Platform desteklenmiyor, paylaşım ekranı açılacak');
        }
      } catch (e) {
        debugPrint('FilePicker hatası, alternatif yönteme geçiliyor: $e');

        // Alternatif yöntem: Android için indirilenler klasörüne kaydetmeyi dene
        if (Platform.isAndroid) {
          savedPath = await saveToDownloadsOnAndroid(sourceFilePath);
        }

        // Kayıt başarısız olursa paylaşım ekranı aç
        if (savedPath == null) {
          debugPrint('Alternatif kaydetme başarısız, paylaşım ekranı açılıyor');
          // Paylaşım ekranını aç, kullanıcı istediği uygulamaya kaydetsin
          final result = await Share.shareXFiles(
            [XFile(sourceFilePath)],
            text: 'Rehber yedeğini kaydetmek için bir seçenek seçin',
          );
          debugPrint('Paylaşım sonucu: ${result.status}');
          return sourceFilePath; // Kaynak dosyayı döndür
        }
      }

      return savedPath;
    } catch (e) {
      debugPrint('Dosya kaydetme hatası: $e');

      // Son çare olarak share_plus kullan
      try {
        final result = await Share.shareXFiles(
          [XFile(sourceFilePath)],
          text: 'Rehber yedeğini kaydetmek için bir seçenek seçin',
        );
        debugPrint('Paylaşım sonucu: ${result.status}');
        return sourceFilePath;
      } catch (shareError) {
        debugPrint('Paylaşım da başarısız oldu: $shareError');
        return null;
      }
    }
  }

  // Android için optimize edilmiş dosya kaydetme
  Future<String?> saveToDownloadsOnAndroid(String sourceFilePath) async {
    try {
      if (!Platform.isAndroid) {
        return null;
      }

      final sourceFile = File(sourceFilePath);
      if (!(await sourceFile.exists())) {
        debugPrint('Kaynak dosya bulunamadı: $sourceFilePath');
        throw Exception('Kaynak dosya bulunamadı');
      }

      final fileName = path.basename(sourceFilePath);

      // Android için depolama izinlerini kontrol et
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Depolama izni verilmedi');
        }
      }

      // Android 11+ için yönetilen depolama izni kontrol et
      if (Platform.isAndroid) {
        var externalStorageStatus =
            await Permission.manageExternalStorage.status;
        if (!externalStorageStatus.isGranted) {
          debugPrint('Yönetilen depolama izni isteniyor');
          externalStorageStatus =
              await Permission.manageExternalStorage.request();
          debugPrint('Yönetilen depolama izni durumu: $externalStorageStatus');
        }
      }

      // Android'de indirilenler klasörüne doğrudan kaydetmeyi dene
      // Bu yol Android 10 ve üzeri için çalışmayabilir, Android 11+ için özel izin gerekir
      try {
        final downloadsPath = '/storage/emulated/0/Download';
        final targetPath = '$downloadsPath/$fileName';

        debugPrint('İndirme hedefi: $targetPath');

        // Hedef dosya var mı kontrol et ve varsa sil
        final targetFile = File(targetPath);
        if (await targetFile.exists()) {
          await targetFile.delete();
          debugPrint('Önceki dosya silindi: $targetPath');
        }

        // Dosyayı kopyala
        final newFile = await sourceFile.copy(targetPath);
        debugPrint('Dosya başarıyla indirildi: ${newFile.path}');

        return newFile.path;
      } catch (e) {
        debugPrint('İndirilenler klasörüne kopyalama hatası: $e');
        throw Exception(
            'İndirilenler klasörüne erişilemiyor, alternatif yönteme geçiliyor');
      }
    } catch (e) {
      debugPrint('Android için dosya kaydetme hatası: $e');
      return null;
    }
  }

  // WhatsApp ile dosya paylaşımı için özel metod
  Future<void> shareWithWhatsApp(String filePath, ContactFormat format) async {
    try {
      final file = File(filePath);
      if (!(await file.exists())) {
        debugPrint('Dosya bulunamadı: $filePath');
        throw Exception(
            'WhatsApp ile paylaşılacak dosya bulunamadı: $filePath');
      }

      // WhatsApp için optimize edilmiş MIME tipi
      String mimeType;
      switch (format) {
        case ContactFormat.vCard:
          mimeType = 'text/x-vcard'; // WhatsApp için alternatif MIME tipi dene
          break;
        case ContactFormat.csv:
          mimeType = 'text/csv';
          break;
        case ContactFormat.excel:
          mimeType =
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          break;
        case ContactFormat.pdf:
          mimeType = 'application/pdf';
          break;
        case ContactFormat.json:
          mimeType = 'application/json';
          break;
      }

      debugPrint('WhatsApp ile paylaşılıyor: $filePath');
      debugPrint('WhatsApp için MIME tipi: $mimeType');

      // XFile oluşturarak MIME tipi belirterek paylaş
      final xFile = XFile(filePath, mimeType: mimeType);

      final result = await Share.shareXFiles(
        [xFile],
        text: 'Rehber yedeği - ${format.displayName} formatında',
        subject: 'Rehber Yedeği (${format.displayName})',
      );

      debugPrint('WhatsApp paylaşım sonucu: ${result.status}');
    } catch (e) {
      debugPrint('WhatsApp ile paylaşım hatası: $e');
      throw Exception('WhatsApp ile paylaşılamadı: $e');
    }
  }

  // Dosyayı açma
  Future<OpenResult> openFile(String filePath) async {
    final file = File(filePath);
    if (!(await file.exists())) {
      throw Exception('Dosya bulunamadı: $filePath');
    }

    return await OpenFile.open(filePath);
  }

  // E-posta ile gönderme
  Future<void> sendEmail(String filePath, String subject, String body,
      List<String> recipients) async {
    try {
      final file = File(filePath);
      if (!(await file.exists())) {
        debugPrint('Dosya bulunamadı: $filePath');
        throw Exception('E-posta için dosya bulunamadı: $filePath');
      }

      // Doğrudan dosyayı paylaş - kopyalama yapma
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: body,
        subject: subject,
      );

      debugPrint('E-posta paylaşım sonucu: ${result.status}');
    } catch (e) {
      debugPrint('E-posta gönderme hatası: $e');
      throw Exception('E-posta gönderilemedi: $e');
    }
  }

  // Google Drive'a gönderme
  Future<void> shareToGoogleDrive(String filePath) async {
    await shareFileDirect(filePath, ContactFormat.values.first);
  }

  // Dropbox'a gönderme
  Future<void> shareToDropbox(String filePath) async {
    await shareFileDirect(filePath, ContactFormat.values.first);
  }

  // iCloud'a gönderme
  Future<void> shareToiCloud(String filePath) async {
    await shareFileDirect(filePath, ContactFormat.values.first);
  }

  // Dosyayı kaydet
  Future<String> saveFile(String sourceFilePath, String filename) async {
    final sourceFile = File(sourceFilePath);
    if (!(await sourceFile.exists())) {
      throw Exception('Kaynak dosya bulunamadı: $sourceFilePath');
    }

    // Uygulama dışı depolama dizinini al
    final directory = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final savedFile = File('${directory.path}/$filename');

    // Dosyayı kopyala
    await sourceFile.copy(savedFile.path);
    return savedFile.path;
  }

  // Geçici dosyayı sil
  Future<void> deleteTemporaryFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Geçici dosya silindi: $filePath');
      }
    } catch (e) {
      debugPrint('Geçici dosya silme hatası: $e');
    }
  }

  // Herhangi bir bulut hizmeti ile paylaşmak için genel metod
  Future<void> shareWithCloudService(
      String filePath, String serviceName) async {
    try {
      await shareFileDirect(filePath, ContactFormat.values.first);
    } catch (e) {
      debugPrint('$serviceName paylaşım hatası: $e');
      throw Exception('$serviceName ile paylaşılamadı: $e');
    }
  }
}
