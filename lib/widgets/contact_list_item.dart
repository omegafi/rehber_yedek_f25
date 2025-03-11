import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../theme/app_theme.dart';

class ContactListItem extends StatelessWidget {
  final Contact contact;
  final bool isDarkMode;

  const ContactListItem({
    Key? key,
    required this.contact,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.lightTextColor;
    final textSecondaryColor = isDarkMode
        ? AppTheme.darkTextSecondaryColor
        : AppTheme.lightTextSecondaryColor;

    return Card(
      color: backgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode
              ? AppTheme.darkDividerColor
              : AppTheme.lightDividerColor,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Text(
            _getInitials(),
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          _getDisplayName(),
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: contact.phones.isNotEmpty
            ? Text(
                contact.phones.first.number,
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 13,
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right,
          color: textSecondaryColor,
          size: 20,
        ),
      ),
    );
  }

  String _getInitials() {
    if (contact.name.first.isEmpty && contact.name.last.isEmpty) {
      return '?';
    }
    final firstInitial = contact.name.first.isNotEmpty
        ? contact.name.first[0].toUpperCase()
        : '';
    final lastInitial =
        contact.name.last.isNotEmpty ? contact.name.last[0].toUpperCase() : '';
    return '$firstInitial$lastInitial';
  }

  String _getDisplayName() {
    if (contact.name.first.isEmpty && contact.name.last.isEmpty) {
      return contact.phones.isNotEmpty
          ? contact.phones.first.number
          : 'İsimsiz Kişi';
    }
    return '${contact.name.first} ${contact.name.last}'.trim();
  }
}
