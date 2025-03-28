import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/contact_format.dart';

class ContactsManager {
  // Simülatör/emülatör tespiti için değişken
  bool? _isSimulator;

  // Cihazın simülatör/emülatör olup olmadığını tespit et
  Future<bool> _isRunningOnSimulator() async {
    if (_isSimulator != null) return _isSimulator!;

    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _isSimulator = !iosInfo.isPhysicalDevice;
        debugPrint('iOS cihaz: ${iosInfo.name}, Simülatör: $_isSimulator');
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _isSimulator = !androidInfo.isPhysicalDevice;
        debugPrint(
            'Android cihaz: ${androidInfo.model}, Emülatör: $_isSimulator');
      } else {
        _isSimulator = false;
      }
    } catch (e) {
      debugPrint('Cihaz bilgisi alınamadı: $e');
      _isSimulator = false;
    }

    return _isSimulator!;
  }

  // Önbelleğe alınmış kişiler
  List<Contact>? _cachedContacts;
  DateTime? _lastFetchTime;

  // Performans için önbellek süresini tanımla (saniye cinsinden)
  final int _cacheExpirationSeconds = 300; // 5 dakika (daha uzun süre)

  // Kişilerin yüklenme durumu
  bool _isLoadingContacts = false;
  Completer<List<Contact>>? _contactsCompleter;

  // Önbelleği temizle
  void clearCache() {
    _cachedContacts = null;
    _lastFetchTime = null;
    _contactsCompleter = null;
    debugPrint('Kişi önbelleği temizlendi');
  }

  // Kişiler iznini iste ve durumunu kontrol et
  Future<PermissionStatus> requestContactPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Masaüstü veya web platformlarında izin kontrolü gerekmez
      return PermissionStatus.granted;
    }

    // Mevcut izin durumunu kontrol et
    final permissionStatus = await Permission.contacts.status;
    debugPrint('Rehber izin durumu: $permissionStatus');

    // İzin henüz istenmemişse veya reddedilmişse iste
    if (permissionStatus == PermissionStatus.denied) {
      final requestStatus = await Permission.contacts.request();
      debugPrint('Rehber izni istendi, yeni durum: $requestStatus');
      return requestStatus;
    }

    // Kalıcı olarak reddedildiyse, bunu bildir
    if (permissionStatus == PermissionStatus.permanentlyDenied) {
      debugPrint(
          'Rehber izni kalıcı olarak reddedildi. Ayarlardan manuel olarak verilebilir.');
    }

    return permissionStatus;
  }

  // Tüm kişileri getir
  Future<List<Contact>> getAllContacts() async {
    // İzin kontrolü
    final permission = await requestContactPermission();
    if (permission != PermissionStatus.granted) {
      debugPrint('Rehber izni yok, boş liste döndürülüyor');
      return [];
    }

    // Önbellek kontrolü - eğer yakın zamanda kişiler alındıysa ve önbellekte varsa
    final now = DateTime.now();
    if (_cachedContacts != null && _lastFetchTime != null) {
      final difference = now.difference(_lastFetchTime!).inSeconds;
      if (difference < _cacheExpirationSeconds) {
        debugPrint(
            'Önbellekten ${_cachedContacts!.length} kişi alındı (${difference}s)');
        return _cachedContacts!;
      }
    }

    // Eğer zaten yükleme devam ediyorsa, aynı Future'ı döndür
    if (_isLoadingContacts && _contactsCompleter != null) {
      debugPrint('Kişiler zaten yükleniyor, mevcut işlem bekleniyor');
      return _contactsCompleter!.future;
    }

    // Yeni bir yükleme işlemi başlat
    _isLoadingContacts = true;
    _contactsCompleter = Completer<List<Contact>>();

    // Arka planda kişileri yükle
    _loadContactsInBackground().then((contacts) {
      // Önbelleğe kaydet
      _cachedContacts = contacts;
      _lastFetchTime = now;

      // Completer'ı tamamla
      if (!_contactsCompleter!.isCompleted) {
        _contactsCompleter!.complete(contacts);
      }

      _isLoadingContacts = false;
      debugPrint('${contacts.length} kişi yüklendi ve önbelleğe alındı');
    }).catchError((error) {
      debugPrint('Kişiler yüklenirken hata: $error');
      if (!_contactsCompleter!.isCompleted) {
        _contactsCompleter!.completeError(error);
      }
      _isLoadingContacts = false;
    });

    return _contactsCompleter!.future;
  }

  // Kişileri arka planda yükle
  Future<List<Contact>> _loadContactsInBackground() async {
    try {
      // Paralel işlem için compute kullanılabilir, ancak şimdilik direkt yükleyelim
      debugPrint('Kişiler yükleniyor...');
      final stopwatch = Stopwatch()..start();

      // Tüm kişileri yükle (thumbnail ve fotoğraflar dahil)
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: true,
        withPhoto:
            false, // Fotoğrafları daha sonra talep edildiğinde yükleyeceğiz (performans için)
        withAccounts: true, // Android üzerinde raw ID'leri almak için ekledik
        sorted: true,
      );

      stopwatch.stop();
      debugPrint('Kişiler ${stopwatch.elapsedMilliseconds}ms içinde yüklendi');
      return contacts;
    } catch (e) {
      debugPrint('Kişiler yüklenirken hata: $e');
      rethrow;
    }
  }

  // Tüm kişileri formata göre dışa aktar
  Future<String> exportContacts(
    ContactFormat format, {
    int? limitContacts,
    Set<String>? selectedContactIds,
    bool includeContactsWithoutNumber = true,
    bool includeNumbersWithoutName = true,
  }) async {
    // Uzun işlem öncesi izin kontrolü
    final permission = await requestContactPermission();
    if (permission != PermissionStatus.granted) {
      throw Exception('Rehber izni verilmedi');
    }

    debugPrint(
        'Kişileri ${format.displayName} formatında dışa aktarma başlıyor...');

    // Kişileri al
    final allContacts = await getAllContacts();
    if (allContacts.isEmpty) {
      throw Exception('Dışa aktarılacak kişi yok veya kişilere erişilemedi');
    }

    // Filtreleme seçeneklerini uygula
    List<Contact> filteredContacts = allContacts;

    // Numarası olmayan kişileri filtrele
    if (!includeContactsWithoutNumber) {
      filteredContacts = filteredContacts
          .where((contact) => contact.phones.isNotEmpty)
          .toList();
      debugPrint(
          'Numarası olmayan kişiler filtrelendi: ${allContacts.length} -> ${filteredContacts.length}');
    }

    // İsmi olmayan numaraları filtrele
    if (!includeNumbersWithoutName) {
      filteredContacts = filteredContacts
          .where((contact) =>
              contact.name.first.isNotEmpty || contact.name.last.isNotEmpty)
          .toList();
      debugPrint(
          'İsmi olmayan numaralar filtrelendi: ${allContacts.length} -> ${filteredContacts.length}');
    }

    // Seçili kişileri filtrele
    if (selectedContactIds != null && selectedContactIds.isNotEmpty) {
      filteredContacts = filteredContacts
          .where((contact) => selectedContactIds.contains(contact.id))
          .toList();
      debugPrint(
          'Seçili kişiler filtrelendi: ${allContacts.length} -> ${filteredContacts.length}');
    }

    // Eğer limitContacts belirtilmişse ve seçili kişiler yoksa, kişi sayısını sınırla
    List<Contact> contacts = filteredContacts;
    if (limitContacts != null &&
        selectedContactIds == null &&
        contacts.length > limitContacts) {
      contacts = contacts.sublist(0, limitContacts);
      debugPrint(
          'Kişi sayısı sınırlandırıldı: ${filteredContacts.length} -> $limitContacts');
    }

    // Tarih formatını oluştur: yyyyMMdd
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());

    // Dosya adını tarih ve kişi sayısı ile oluştur
    final contactCount = contacts.length;
    final fileNamePrefix = 'contacts_${dateStr}_${contactCount}kisi';

    // Format işlemine göre dosya oluştur
    String filePath;
    switch (format) {
      case ContactFormat.vCard:
        filePath =
            await _exportAsVCard(contacts, fileNamePrefix: fileNamePrefix);
        break;
      case ContactFormat.csv:
        filePath = await _exportAsCSV(contacts, fileNamePrefix: fileNamePrefix);
        break;
      case ContactFormat.excel:
        filePath =
            await _exportAsExcel(contacts, fileNamePrefix: fileNamePrefix);
        break;
      case ContactFormat.pdf:
        filePath = await _exportAsPDF(contacts, fileNamePrefix: fileNamePrefix);
        break;
      case ContactFormat.json:
        filePath =
            await _exportAsJSON(contacts, fileNamePrefix: fileNamePrefix);
        break;
    }

    debugPrint('Kişiler başarıyla dışa aktarıldı: $filePath');
    return filePath;
  }

  // vCard formatında dışa aktar
  Future<String> _exportAsVCard(List<Contact> contacts,
      {String? fileNamePrefix}) async {
    // Zamanlayıcı başlat
    final stopwatch = Stopwatch()..start();

    // Toplam kişi sayısı
    final totalContacts = contacts.length;

    try {
      // Geçici dizine erişimi kontrol et ve dizini oluştur
      final directory = await getTemporaryDirectory();
      final fileName =
          fileNamePrefix ?? 'contacts_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = '${directory.path}/${fileName}.vcf';
      final file = File(filePath);

      // Log ekleyelim
      debugPrint('vCard yaratılıyor: $filePath');

      // Önce mevcut ise silelim
      if (await file.exists()) {
        await file.delete();
        debugPrint('Önceki dosya silindi: $filePath');
      }

      // Dosya yolu doğrulaması
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
        debugPrint('Dizin oluşturuldu: ${parent.path}');
      }

      // Dosyaya yazma işlemi için StringBuffer kullan
      final buffer = StringBuffer();
      for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];

        // Her 50 kişide bir ilerleme güncellemesi
        if (i % 50 == 0) {
          debugPrint('vCard oluşturuluyor: ${i + 1}/$totalContacts');
        }

        // Flutter_contacts paketi ile vCard oluşturma
        final vcardData = await contact.toVCard();
        buffer.write(vcardData);
      }

      // Dosyaya yaz
      await file.writeAsString(buffer.toString());

      // Dosya varlığını doğrula
      if (!await file.exists()) {
        throw Exception('Dosya oluşturuldu ancak bulunamadı: $filePath');
      }

      // İşlem süresini ölç
      stopwatch.stop();
      debugPrint(
          'vCard oluşturma tamamlandı. Süre: ${stopwatch.elapsedMilliseconds}ms');

      return filePath;
    } catch (e) {
      stopwatch.stop();
      debugPrint('vCard oluşturma hatası: $e');
      rethrow;
    }
  }

  // CSV formatında dışa aktar (daha verimli uygulama)
  Future<String> _exportAsCSV(List<Contact> contacts,
      {String? fileNamePrefix}) async {
    final stopwatch = Stopwatch()..start();
    final totalContacts = contacts.length;

    try {
      // Geçici dizine erişimi kontrol et ve dizini oluştur
      final directory = await getTemporaryDirectory();
      final fileName =
          fileNamePrefix ?? 'contacts_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = '${directory.path}/${fileName}.csv';
      final file = File(filePath);

      // Log ekleyelim
      debugPrint('CSV yaratılıyor: $filePath');

      // Önce mevcut ise silelim
      if (await file.exists()) {
        await file.delete();
        debugPrint('Önceki dosya silindi: $filePath');
      }

      // Dosya yolu doğrulaması
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
        debugPrint('Dizin oluşturuldu: ${parent.path}');
      }

      // CSV başlık satırını hazırla
      final List<List<dynamic>> csvData = [
        [
          'Ad',
          'Soyad',
          'Telefon Numaraları',
          'E-posta Adresleri',
          'Şirket',
          'Adres'
        ]
      ];

      // Daha verimli döngü ile veriyi hazırla
      debugPrint('CSV verisi hazırlanıyor...');
      for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];

        // Her 50 kişide bir ilerleme güncellemesi
        if (i % 50 == 0) {
          debugPrint('CSV işleniyor: ${i + 1}/$totalContacts');
        }

        // Telefon numaralarını birleştir
        final phoneNumbers = contact.phones.map((p) => p.number).join(', ');

        // E-posta adreslerini birleştir
        final emails = contact.emails.map((e) => e.address).join(', ');

        // Adresleri birleştir (flutter_contacts kütüphanesinde region ve postcode yok)
        final addresses = contact.addresses
            .map((a) => '${a.street}, ${a.city}, ${a.country}')
            .join('; ');

        csvData.add([
          contact.name.first,
          contact.name.last,
          phoneNumbers,
          emails,
          contact.organizations.isNotEmpty
              ? contact.organizations.first.company
              : '',
          addresses
        ]);
      }

      // CSV'ye dönüştür
      final csv = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csv);

      // Dosya varlığını doğrula
      if (!await file.exists()) {
        throw Exception('Dosya oluşturuldu ancak bulunamadı: $filePath');
      }

      stopwatch.stop();
      debugPrint(
          'CSV oluşturma tamamlandı. Süre: ${stopwatch.elapsedMilliseconds}ms');

      return filePath;
    } catch (e) {
      stopwatch.stop();
      debugPrint('CSV oluşturma hatası: $e');
      rethrow;
    }
  }

  // Excel formatında dışa aktar (daha hızlı uygulama)
  Future<String> _exportAsExcel(List<Contact> contacts,
      {String? fileNamePrefix}) async {
    final stopwatch = Stopwatch()..start();
    final totalContacts = contacts.length;

    try {
      // Geçici dizine erişimi kontrol et ve dizini oluştur
      final directory = await getTemporaryDirectory();
      final fileName =
          fileNamePrefix ?? 'contacts_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = '${directory.path}/${fileName}.xlsx';
      final file = File(filePath);

      // Log ekleyelim
      debugPrint('Excel yaratılıyor: $filePath');

      // Önce mevcut ise silelim
      if (await file.exists()) {
        await file.delete();
        debugPrint('Önceki dosya silindi: $filePath');
      }

      // Dosya yolu doğrulaması
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
        debugPrint('Dizin oluşturuldu: ${parent.path}');
      }

      final excel = Excel.createExcel();
      final sheet = excel['Kişiler'];

      // Başlıkları ekle
      final headers = [
        'Ad',
        'Soyad',
        'Telefon Numaraları',
        'E-posta Adresleri',
        'Şirket',
        'Adres'
      ];

      for (var i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = headers[i];
      }

      // Her kişiyi ekle (daha verimli döngü)
      for (var i = 0; i < contacts.length; i++) {
        final contact = contacts[i];

        // Her 50 kişide bir ilerleme güncellemesi
        if (i % 50 == 0) {
          debugPrint('Excel işleniyor: ${i + 1}/$totalContacts');
        }

        final row = i + 1;

        // Ad
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = contact.name.first;

        // Soyad
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = contact.name.last;

        // Telefon numaraları
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = contact.phones.map((p) => p.number).join(', ');

        // E-postalar
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = contact.emails.map((e) => e.address).join(', ');

        // Şirket
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
                .value =
            contact.organizations.isNotEmpty
                ? contact.organizations.first.company
                : '';

        // Adres (flutter_contacts kütüphanesinde region ve postcode yok)
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
                .value =
            contact.addresses
                .map((a) => '${a.street}, ${a.city}, ${a.country}')
                .join('; ');
      }

      // Excel dosyasını kaydet
      final excelData = excel.encode();
      if (excelData == null) {
        throw Exception('Excel verisi oluşturulamadı');
      }

      await file.writeAsBytes(excelData);

      // Dosya varlığını doğrula
      if (!await file.exists()) {
        throw Exception('Dosya oluşturuldu ancak bulunamadı: $filePath');
      }

      stopwatch.stop();
      debugPrint(
          'Excel oluşturma tamamlandı. Süre: ${stopwatch.elapsedMilliseconds}ms');

      return filePath;
    } catch (e) {
      stopwatch.stop();
      debugPrint('Excel oluşturma hatası: $e');
      rethrow;
    }
  }

  // PDF formatında dışa aktar (daha verimli uygulama)
  Future<String> _exportAsPDF(List<Contact> contacts,
      {String? fileNamePrefix}) async {
    final stopwatch = Stopwatch()..start();
    final totalContacts = contacts.length;

    try {
      // Geçici dizine erişimi kontrol et ve dizini oluştur
      final directory = await getTemporaryDirectory();
      final fileName =
          fileNamePrefix ?? 'contacts_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = '${directory.path}/${fileName}.pdf';
      final file = File(filePath);

      // Log ekleyelim
      debugPrint('PDF yaratılıyor: $filePath');

      // Önce mevcut ise silelim
      if (await file.exists()) {
        await file.delete();
        debugPrint('Önceki dosya silindi: $filePath');
      }

      // Dosya yolu doğrulaması
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
        debugPrint('Dizin oluşturuldu: ${parent.path}');
      }

      final pdf = pw.Document();

      debugPrint('PDF oluşturuluyor...');

      // Bellek tüketimini azaltmak için sayfaları ayrı ayrı oluştur
      const int contactsPerPage = 30;
      int totalPages = (contacts.length / contactsPerPage).ceil();

      for (var pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        // Her sayfanın başında ilerleme güncellemesi
        debugPrint('PDF sayfa oluşturuluyor: ${pageIndex + 1}/$totalPages');

        final startIndex = pageIndex * contactsPerPage;
        final endIndex = (pageIndex + 1) * contactsPerPage;
        final pageContacts = contacts.sublist(startIndex,
            endIndex > contacts.length ? contacts.length : endIndex);

        // PDF'e sayfa ekle
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Kişiler Listesi',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                      'Toplam ${contacts.length} kişi | Sayfa: ${pageIndex + 1}/$totalPages'),
                  pw.SizedBox(height: 15),
                  pw.Expanded(
                    child: pw.Table.fromTextArray(
                      headers: ['Ad', 'Soyad', 'Telefon', 'E-posta'],
                      data: pageContacts.map((contact) {
                        return [
                          contact.name.first,
                          contact.name.last,
                          contact.phones.isNotEmpty
                              ? contact.phones.first.number
                              : '',
                          contact.emails.isNotEmpty
                              ? contact.emails.first.address
                              : '',
                        ];
                      }).toList(),
                      cellAlignment: pw.Alignment.centerLeft,
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 10),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                            'Oluşturma tarihi: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
                        pw.Text('Sayfa ${pageIndex + 1}/$totalPages'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      // PDF dosyasını kaydet
      final pdfData = await pdf.save();
      await file.writeAsBytes(pdfData);

      // Dosya varlığını doğrula
      if (!await file.exists()) {
        throw Exception('Dosya oluşturuldu ancak bulunamadı: $filePath');
      }

      stopwatch.stop();
      debugPrint(
          'PDF oluşturma tamamlandı. Süre: ${stopwatch.elapsedMilliseconds}ms');

      return filePath;
    } catch (e) {
      stopwatch.stop();
      debugPrint('PDF oluşturma hatası: $e');
      rethrow;
    }
  }

  // JSON formatında dışa aktar (daha verimli uygulama)
  Future<String> _exportAsJSON(List<Contact> contacts,
      {String? fileNamePrefix}) async {
    final stopwatch = Stopwatch()..start();
    final totalContacts = contacts.length;

    try {
      // Geçici dizine erişimi kontrol et ve dizini oluştur
      final directory = await getTemporaryDirectory();
      final fileName =
          fileNamePrefix ?? 'contacts_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = '${directory.path}/${fileName}.json';
      final file = File(filePath);

      // Log ekleyelim
      debugPrint('JSON yaratılıyor: $filePath');

      // Önce mevcut ise silelim
      if (await file.exists()) {
        await file.delete();
        debugPrint('Önceki dosya silindi: $filePath');
      }

      // Dosya yolu doğrulaması
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
        debugPrint('Dizin oluşturuldu: ${parent.path}');
      }

      final List<Map<String, dynamic>> jsonContacts = [];

      debugPrint('JSON verisi oluşturuluyor...');

      // JSON verilerini oluştur
      for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];

        // Her 50 kişide bir ilerleme güncellemesi
        if (i % 50 == 0) {
          debugPrint('JSON işleniyor: ${i + 1}/$totalContacts');
        }

        final contactMap = {
          'id': contact.id,
          'displayName': contact.displayName,
          'name': {
            'first': contact.name.first,
            'last': contact.name.last,
            'middle': contact.name.middle,
            'prefix': contact.name.prefix,
            'suffix': contact.name.suffix,
          },
          'phones': contact.phones
              .map((phone) => {
                    'number': phone.number,
                    'label': phone.label.toString(),
                  })
              .toList(),
          'emails': contact.emails
              .map((email) => {
                    'address': email.address,
                    'label': email.label.toString(),
                  })
              .toList(),
          'organizations': contact.organizations
              .map((org) => {
                    'company': org.company,
                    'title': org.title,
                  })
              .toList(),
          'addresses': contact.addresses
              .map((addr) => {
                    'street': addr.street,
                    'city': addr.city,
                    'country': addr.country,
                    'label': addr.label.toString(),
                  })
              .toList(),
        };

        jsonContacts.add(contactMap);
      }

      // JSON'a dönüştür ve dosyaya yaz
      final jsonData = jsonEncode({
        'contacts': jsonContacts,
        'count': jsonContacts.length,
        'exportDate': DateTime.now().toIso8601String(),
      });

      await file.writeAsString(jsonData);

      // Dosya varlığını doğrula
      if (!await file.exists()) {
        throw Exception('Dosya oluşturuldu ancak bulunamadı: $filePath');
      }

      stopwatch.stop();
      debugPrint(
          'JSON oluşturma tamamlandı. Süre: ${stopwatch.elapsedMilliseconds}ms');

      return filePath;
    } catch (e) {
      stopwatch.stop();
      debugPrint('JSON oluşturma hatası: $e');
      rethrow;
    }
  }

  // vCard'dan kişileri içe aktar
  Future<int> importContactsFromVCard(String filePath) async {
    final permission = await requestContactPermission();
    if (permission != PermissionStatus.granted) {
      throw Exception('Rehber izni verilmedi');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Dosya bulunamadı: $filePath');
    }

    final content = await file.readAsString();

    // vCard ayrıştırma işlemi
    final vcards = content.split('BEGIN:VCARD');
    int importedCount = 0;

    for (var i = 1; i < vcards.length; i++) {
      // Geçerli bir vCard oluştur
      final vcard = 'BEGIN:VCARD${vcards[i]}';

      try {
        // Kişiyi oluştur
        final newContact = await Contact.fromVCard(vcard);

        // Kişiyi telefona kaydet
        await newContact.insert();
        importedCount++;
      } catch (e) {
        // Hata durumunda devam et
        debugPrint('vCard içe aktarma hatası: $e');
      }
    }

    // Önbelleği temizle (yeni kişiler eklendiği için)
    _cachedContacts = null;

    return importedCount;
  }

  // vCard dosyasındaki kişi sayısını analiz et
  Future<int> analyzeVCardContacts(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Dosya bulunamadı: $filePath');
      }

      final content = await file.readAsString();

      // vCard ayrıştırma işlemi (BEGIN:VCARD sayısına göre)
      final vcards = content.split('BEGIN:VCARD');

      // İlk eleman boş olabilir, bu yüzden 1'den büyük olanları sayarız
      int contactCount = vcards.where((card) => card.trim().isNotEmpty).length;

      debugPrint('vCard dosyasında $contactCount kişi bulundu: $filePath');
      return contactCount;
    } catch (e) {
      debugPrint('vCard analiz hatası: $e');
      return 0;
    }
  }

  // Tekrarlanan telefon numaralarını bul
  Future<List<List<dynamic>>> getDuplicateNumbers() async {
    try {
      final contacts = await getAllContacts();

      // Telefon numaralarına göre gruplandır
      Map<String, List<Contact>> numberGroups = {};

      for (final contact in contacts) {
        for (final phone in contact.phones) {
          // Numarayı normalleştir (sadece rakamları al)
          final normalizedNumber = phone.number.replaceAll(RegExp(r'\D'), '');
          if (normalizedNumber.isNotEmpty) {
            if (!numberGroups.containsKey(normalizedNumber)) {
              numberGroups[normalizedNumber] = [];
            }
            numberGroups[normalizedNumber]!.add(contact);
          }
        }
      }

      // Birden fazla kişiye ait olan numaraları bul
      List<List<Contact>> duplicateNumbers = [];
      numberGroups.forEach((number, contactList) {
        if (contactList.length > 1) {
          duplicateNumbers.add(contactList);
        }
      });

      return duplicateNumbers;
    } catch (e) {
      debugPrint('Tekrarlanan numaralar bulunurken hata: $e');
      return [];
    }
  }

  // Tekrarlanan isimleri bul
  Future<List<List<dynamic>>> getDuplicateNames() async {
    try {
      final contacts = await getAllContacts();

      // İsimlere göre gruplandır
      Map<String, List<Contact>> nameGroups = {};

      for (final contact in contacts) {
        final fullName =
            '${contact.name.first} ${contact.name.last}'.trim().toLowerCase();
        if (fullName.isNotEmpty) {
          if (!nameGroups.containsKey(fullName)) {
            nameGroups[fullName] = [];
          }
          nameGroups[fullName]!.add(contact);
        }
      }

      // Birden fazla kişiye ait olan isimleri bul
      List<List<Contact>> duplicateNames = [];
      nameGroups.forEach((name, contactList) {
        if (contactList.length > 1) {
          duplicateNames.add(contactList);
        }
      });

      return duplicateNames;
    } catch (e) {
      debugPrint('Tekrarlanan isimler bulunurken hata: $e');
      return [];
    }
  }

  // Tekrarlanan e-postaları bul
  Future<List<List<dynamic>>> getDuplicateEmails() async {
    try {
      final contacts = await getAllContacts();

      // E-postalara göre gruplandır
      Map<String, List<Contact>> emailGroups = {};

      for (final contact in contacts) {
        for (final email in contact.emails) {
          final normalizedEmail = email.address.trim().toLowerCase();
          if (normalizedEmail.isNotEmpty) {
            if (!emailGroups.containsKey(normalizedEmail)) {
              emailGroups[normalizedEmail] = [];
            }
            emailGroups[normalizedEmail]!.add(contact);
          }
        }
      }

      // Birden fazla kişiye ait olan e-postaları bul
      List<List<Contact>> duplicateEmails = [];
      emailGroups.forEach((email, contactList) {
        if (contactList.length > 1) {
          duplicateEmails.add(contactList);
        }
      });

      return duplicateEmails;
    } catch (e) {
      debugPrint('Tekrarlanan e-postalar bulunurken hata: $e');
      return [];
    }
  }

  // Eksik bilgiye sahip kişileri bul
  Future<List<Contact>> getMissingInfoContacts() async {
    try {
      final contacts = await getAllContacts();

      // Eksik bilgiye sahip kişileri filtrele
      final missingInfoContacts = contacts.where((contact) {
        // İsim eksikliği
        final hasMissingName =
            contact.name.first.isEmpty && contact.name.last.isEmpty;

        // Telefon eksikliği
        final hasMissingPhone = contact.phones.isEmpty;

        // E-posta eksikliği
        final hasMissingEmail = contact.emails.isEmpty;

        // En az bir eksik bilgisi olan kişileri dahil et
        return hasMissingName || hasMissingPhone || hasMissingEmail;
      }).toList();

      debugPrint('${missingInfoContacts.length} eksik bilgili kişi bulundu');
      return missingInfoContacts;
    } catch (e) {
      debugPrint('Eksik bilgiye sahip kişiler bulunurken hata: $e');
      return [];
    }
  }

  // Kişi detaylarını aç
  void openContact(String contactId) {
    try {
      FlutterContacts.openExternalView(contactId);
    } catch (e) {
      debugPrint('Kişi açılırken hata: $e');
      throw Exception('Kişi açılamadı: $e');
    }
  }

  // Tekrarlanan kişileri birleştirme
  Future<bool> mergeContacts(List<Contact> contacts,
      {Contact? primaryContact}) async {
    try {
      if (contacts.length < 2) {
        throw Exception('Birleştirmek için en az 2 kişi gereklidir');
      }

      // Ana kişi belirtilmemişse, listedeki ilk kişiyi ana kişi olarak seç
      Contact main = primaryContact ?? contacts.first;

      // Ana kişi dışındaki kişileri al (birleştirilecek kişiler)
      List<Contact> othersToMerge =
          contacts.where((c) => c.id != main.id).toList();

      // Ana kişiyi değiştirmek için tam bilgilerini yükle (withAccounts: true ekledik)
      Contact? contactDetails = await FlutterContacts.getContact(main.id,
          withProperties: true, withAccounts: true);
      if (contactDetails == null) {
        throw Exception('Ana kişi bulunamadı');
      }
      Contact mergedContact = contactDetails;

      // Değiştirilebilir kopyasını oluştur
      final mutableContact = mergedContact.toJson();

      // Diğer kişilerdeki bilgileri ana kişiye ekle
      for (var other in othersToMerge) {
        // Tam bilgileri yükle (withAccounts: true ekledik)
        Contact? otherDetails = await FlutterContacts.getContact(other.id,
            withProperties: true, withAccounts: true);
        if (otherDetails == null) {
          debugPrint(
              '${other.displayName} için detaylar yüklenemedi, atlanıyor');
          continue;
        }
        Contact otherFull = otherDetails;

        // Telefon numaralarını ekle (tekrar olmayan)
        for (var phone in otherFull.phones) {
          // Numarayı normalleştir (sadece rakamları al)
          final normalizedNumber = phone.number.replaceAll(RegExp(r'\D'), '');

          // Ana kişide bu numara yoksa ekle
          if (!mergedContact.phones.any((p) =>
              p.number.replaceAll(RegExp(r'\D'), '') == normalizedNumber)) {
            // PhoneLabel tipini String'e dönüştür
            String labelStr;
            if (phone.label == null) {
              labelStr = 'mobile'; // Varsayılan değer
            } else {
              try {
                labelStr = phone.label.toString();
                // "PhoneLabel.mobile" formatından sadece "mobile" kısmını al
                if (labelStr.contains('.')) {
                  labelStr = labelStr.split('.').last;
                }
              } catch (e) {
                labelStr = 'mobile';
                debugPrint('Phone label dönüştürme hatası: $e');
              }
            }

            mutableContact['phones'].add({
              'number': phone.number,
              'normalizedNumber': normalizedNumber,
              'label': labelStr,
              'customLabel': phone.customLabel
            });
          }
        }

        // E-posta adreslerini ekle (tekrar olmayan)
        for (var email in otherFull.emails) {
          final normalizedEmail = email.address.trim().toLowerCase();

          // Ana kişide bu email yoksa ekle
          if (!mergedContact.emails
              .any((e) => e.address.trim().toLowerCase() == normalizedEmail)) {
            // EmailLabel tipinin String'e dönüştürülememesi sorununu çözmek için
            // label değerini güvenli şekilde String'e dönüştürelim
            String labelStr;
            if (email.label == null) {
              labelStr = 'home'; // Varsayılan değer
            } else {
              try {
                labelStr = email.label.toString();
                // toString() metodu "EmailLabel.home" gibi bir değer döndürür
                // Sadece "home" kısmını almak için
                if (labelStr.contains('.')) {
                  labelStr = labelStr.split('.').last;
                }
              } catch (e) {
                // Dönüştürme hatası durumunda varsayılan değer kullan
                labelStr = 'home';
                debugPrint('Email label dönüştürme hatası: $e');
              }
            }

            mutableContact['emails'].add({
              'address': email.address,
              'label': labelStr,
              'customLabel': email.customLabel
            });
          }
        }

        // Adresleri ekle (tekrar olmayan)
        for (var address in otherFull.addresses) {
          final addressString =
              '${address.street},${address.city},${address.country}'
                  .toLowerCase();

          // Ana kişide benzer adres yoksa ekle
          if (!mergedContact.addresses.any((a) =>
              '${a.street},${a.city},${a.country}'.toLowerCase() ==
              addressString)) {
            // AddressLabel tipini String'e dönüştür
            String labelStr;
            if (address.label == null) {
              labelStr = 'home'; // Varsayılan değer
            } else {
              try {
                labelStr = address.label.toString();
                // "AddressLabel.home" formatından sadece "home" kısmını al
                if (labelStr.contains('.')) {
                  labelStr = labelStr.split('.').last;
                }
              } catch (e) {
                labelStr = 'home';
                debugPrint('Address label dönüştürme hatası: $e');
              }
            }

            mutableContact['addresses'].add({
              'address': address.address,
              'street': address.street,
              'city': address.city,
              'state': address.state,
              'postalCode': address.postalCode,
              'country': address.country,
              'label': labelStr,
              'customLabel': address.customLabel
            });
          }
        }

        // Not bilgisini birleştir
        String otherNotes = "";
        if (otherFull.notes.isNotEmpty) {
          otherNotes = otherFull.notes.first.note;
        }

        String mainNotes = "";
        if (mergedContact.notes.isNotEmpty) {
          mainNotes = mergedContact.notes.first.note;
        }

        if (otherNotes.isNotEmpty && otherNotes != mainNotes) {
          String combinedNotes = mainNotes;

          if (combinedNotes.isNotEmpty) {
            combinedNotes += '\n\n';
          }

          combinedNotes += '(Birleştirilmiş kişiden not): ${otherNotes}';

          if (mutableContact['notes'] == null ||
              mutableContact['notes'].isEmpty) {
            mutableContact['notes'] = [
              {'note': combinedNotes}
            ];
          } else {
            mutableContact['notes'][0]['note'] = combinedNotes;
          }
        }

        // Şirket bilgisini ekle (eğer ana kişide yoksa)
        if (mergedContact.organizations.isEmpty &&
            otherFull.organizations.isNotEmpty) {
          for (var org in otherFull.organizations) {
            mutableContact['organizations'].add({
              'company': org.company,
              'title': org.title,
              'department': org.department
            });
          }
        }

        // Doğum günü bilgisini ekle (eğer ana kişide yoksa)
        if (mergedContact.events.isEmpty && otherFull.events.isNotEmpty) {
          for (var event in otherFull.events) {
            // EventLabel tipini String'e dönüştür
            String labelStr;
            if (event.label == null) {
              labelStr = 'birthday'; // Varsayılan değer
            } else {
              try {
                labelStr = event.label.toString();
                // "EventLabel.birthday" formatından sadece "birthday" kısmını al
                if (labelStr.contains('.')) {
                  labelStr = labelStr.split('.').last;
                }
              } catch (e) {
                labelStr = 'birthday';
                debugPrint('Event label dönüştürme hatası: $e');
              }
            }

            mutableContact['events'].add({
              'year': event.year,
              'month': event.month,
              'day': event.day,
              'label': labelStr,
              'customLabel': event.customLabel
            });
          }
        }
      }

      // Değiştirilmiş kişiyi yükle
      final updatedContact = Contact.fromJson(mutableContact);

      // Ana kişiyi güncelle
      await updatedContact.update();

      // Diğer kişileri sil
      for (var other in othersToMerge) {
        await other.delete();
      }

      // Önbelleği temizle
      _cachedContacts = null;

      return true;
    } catch (e) {
      debugPrint('Kişileri birleştirirken hata: $e');
      rethrow;
    }
  }
}
