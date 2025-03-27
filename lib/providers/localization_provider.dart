import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama dilini yöneten provider
final localeProvider = StateProvider<Locale>((ref) {
  // Varsayılan olarak sistem dilini kullan
  return const Locale('tr');
});

/// Uygulama başlangıcında dil ayarını yüklemek için kullanılan fonksiyon
Future<void> loadLocale(WidgetRef ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code');

    if (languageCode != null && languageCode != 'system') {
      ref.read(localeProvider.notifier).state = Locale(languageCode);
    } else {
      // Sistem dilini kullan veya varsayılan olarak Türkçe
      ref.read(localeProvider.notifier).state = const Locale('tr');
    }
  } catch (e) {
    debugPrint('Dil ayarı yüklenirken hata oluştu: $e');
    // Hata durumunda varsayılan dil olarak Türkçe kullan
    ref.read(localeProvider.notifier).state = const Locale('tr');
  }
}

/// Dil değiştirme işlemini gerçekleştiren sınıf
class LocalizationProvider extends ChangeNotifier {
  Locale _locale = const Locale('tr');

  Locale get locale => _locale;

  void setLocale(String languageCode) {
    if (languageCode == 'system') {
      // Sistem dilini kullan (varsayılan olarak Türkçe)
      _locale = const Locale('tr');
    } else {
      _locale = Locale(languageCode);
    }
    notifyListeners();
    _saveLocale(languageCode);
  }

  Future<void> _saveLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
  }
}
