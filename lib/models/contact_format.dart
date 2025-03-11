enum ContactFormat {
  vCard,
  csv,
  excel,
  pdf,
  json;

  String get displayName {
    switch (this) {
      case ContactFormat.vCard:
        return 'vCard (.vcf)';
      case ContactFormat.csv:
        return 'CSV (.csv)';
      case ContactFormat.excel:
        return 'Excel (.xlsx)';
      case ContactFormat.pdf:
        return 'PDF (.pdf)';
      case ContactFormat.json:
        return 'JSON (.json)';
    }
  }

  String get fileExtension {
    switch (this) {
      case ContactFormat.vCard:
        return '.vcf';
      case ContactFormat.csv:
        return '.csv';
      case ContactFormat.excel:
        return '.xlsx';
      case ContactFormat.pdf:
        return '.pdf';
      case ContactFormat.json:
        return '.json';
    }
  }

  String get mimeType {
    switch (this) {
      case ContactFormat.vCard:
        return 'text/vcard';
      case ContactFormat.csv:
        return 'text/csv';
      case ContactFormat.excel:
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case ContactFormat.pdf:
        return 'application/pdf';
      case ContactFormat.json:
        return 'application/json';
    }
  }
}
