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
        duplicateNumbersProvider,
        duplicateNumbersPhoneProvider,
        duplicateNamesProvider,
        duplicateEmailsProvider,
        includeContactsWithoutNumberProvider,
        includeNumbersWithoutNameProvider;
import '../screens/settings_screen.dart' show refreshContactsCacheProvider;
import '../utils/app_localizations.dart';

// Tema renkleri için sabit
final appPrimaryColor = Color(0xFF4285F4); // Ana Google mavisi

// Provider tanımları
final duplicateNamesProvider = FutureProvider<List<List<dynamic>>>((ref) async {
  final contactsManager = ContactsManager();
  // Önce kişilerin önbelleğini temizleyelim, yeni kişileri doğru parametrelerle almak için
  contactsManager.clearCache();
  return await contactsManager.getDuplicateNames();
});

// Birleştirme durumu takibi için provider
final mergingStateProvider = StateProvider<bool>((ref) => false);

class DuplicateNamesScreen extends ConsumerStatefulWidget {
  const DuplicateNamesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DuplicateNamesScreen> createState() =>
      _DuplicateNamesScreenState();
}

class _DuplicateNamesScreenState extends ConsumerState<DuplicateNamesScreen> {
  // Seçili kişilerin ID'lerini depolamak için
  final Map<String, Map<String, bool>> _selectedContacts = {};

  // Lokalizasyon için
  late AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // Tema değişkenleri
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    // Lokalizasyon erişimi için
    l10n = AppLocalizations.of(context);

    // Tekrar eden isimler listesini almak için provider'ı kullan
    final duplicateNamesAsync = ref.watch(duplicateNamesProvider);

    // Birleştirme işleminin durumunu takip et
    final isMerging = ref.watch(mergingStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.duplicate_names),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        actions: [
          // Yenile butonu
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(duplicateNamesProvider);
            },
          ),
        ],
      ),
      backgroundColor: backgroundColor,
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
          : duplicateNamesAsync.when(
              data: (duplicateNames) {
                if (duplicateNames.isEmpty) {
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
                          l10n.no_duplicate_names,
                          style: TextStyle(
                            fontSize: 18,
                            color: textColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Tekrar eden isimleri gruplandır
                Map<String, List<Contact>> groupedContacts = {};

                for (var contactGroup in duplicateNames) {
                  final contacts = contactGroup as List<Contact>;
                  if (contacts.isNotEmpty) {
                    String displayName = contacts.first.displayName;
                    groupedContacts[displayName] = contacts;

                    // Seçili kişiler haritasını başlat
                    if (!_selectedContacts.containsKey(displayName)) {
                      _selectedContacts[displayName] = {};
                      for (var contact in contacts) {
                        _selectedContacts[displayName]![contact.id] = false;
                      }
                    }
                  }
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  itemCount: groupedContacts.length,
                  itemBuilder: (context, index) {
                    String displayName = groupedContacts.keys.elementAt(index);
                    List<Contact> contacts = groupedContacts[displayName]!;

                    // Bu grup için en az bir kişi seçili mi kontrol et
                    bool hasSelection = _selectedContacts[displayName]!
                        .values
                        .any((selected) => selected);

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
                          // Kişi başlığı ve sayısı
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Kişi ikonu
                                Icon(
                                  Icons.person,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  size: 20,
                                ),
                                SizedBox(width: 10),

                                // Kişi ismi
                                Expanded(
                                  child: Text(
                                    displayName,
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
                                // Burada bir IconButton kullanarak daha minimal bir tasarım yapıyoruz
                                IconButton(
                                  icon: Icon(
                                    hasSelection
                                        ? Icons.deselect
                                        : Icons.select_all,
                                    size: 20,
                                    color: appPrimaryColor,
                                  ),
                                  tooltip: hasSelection
                                      ? 'Tümünü Kaldır'
                                      : 'Tümünü Seç',
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      bool newValue = !hasSelection;
                                      for (var id
                                          in _selectedContacts[displayName]!
                                              .keys) {
                                        _selectedContacts[displayName]![id] =
                                            newValue;
                                      }
                                    });
                                  },
                                ),

                                SizedBox(width: 8),

                                // Kişi sayısı
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: appPrimaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${contacts.length} kişi',
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
                          if (hasSelection)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: appPrimaryColor,
                                        foregroundColor: Colors.white,
                                        padding:
                                            EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      icon: Icon(Icons.merge_type, size: 18),
                                      label: Text(l10n.merge_selected_contacts),
                                      onPressed: () => _mergeSelectedContacts(
                                          displayName, contacts),
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
                              final isSelected =
                                  _selectedContacts[displayName]![contact.id] ??
                                      false;

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
                                child: Column(
                                  children: [
                                    // Daha sadeleştirilmiş kişi bilgileri
                                    ListTile(
                                      onTap: () {
                                        setState(() {
                                          _selectedContacts[displayName]![
                                              contact.id] = !isSelected;
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
                                          if (contact.phones.isNotEmpty)
                                            Text(
                                              contact.phones.first.number,
                                              style: TextStyle(
                                                color:
                                                    textColor.withOpacity(0.6),
                                                fontSize: 13,
                                              ),
                                            ),
                                          if (contact.phones.isEmpty)
                                            Text(
                                              'Numara Yok',
                                              style: TextStyle(
                                                color:
                                                    textColor.withOpacity(0.6),
                                                fontSize: 13,
                                              ),
                                            ),
                                          if (contact.accounts.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
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
                                                  Text(
                                                    _getAccountName(
                                                        contact.accounts.first
                                                            .type,
                                                        contact.accounts.first
                                                            .name),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: textColor
                                                          .withOpacity(0.5),
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
                                            _selectedContacts[displayName]![
                                                contact.id] = value!;
                                          });
                                        },
                                        activeColor: appPrimaryColor,
                                      ),
                                    ),
                                  ],
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
    );
  }

  Future<void> _mergeSelectedContacts(
      String displayName, List<Contact> contacts) async {
    // Birleştirme işlemi sırasında yükleniyor durumunu etkinleştir
    ref.read(mergingStateProvider.notifier).state = true;

    try {
      // Seçili kişileri al
      List<Contact> selectedContacts = contacts
          .where(
              (contact) => _selectedContacts[displayName]![contact.id] == true)
          .toList();

      if (selectedContacts.length < 2) {
        _showSnackbar(l10n.merge_select_min);
        return;
      }

      // İlk sıradaki kişiyi ana kişi olarak belirle
      Contact primaryContact = selectedContacts.first;

      // Birleştirme seçeneklerini göster
      final Contact? chosenPrimary =
          await _showMergeOptionsDialog(selectedContacts);

      // Eğer kullanıcı iptal ettiyse veya bir kişi seçmediyse, işlemi sonlandır
      if (chosenPrimary == null) {
        _showSnackbar(l10n.merge_canceled);
        ref.read(mergingStateProvider.notifier).state = false;
        return;
      }

      // Kullanıcının seçtiği kişiyi ana kişi olarak belirle
      primaryContact = chosenPrimary;

      // Onay diyaloğu göster
      final bool? confirmMerge = await _showConfirmMergeDialog(primaryContact);

      // Eğer kullanıcı onaylamazsa, işlemi sonlandır
      if (confirmMerge != true) {
        _showSnackbar(l10n.merge_canceled);
        ref.read(mergingStateProvider.notifier).state = false;
        return;
      }

      // Birleştirme işlemini gerçekleştir
      final contactsManager = ContactsManager();
      final result = await contactsManager.mergeContacts(selectedContacts,
          primaryContact: primaryContact);

      if (result) {
        // Önce önbelleği temizle
        contactsManager.clearCache();
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
      ref.read(mergingStateProvider.notifier).state = false;
    }
  }

  Future<Contact?> _showMergeOptionsDialog(List<Contact> contacts) async {
    // Tema değişkenlerini al
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Color(0xFF222222) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    // Lokalizasyon erişimi için
    final l10n = AppLocalizations.of(context);

    // Ekran boyutunu al
    final screenSize = MediaQuery.of(context).size;

    return await showDialog<Contact>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            width: screenSize.width,
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog başlığı
                Row(
                  children: [
                    Icon(
                      Icons.person_add_outlined,
                      color: appPrimaryColor,
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        l10n.select_primary_contact,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // Alt açıklama
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: appPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: appPrimaryColor,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.primary_contact_info,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.9)
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Kişi listesi
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.1)
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        elevation: 0,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop(contact);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 14, horizontal: 18),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: appPrimaryColor.withOpacity(0.1),
                                    border: Border.all(
                                      color: appPrimaryColor.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      contact.displayName.isNotEmpty
                                          ? contact.displayName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: appPrimaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 18),

                                // Kişi bilgileri
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.displayName.isNotEmpty
                                            ? contact.displayName
                                            : l10n.anonymous_name,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w500,
                                          color: textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            contact.phones.isNotEmpty
                                                ? Icons.phone_outlined
                                                : Icons.phone_disabled_outlined,
                                            size: 16,
                                            color: textColor.withOpacity(0.5),
                                          ),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              contact.phones.isNotEmpty
                                                  ? contact.phones.first.number
                                                  : l10n.no_phone_number,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                    textColor.withOpacity(0.7),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Seçim ikonu
                                Icon(
                                  Icons.radio_button_unchecked,
                                  color: appPrimaryColor,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: 20),

                // Alt butonlar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // İptal butonu
                    TextButton(
                      onPressed: () {
                        // Sadece dialog'u kapat, null döndür (seçim yapılmadı)
                        Navigator.of(context).pop(null);
                      },
                      style: TextButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                      child: Text(
                        l10n.cancel,
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Birleştirme işlemi onay diyaloğu
  Future<bool?> _showConfirmMergeDialog(Contact primaryContact) async {
    // Tema değişkenlerini al
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Color(0xFF222222) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    // Lokalizasyon erişimi için
    final l10n = AppLocalizations.of(context);

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
                size: 26,
              ),
              SizedBox(width: 10),
              Text(
                l10n.merge_confirmation,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
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

  // Bildirim gösterme yardımcı metodu
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
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
        ref.invalidate(duplicateNamesProvider);
        ref.invalidate(contactsCountProvider);
        ref.invalidate(filteredContactsCountProvider);
        ref.invalidate(contactsListProvider);
        ref.invalidate(duplicateContactsProvider);
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

  IconData _getAccountIcon(String type) {
    // Hesap türüne göre uygun ikon
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
}
