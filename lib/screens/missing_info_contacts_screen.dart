import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/contacts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localizations.dart';
// Ana ekrandaki provider'ları import et
import '../screens/home_screen.dart'
    show
        contactsCountProvider,
        filteredContactsCountProvider,
        contactsListProvider,
        duplicateContactsProvider,
        missingInfoContactsProvider;
import '../screens/settings_screen.dart'
    show
        refreshContactsCacheProvider,
        includeContactsWithoutNumberProvider,
        includeNumbersWithoutNameProvider;

// Tema renkleri için sabit
final appPrimaryColor = Color(0xFF4285F4); // Ana Google mavisi

// Filtre türleri
enum MissingInfoFilterType { all, name, phone, email }

// Aktif filtre provider'ı
final missingInfoFilterProvider =
    StateProvider<MissingInfoFilterType>((ref) => MissingInfoFilterType.all);

// Provider tanımları
final missingInfoContactsProvider = FutureProvider<List<Contact>>((ref) async {
  final contactsManager = ContactsManager();
  return await contactsManager.getMissingInfoContacts();
});

// Filtrelenmiş kişiler provider'ı
final filteredMissingInfoContactsProvider =
    Provider<AsyncValue<List<Contact>>>((ref) {
  final contactsAsync = ref.watch(missingInfoContactsProvider);
  final filterType = ref.watch(missingInfoFilterProvider);

  return contactsAsync.whenData((contacts) {
    switch (filterType) {
      case MissingInfoFilterType.name:
        return contacts
            .where((contact) =>
                contact.name.first.isEmpty && contact.name.last.isEmpty)
            .toList();
      case MissingInfoFilterType.phone:
        return contacts.where((contact) => contact.phones.isEmpty).toList();
      case MissingInfoFilterType.email:
        return contacts.where((contact) => contact.emails.isEmpty).toList();
      case MissingInfoFilterType.all:
      default:
        return contacts;
    }
  });
});

class MissingInfoContactsScreen extends ConsumerStatefulWidget {
  const MissingInfoContactsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MissingInfoContactsScreen> createState() =>
      _MissingInfoContactsScreenState();
}

class _MissingInfoContactsScreenState
    extends ConsumerState<MissingInfoContactsScreen> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tema değişkenleri
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final surfaceColor = isDarkMode ? Color(0xFF1E1E1E) : Color(0xFFF5F5F5);

    // Filtre türünü al
    final filterType = ref.watch(missingInfoFilterProvider);

    // Filtrelenmiş kişiler listesini al
    final filteredContactsAsync =
        ref.watch(filteredMissingInfoContactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).missing_info),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
      ),
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Daha zarif filtre seçicisi
          Container(
            margin: EdgeInsets.fromLTRB(16, 12, 16, 6),
            height: 36,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              controller: _scrollController,
              child: Row(
                children: MissingInfoFilterType.values.map((type) {
                  final isSelected = type == filterType;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () {
                        ref.read(missingInfoFilterProvider.notifier).state =
                            type;

                        // Seçilen öğeye kaydır
                        final index =
                            MissingInfoFilterType.values.indexOf(type);
                        _scrollToSelectedItem(index);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? appPrimaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : textColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getIconForType(type),
                              size: 14,
                              color: isSelected
                                  ? Colors.white
                                  : textColor.withOpacity(0.7),
                            ),
                            SizedBox(width: 4),
                            Text(
                              _getTextForType(type),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : textColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Kişi sayısı göstergesi
          filteredContactsAsync.when(
            data: (contacts) => Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${contacts.length} ${context.l10n.contacts_found}',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            loading: () => SizedBox.shrink(),
            error: (_, __) => SizedBox.shrink(),
          ),

          // Kişi listesi
          Expanded(
            child: filteredContactsAsync.when(
              data: (contacts) {
                if (contacts.isEmpty) {
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
                          _getEmptyStateMessage(filterType),
                          style: TextStyle(
                            fontSize: 18,
                            color: textColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];

                    // Kişinin hangi bilgilerinin eksik olduğunu belirle
                    List<String> missingInfo = [];
                    if (contact.name.first.isEmpty &&
                        contact.name.last.isEmpty) {
                      missingInfo.add(context.l10n.name_label);
                    }
                    if (contact.phones.isEmpty) {
                      missingInfo.add(context.l10n.phone_label);
                    }
                    if (contact.emails.isEmpty) {
                      missingInfo.add(context.l10n.email_label);
                    }

                    return Card(
                      elevation: 0,
                      margin: EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                          // Kişi başlık alanı
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDarkMode
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.transparent,
                                    child: Text(
                                      contact.displayName.isNotEmpty
                                          ? contact.displayName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: appPrimaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),

                                // İsim ve eksik bilgi etiketi
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.displayName.isNotEmpty
                                            ? contact.displayName
                                            : 'İsimsiz Kişi',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 12,
                                            color: Colors.orange,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            '${missingInfo.join(", ")} eksik',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Düzenle butonu
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, size: 16),
                                  color: textColor.withOpacity(0.6),
                                  onPressed: () =>
                                      _openContactDetails(contact.id),
                                  constraints: BoxConstraints(
                                      minWidth: 24, minHeight: 24),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Düzenle',
                                ),
                              ],
                            ),
                          ),

                          // Mevcut ve eksik bilgiler
                          if (contact.name.first.isNotEmpty ||
                              contact.name.last.isNotEmpty ||
                              contact.phones.isNotEmpty ||
                              contact.emails.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: isDarkMode
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                              ),
                            ),

                          // Bilgi satırları
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 12, right: 12, bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (contact.name.first.isNotEmpty ||
                                    contact.name.last.isNotEmpty)
                                  _buildCompactInfoRow(
                                    Icons.person_outline,
                                    '${contact.name.first} ${contact.name.last}',
                                    textColor,
                                  ),
                                if (contact.phones.isNotEmpty)
                                  _buildCompactInfoRow(
                                    Icons.phone_outlined,
                                    contact.phones.first.number,
                                    textColor,
                                  ),
                                if (contact.emails.isNotEmpty)
                                  _buildCompactInfoRow(
                                    Icons.email_outlined,
                                    contact.emails.first.address,
                                    textColor,
                                  ),
                              ],
                            ),
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
                  '${context.l10n.export_error}: $error',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Minimal bilgi satırı
  Widget _buildCompactInfoRow(IconData icon, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor.withOpacity(0.6)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Filtre tipi için ikon
  IconData _getIconForType(MissingInfoFilterType type) {
    switch (type) {
      case MissingInfoFilterType.all:
        return Icons.filter_list;
      case MissingInfoFilterType.name:
        return Icons.person_off_outlined;
      case MissingInfoFilterType.phone:
        return Icons.phone_disabled_outlined;
      case MissingInfoFilterType.email:
        return Icons.alternate_email;
    }
  }

  // Filtre tipi için metin
  String _getTextForType(MissingInfoFilterType type) {
    switch (type) {
      case MissingInfoFilterType.all:
        return context.l10n.all_missing_info;
      case MissingInfoFilterType.name:
        return context.l10n.show_missing_name;
      case MissingInfoFilterType.phone:
        return context.l10n.show_missing_phone;
      case MissingInfoFilterType.email:
        return context.l10n.show_missing_email;
    }
  }

  // Boş durum mesajı
  String _getEmptyStateMessage(MissingInfoFilterType filterType) {
    switch (filterType) {
      case MissingInfoFilterType.name:
        return context.l10n.no_missing_name;
      case MissingInfoFilterType.phone:
        return context.l10n.no_missing_phone;
      case MissingInfoFilterType.email:
        return context.l10n.no_missing_email;
      case MissingInfoFilterType.all:
      default:
        return context.l10n.no_missing_info;
    }
  }

  void _openContactDetails(String contactId) {
    // Cihaz rehber uygulamasında kişiyi aç
    ContactsManager().openContact(contactId);

    // Kullanıcı rehberden döndüğünde ana ekrana git ve tüm provider'ları yenile
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        // Ana ekrandaki ilgili tüm provider'ları yenile
        ref.invalidate(contactsCountProvider);
        ref.invalidate(filteredContactsCountProvider);
        ref.invalidate(contactsListProvider);
        ref.invalidate(duplicateContactsProvider);
        ref.invalidate(missingInfoContactsProvider);
        ref.read(refreshContactsCacheProvider.notifier).state++;

        // Ana ekrana geri dön
        Navigator.of(context).pop();
      }
    });
  }

  void _scrollToSelectedItem(int index) {
    if (!_scrollController.hasClients) return;

    // Seçilen öğeye kaydır
    // Her öğeye biraz daha fazla genişlik ekleyerek düzgün görünmesini sağlıyoruz
    _scrollController.animateTo(
      index * 85.0, // Yaklaşık bir öğe genişliği
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
