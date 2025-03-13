import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // Sınıfın statik yardımcı metodu
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  Future<bool> load() async {
    // Dil dosyasını yükle
    String jsonString =
        await rootBundle.loadString('assets/lang/${locale.languageCode}.json');

    Map<String, dynamic> jsonMap = json.decode(jsonString);

    _localizedStrings = jsonMap.map((key, value) {
      return MapEntry(key, value.toString());
    });

    return true;
  }

  // Bir anahtar verildiğinde, ilgili dildeki metni döndürür
  String translate(String key) {
    if (_localizedStrings.containsKey(key)) {
      return _localizedStrings[key]!;
    }

    // Eğer anahtar bulunamadıysa, anahtarı döndür (hata durumu)
    return key;
  }

  // Özel getter'lar
  String get app_title => translate('app_title');
  String get home_screen_title => translate('home_screen_title');
  String get settings_screen_title => translate('settings_screen_title');
  String get export_screen_title => translate('export_screen_title');
  String get import_screen_title => translate('import_screen_title');

  String get premium_title => translate('premium_title');
  String get premium_features => translate('premium_features');
  String get premium_subtitle => translate('premium_subtitle');
  String get premium_button => translate('premium_button');
  String get premium_active => translate('premium_active');
  String get premium_required => translate('premium_required');
  String get premium_limit_message => translate('premium_limit_message');
  String get premium_upgrade_message => translate('premium_upgrade_message');

  String get backup_all_contacts => translate('backup_all_contacts');
  String get no_ads => translate('no_ads');
  String get priority_support => translate('priority_support');
  String get auto_backup => translate('auto_backup');
  String get lifetime_premium => translate('lifetime_premium');

  String get theme_title => translate('theme_title');
  String get dark_theme => translate('dark_theme');
  String get dark_theme_subtitle_on => translate('dark_theme_subtitle_on');
  String get dark_theme_subtitle_off => translate('dark_theme_subtitle_off');
  String get dark_theme_hint => translate('dark_theme_hint');

  String get language_title => translate('language_title');
  String get current_language => translate('current_language');
  String get change_language => translate('change_language');
  String get english => translate('english');
  String get turkish => translate('turkish');
  String get spanish => translate('spanish');
  String get japanese => translate('japanese');

  String get guide_title => translate('guide_title');
  String get show_tutorial => translate('show_tutorial');

  String get contacts_title => translate('contacts_title');
  String get total_contacts => translate('total_contacts');
  String get view_all_contacts => translate('view_all_contacts');
  String get search_contacts => translate('search_contacts');
  String get no_contacts => translate('no_contacts');

  String get quick_actions => translate('quick_actions');
  String get backup_contacts => translate('backup_contacts');
  String get backup_contacts_desc => translate('backup_contacts_desc');
  String get restore_contacts => translate('restore_contacts');
  String get restore_contacts_desc => translate('restore_contacts_desc');

  String get export_format => translate('export_format');
  String get share => translate('share');
  String get exporting => translate('exporting');
  String get export_and_share => translate('export_and_share');
  String get export_success => translate('export_success');
  String get export_error => translate('export_error');
  String get export_success_message => translate('export_success_message');

  String get permission_required => translate('permission_required');
  String get contacts_permission_message =>
      translate('contacts_permission_message');
  String get grant_permission => translate('grant_permission');
  String get open_settings => translate('open_settings');

  String get about_app => translate('about_app');
  String get app_version => translate('app_version');
  String get app_description => translate('app_description');

  String get contact_info => translate('contact_info');
  String get copyright => translate('copyright');
  String get contact_us => translate('contact_us');
  String get visit_website => translate('visit_website');

  String get onboarding_title_1 => translate('onboarding_title_1');
  String get onboarding_subtitle_1 => translate('onboarding_subtitle_1');
  String get onboarding_title_2 => translate('onboarding_title_2');
  String get onboarding_subtitle_2 => translate('onboarding_subtitle_2');

  String get next => translate('next');
  String get skip => translate('skip');
  String get get_started => translate('get_started');
  String get back => translate('back');
  String get cancel => translate('cancel');
  String get buy => translate('buy');
  String get retry => translate('retry');
  String get ok => translate('ok');
  String get close => translate('close');

  String get vcard_desc => translate('vcard_desc');
  String get csv_desc => translate('csv_desc');
  String get excel_desc => translate('excel_desc');
  String get pdf_desc => translate('pdf_desc');
  String get json_desc => translate('json_desc');

  // Dil seçenekleri ile ilgili getter'lar
  String get language_settings => translate('language_settings');
  String get system_language => translate('system_language');
  String get use_system_language => translate('use_system_language');

  // Rehber filtreleme ile ilgili getter'lar
  String get contact_filtering => translate('contact_filtering');
  String get include_contacts_without_number =>
      translate('include_contacts_without_number');
  String get include_contacts_without_number_desc =>
      translate('include_contacts_without_number_desc');
  String get include_numbers_without_name =>
      translate('include_numbers_without_name');
  String get include_numbers_without_name_desc =>
      translate('include_numbers_without_name_desc');
  String get filters_active => translate('filters_active');
  String get filtered_contacts => translate('filtered_contacts');
  String get total_contact_count => translate('total_contact_count');

  // Veri yükleme ve bekletme ile ilgili getter'lar
  String get loading_contacts => translate('loading_contacts');
  String get please_wait => translate('please_wait');
  String get contact_not_found => translate('contact_not_found');

  // Uygulama statüsü ile ilgili getter'lar
  String get last_update => translate('last_update');
  String get last_backup => translate('last_backup');
  String get backup_and_share => translate('backup_and_share');

  // Seçim ile ilgili getter'lar
  String get select_contacts => translate('select_contacts');
  String get contacts_selected => translate('contacts_selected');
  String get backup_selected_contacts => translate('backup_selected_contacts');
  String get select_all => translate('select_all');
  String get deselect_all => translate('deselect_all');

  // Tür isimleri
  String get anonymous_contact => translate('anonymous_contact');

  // Buton ve UI elemanları
  String get done => translate('done');
  String get apply => translate('apply');
  String get home => translate('home');
  String get my_contacts => translate('my_contacts');
  String get settings => translate('settings');
  String get calendar => translate('calendar');
  String get statistics => translate('statistics');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Desteklenen diller
    return ['en', 'tr', 'es', 'ja', 'de', 'fr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// Kolay erişim için uzantı metodu
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
