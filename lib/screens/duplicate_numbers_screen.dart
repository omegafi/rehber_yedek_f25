import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/contacts_service.dart';
// Ana ekrandaki provider'ları import et
import '../screens/home_screen.dart'
    show
        contactsCountProvider,
        filteredContactsCountProvider,
        contactsListProvider,
        duplicateContactsProvider,
        duplicateNumbersPhoneProvider,
        duplicateNamesProvider,
        duplicateEmailsProvider,
        includeContactsWithoutNumberProvider,
        includeNumbersWithoutNameProvider;
import '../screens/settings_screen.dart' show refreshContactsCacheProvider;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localizations.dart';

// Tema renkleri için sabit
final appPrimaryColor = Color(0xFF4285F4); // Ana Google mavisi

// Provider tanımları
final duplicateNumbersProvider =
    FutureProvider<List<List<dynamic>>>((ref) async {
  final contactsManager = ContactsManager();
  // Önce kişilerin önbelleğini temizleyelim, yeni kişileri doğru parametrelerle almak için
  contactsManager.clearCache();
  return await contactsManager.getDuplicateNumbers();
});

// Birleştirme durumu takibi için provider
final mergingNumbersStateProvider = StateProvider<bool>((ref) => false);

// Ana ekrandan getirilen provider'lar
final contactsCountProvider = FutureProvider<int>((ref) => 0);
final filteredContactsCountProvider = FutureProvider<int>((ref) => 0);
final contactsListProvider = FutureProvider<List<Contact>>((ref) => []);
final duplicateContactsProvider = FutureProvider<List<Contact>>((ref) => []);
final duplicateNumbersPhoneProvider =
    FutureProvider<List<Contact>>((ref) => []);
final includeContactsWithoutNumberProvider = StateProvider<bool>((ref) => true);
final includeNumbersWithoutNameProvider = StateProvider<bool>((ref) => true);

class DuplicateNumbersScreen extends ConsumerStatefulWidget {
  const DuplicateNumbersScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DuplicateNumbersScreen> createState() =>
      _DuplicateNumbersScreenState();
}

class _DuplicateNumbersScreenState
    extends ConsumerState<DuplicateNumbersScreen> {
  Map<String, Contact> selectedContactsMap = {};
  Contact? primaryContact;
  bool isMerging = false;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late AppLocalizations l10n;

  @override
  void initState() {
    super.initState();
    ref.read(duplicateNumbersPhoneProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Tema bilgilerini al
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appPrimaryColor = Theme.of(context).primaryColor;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    // Lokalizasyon erişimi için
    l10n = AppLocalizations.of(context);

    // Tekrar eden numaralar listesini almak için provider'ı kullan
    final duplicateNumbersAsync = ref.watch(duplicateNumbersProvider);

    // Birleştirme işleminin durumunu takip et
    final isMerging = ref.watch(mergingNumbersStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.duplicate_numbers),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        actions: [
          // Yenile butonu
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(duplicateNumbersProvider);
            },
          ),
        ],
      ),
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: isMerging
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(context.l10n.contacts_merging),
                ],
              ),
            )
          : Column(
              children: [
                // Kişi listesi
                Expanded(
                  child: duplicateNumbersAsync.when(
                    data: (duplicateNumbers) {
                      if (duplicateNumbers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 80,
                                color: appPrimaryColor.withOpacity(0.5),
                              ),
                              SizedBox(height: 20),
                              Text(
                                l10n.contact_not_found,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: textColor.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Tekrar eden numaraları gruplandır
                      Map<String, List<Contact>> groupedContacts = {};

                      for (var contactGroup in duplicateNumbers) {
                        final contacts = contactGroup as List<Contact>;
                        if (contacts.isNotEmpty &&
                            contacts.first.phones.isNotEmpty) {
                          String phoneNumber =
                              contacts.first.phones.first.number;
                          groupedContacts[phoneNumber] = contacts;
                        }
                      }

                      return ListView.builder(
                        padding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        itemCount: groupedContacts.length,
                        itemBuilder: (context, index) {
                          String phoneNumber =
                              groupedContacts.keys.elementAt(index);
                          List<Contact> contacts =
                              groupedContacts[phoneNumber]!;

                          return Card(
                            elevation: 0,
                            margin: EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isDarkMode
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            color: Colors.transparent,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          phoneNumber,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      // Tümünü Seç / Kaldır butonu
                                      IconButton(
                                        icon: Icon(
                                          _areAllContactsInGroupSelected(
                                                  contacts)
                                              ? Icons.deselect
                                              : Icons.select_all,
                                          size: 20,
                                          color: appPrimaryColor,
                                        ),
                                        tooltip: _areAllContactsInGroupSelected(
                                                contacts)
                                            ? context.l10n.deselect_all_option
                                            : context.l10n.select_all_option,
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                        onPressed: () {
                                          setState(() {
                                            // Aynı numaraya sahip tüm kişilerin seçili olup olmadığını kontrol et
                                            bool allSelected =
                                                _areAllContactsInGroupSelected(
                                                    contacts);

                                            if (allSelected) {
                                              // Hepsi seçiliyse, tümünü kaldır
                                              for (var contact in contacts) {
                                                selectedContactsMap
                                                    .remove(contact.id);
                                              }
                                            } else {
                                              // Hepsi seçili değilse, tümünü seç
                                              for (var contact in contacts) {
                                                selectedContactsMap[
                                                    contact.id] = contact;
                                              }
                                            }
                                          });
                                        },
                                      ),
                                      SizedBox(width: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: appPrimaryColor,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          context.l10n.x_contacts.replaceAll(
                                              '{count}',
                                              contacts.length.toString()),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Birleştirme butonu - sadece seçim olduğunda göster
                                if (_isAnyContactInGroupSelected(contacts))
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: appPrimaryColor,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 10),
                                            ),
                                            icon: Icon(Icons.merge_type,
                                                size: 18),
                                            label: Text(
                                                l10n.merge_selected_contacts),
                                            onPressed: () =>
                                                _mergeSelectedContacts(
                                                    contacts),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: isDarkMode
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade300,
                                ),

                                // Kişiler listesi
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: contacts.length,
                                  padding: EdgeInsets.only(top: 8, bottom: 8),
                                  itemBuilder: (context, contactIndex) {
                                    final contact = contacts[contactIndex];
                                    final isSelected = selectedContactsMap
                                        .containsKey(contact.id);

                                    return Container(
                                      margin: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isSelected
                                              ? appPrimaryColor
                                              : isDarkMode
                                                  ? Colors.grey.shade800
                                                  : Colors.grey.shade300,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.transparent,
                                      ),
                                      child: ListTile(
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              selectedContactsMap
                                                  .remove(contact.id);
                                            } else {
                                              selectedContactsMap[contact.id] =
                                                  contact;
                                            }
                                          });
                                        },
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 4),
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        leading: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? appPrimaryColor
                                                  : isDarkMode
                                                      ? Colors.grey.shade800
                                                      : Colors.grey.shade300,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            radius: 18,
                                            backgroundColor: isSelected
                                                ? appPrimaryColor
                                                : Colors.transparent,
                                            child: Text(
                                              contact.displayName.isNotEmpty
                                                  ? contact.displayName[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : appPrimaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          contact.displayName,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              contact.phones.isNotEmpty
                                                  ? contact.phones.first.number
                                                  : '',
                                              style: TextStyle(
                                                color:
                                                    textColor.withOpacity(0.6),
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (contact.accounts.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      _getAccountIcon(contact
                                                          .accounts.first.type),
                                                      size: 14,
                                                      color: textColor
                                                          .withOpacity(0.5),
                                                    ),
                                                    SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        _getAccountName(
                                                            contact.accounts
                                                                .first.type,
                                                            contact.accounts
                                                                .first.name),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: textColor
                                                              .withOpacity(0.5),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: Checkbox(
                                          value: isSelected,
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                selectedContactsMap[
                                                    contact.id] = contact;
                                              } else {
                                                selectedContactsMap
                                                    .remove(contact.id);
                                              }
                                            });
                                          },
                                          activeColor: appPrimaryColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stackTrace) => Center(
                      child: Text(
                        'Hata oluştu: $error',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _mergeSelectedContacts(List<Contact> contactsToMerge) async {
    // Birleştirme işlemi sırasında yükleniyor durumunu etkinleştir
    ref.read(mergingNumbersStateProvider.notifier).state = true;

    try {
      // Seçili kişileri al
      List<Contact> selectedContacts = contactsToMerge;

      if (selectedContacts.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.merge_select_min),
            duration: Duration(seconds: 2),
          ),
        );
        ref.read(mergingNumbersStateProvider.notifier).state = false;
        return;
      }

      // İlk sıradaki kişiyi ana kişi olarak belirle
      Contact mainContact = selectedContacts.first;
      primaryContact = mainContact;

      // Birleştirme seçeneklerini göster
      final result = await _showConfirmMergeDialog(mainContact);

      // Eğer kullanıcı iptal ettiyse veya bir kişi seçmediyse, işlemi sonlandır
      if (result != true) {
        _showSnackbar(l10n.merge_canceled);
        ref.read(mergingNumbersStateProvider.notifier).state = false;
        return;
      }

      // Birleştirme işlemini gerçekleştir
      final contactsManager = ContactsManager();
      final resultMerge = await contactsManager.mergeContacts(selectedContacts,
          primaryContact: primaryContact);

      if (resultMerge) {
        // Önce önbelleği temizle
        ContactsManager().clearCache();
        await Future.delayed(Duration(milliseconds: 100));

        // Kişi listesini yenile
        ref.invalidate(contactsListProvider);
        await Future.delayed(Duration(milliseconds: 100));

        // Sayıları yenile
        ref.invalidate(contactsCountProvider);
        ref.invalidate(filteredContactsCountProvider);
        await Future.delayed(Duration(milliseconds: 100));

        // Tekrar eden kişileri yenile
        ref.invalidate(duplicateContactsProvider);
        ref.invalidate(duplicateNumbersProvider);
        ref.invalidate(duplicateNumbersPhoneProvider);
        ref.invalidate(duplicateNamesProvider);
        ref.invalidate(duplicateEmailsProvider);
        await Future.delayed(Duration(milliseconds: 100));

        // Önbellek sayacını artır
        ref.read(refreshContactsCacheProvider.notifier).state++;

        // Başarı mesajını göster
        _showSnackbar(l10n.merge_success);

        // Ana ekrana dönmeden önce kısa bir bekleme
        await Future.delayed(Duration(milliseconds: 300));

        // Ana ekrana dön
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showSnackbar(l10n.merge_error);
      }
    } catch (e) {
      // Daha açıklayıcı hata mesajı gösterelim
      String errorMessage = e.toString();
      if (errorMessage.contains('raw ID')) {
        errorMessage =
            'Android cihazda kişi güncellenirken hata oluştu. Uygulama yeniden başlatılmalı.';
      }

      _showSnackbar(errorMessage);
      debugPrint('Birleştirme hatası: $e');
    } finally {
      // Birleştirme işlemi tamamlandığında yükleniyor durumunu devre dışı bırak
      ref.read(mergingNumbersStateProvider.notifier).state = false;
    }
  }

  Future<bool?> _showConfirmMergeDialog(Contact primaryContact) async {
    // Tema değişkenlerini al
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Color(0xFF222222) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 22,
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.select_primary_contact,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.merge_confirmation_message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 12),
              Text(
                l10n.merge_contact_message
                    .replaceAll('{name}', primaryContact.displayName),
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                l10n.merge_warning,
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Text(
                l10n.merge_cancel_button,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: appPrimaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                l10n.merge_confirm_button,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openContactDetails(String contactId) {
    // Cihaz rehber uygulamasında kişiyi aç
    ContactsManager().openContact(contactId);

    // Kullanıcı rehberden döndüğünde ana ekrana git ve tüm provider'ları yenile
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        // Ana ekrandaki ilgili tüm provider'ları yenile
        ref.invalidate(duplicateNumbersProvider);
        ref.invalidate(contactsCountProvider);
        ref.invalidate(filteredContactsCountProvider);
        ref.invalidate(contactsListProvider);
        ref.invalidate(duplicateContactsProvider);
        ref.invalidate(duplicateNumbersPhoneProvider);
        ref.read(refreshContactsCacheProvider.notifier).state++;

        // Ana ekrana geri dön
        Navigator.of(context).pop();
      }
    });
  }

  void _callContact(String phoneNumber) async {
    // Boşluk, parantez gibi karakterleri temizle
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('tel:$cleanedNumber');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showSnackbar('Arama başlatılamadı');
    }
  }

  void _sendSMSToContact(String phoneNumber) async {
    // Boşluk, parantez gibi karakterleri temizle
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('sms:$cleanedNumber');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showSnackbar('SMS gönderilemedi');
    }
  }

  void _openWhatsApp(String phoneNumber) async {
    // Boşluk, parantez gibi karakterleri temizle
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // WhatsApp URL'si (uluslararası formatta olmalı)
    var formattedNumber = cleanedNumber;
    if (!formattedNumber.startsWith('+')) {
      // Türkiye numarası olarak düşün ve +90 ekle
      if (formattedNumber.startsWith('0')) {
        formattedNumber = '+9${formattedNumber}';
      } else {
        formattedNumber = '+90$formattedNumber';
      }
    }

    final url = Uri.parse('https://wa.me/$formattedNumber');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showSnackbar('WhatsApp açılamadı');
    }
  }

  // Ana sayfadaki provider'ları yenilemek için yardımcı metod
  void _forceRefreshHomeScreenProviders() {
    try {
      // Sadece provider'ları yenile, ekran geçişi yapma
      ref.invalidate(duplicateNumbersProvider);
      ref.invalidate(contactsCountProvider);
      ref.invalidate(filteredContactsCountProvider);
      ref.invalidate(contactsListProvider);
      ref.invalidate(duplicateContactsProvider);
      ref.invalidate(duplicateNumbersPhoneProvider);
      ref.read(refreshContactsCacheProvider.notifier).state++;
    } catch (e) {
      print('Provider yenileme hatası: $e');
    }
  }

  IconData _getAccountIcon(String type) {
    // Bu metod, hesap türüne göre uygun icon seçmek için kullanılabilir.
    // Bazı hesap türleri için uygun ikonlar
    switch (type.toLowerCase()) {
      case 'google':
        return Icons.email; // Google için email ikonu
      case 'icloud':
        return Icons.cloud_outlined; // iCloud için bulut ikonu
      case 'apple':
        return Icons.laptop_mac; // Apple için mac ikonu
      case 'exchange':
        return Icons.business;
      case 'outlook':
        return Icons.mail_outline;
      case 'yahoo':
        return Icons.alternate_email;
      default:
        return Icons.account_circle; // Diğer hesaplar için varsayılan
    }
  }

  String _getAccountName(String type, String name) {
    // Hesap türünün adını ve varsa kullanıcı adını birleştiriyor
    if (name.isNotEmpty) {
      // E-posta adresi mi yoksa paket adı mı kontrol et
      if (name.contains('@')) {
        // E-posta adresi - tür kısmını temizle
        return name.split('(')[0].trim();
      } else {
        // Paket adı - önekleri temizle
        String cleanName = name;

        // com.* veya org.* gibi önekleri kaldır
        if (name.contains('com.')) {
          cleanName = name.replaceAll('com.', '');
        } else if (name.contains('org.')) {
          cleanName = name.replaceAll('org.', '');
        }

        // Özel durumlar için düzeltmeler
        cleanName = cleanName.replaceAll('whatsapp', 'Whatsapp');
        cleanName = cleanName.replaceAll('telegram.messenger', 'Telegram');
        cleanName = cleanName.replaceAll('xiaomi', 'Xiaomi');

        return cleanName;
      }
    }

    // Hesap adı boşsa sadece türünü döndür
    switch (type.toLowerCase()) {
      case 'google':
        return 'Google Hesabı';
      case 'icloud':
        return 'iCloud Hesabı';
      case 'apple':
        return 'Apple Hesabı';
      case 'exchange':
        return 'Exchange Hesabı';
      case 'outlook':
        return 'Outlook Hesabı';
      case 'yahoo':
        return 'Yahoo Hesabı';
      default:
        return 'Yerel Hesap';
    }
  }

  // Grupta en az bir kişinin seçili olup olmadığını kontrol eder
  bool _isAnyContactInGroupSelected(List<Contact> contacts) {
    for (var contact in contacts) {
      if (selectedContactsMap.containsKey(contact.id)) {
        return true;
      }
    }
    return false;
  }

  // Grupta yer alan tüm kişilerin seçilip seçilmediğini kontrol eder
  bool _areAllContactsInGroupSelected(List<Contact> contacts) {
    for (var contact in contacts) {
      if (!selectedContactsMap.containsKey(contact.id)) {
        return false;
      }
    }
    return contacts.isNotEmpty;
  }
}
