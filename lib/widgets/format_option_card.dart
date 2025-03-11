import 'package:flutter/material.dart';
import '../models/contact_format.dart';

class FormatOptionCard extends StatelessWidget {
  final ContactFormat format;
  final bool isSelected;
  final VoidCallback onTap;

  const FormatOptionCard({
    Key? key,
    required this.format,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFormatIcon(),
              const SizedBox(height: 12),
              Text(
                format.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              if (isSelected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Seçili',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatIcon() {
    IconData iconData;
    Color iconColor;

    switch (format) {
      case ContactFormat.vCard:
        iconData = Icons.contact_page;
        iconColor = Colors.blue;
        break;
      case ContactFormat.csv:
        iconData = Icons.table_chart;
        iconColor = Colors.green;
        break;
      case ContactFormat.excel:
        iconData = Icons.insert_chart;
        iconColor = Colors.green.shade700;
        break;
      case ContactFormat.pdf:
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case ContactFormat.json:
        iconData = Icons.code;
        iconColor = Colors.blue.shade800;
        break;
    }

    return Icon(
      iconData,
      size: 40,
      color: iconColor,
    );
  }
}
