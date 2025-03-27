import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/contacts_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';
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
        duplicateEmailsProvider;
import '../screens/settings_screen.dart' show refreshContactsCacheProvider;

// Tema renkleri için sabit
final appPrimaryColor = Color(0xFF4285F4); // Ana Google mavisi

// Provider tanımları
final duplicateEmailsProvider =
    FutureProvider<List<List<dynamic>>>((ref) async {
  final contactsManager = ContactsManager();
  return await contactsManager.getDuplicateEmails();
});

class DuplicateEmailsScreen extends ConsumerStatefulWidget {
  const DuplicateEmailsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DuplicateEmailsScreen> createState() =>
      _DuplicateEmailsScreenState();
}

class _DuplicateEmailsScreenState extends ConsumerState<DuplicateEmailsScreen> {
  @override
  Widget build(BuildContext context) {
    // Tema değişkenleri
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    // Tekrar eden e-postalar listesini almak için provider'ı kullan
    final duplicateEmailsAsync = ref.watch(duplicateEmailsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).duplicate_emails),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
      ),
      backgroundColor: backgroundColor,
      body: duplicateEmailsAsync.when(
        data: (duplicateEmails) {
          if (duplicateEmails.isEmpty) {
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
                    context.l10n.no_duplicate_emails,
                    style: TextStyle(
                      fontSize: 18,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          // Tekrar eden e-postaları gruplandır
          Map<String, List<Contact>> groupedContacts = {};

          for (var contactGroup in duplicateEmails) {
            final contacts = contactGroup as List<Contact>;
            if (contacts.isNotEmpty && contacts.first.emails.isNotEmpty) {
              String email = contacts.first.emails.first.address;
              groupedContacts[email] = contacts;
            }
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: groupedContacts.length,
            itemBuilder: (context, index) {
              String email = groupedContacts.keys.elementAt(index);
              List<Contact> contacts = groupedContacts[email]!;

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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.email,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              email,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
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
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade300,
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: contacts.length,
                      padding: EdgeInsets.only(top: 8, bottom: 8),
                      itemBuilder: (context, contactIndex) {
                        final contact = contacts[contactIndex];
                        return Container(
                          margin:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.transparent,
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: Container(
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
                            title: Text(
                              contact.displayName.isNotEmpty
                                  ? contact.displayName
                                  : 'İsimsiz Kişi',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                            subtitle: contact.emails.isNotEmpty
                                ? Text(
                                    contact.emails.first.address,
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.6),
                                    ),
                                  )
                                : Text(
                                    'E-posta Yok',
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.6),
                                    ),
                                  ),
                            trailing: IconButton(
                              icon: Icon(Icons.open_in_new, size: 16),
                              color: textColor.withOpacity(0.6),
                              padding: EdgeInsets.zero,
                              constraints:
                                  BoxConstraints(minWidth: 24, minHeight: 24),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _openContactDetails(contact.id),
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
    );
  }

  void _openContactDetails(String contactId) {
    // Cihaz rehber uygulamasında kişiyi aç
    ContactsManager().openContact(contactId);

    // Kullanıcı rehberden döndüğünde ana ekrana git ve tüm provider'ları yenile
    Future.delayed(Duration(seconds: 1), () async {
      if (mounted) {
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

        // Ana ekrana dön
        Navigator.of(context).pop();
      }
    });
  }
}
