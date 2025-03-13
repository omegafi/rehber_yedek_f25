import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'screens/home_screen.dart';
import 'screens/export_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'utils/app_localizations.dart';
import 'providers/localization_provider.dart';

// Premium durum Provider'ı (eski provider ile uyumluluk için)
final isPremiumProvider = StateProvider<bool>((ref) => false);
final isPremiumUserProvider = StateProvider<bool>((ref) => false);

// İlk çalıştırma kontrolü Provider'ı
final isFirstRunProvider = StateProvider<bool>((ref) => true);

// Tema Provider'ı
final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// Rehber izin durumu sağlayıcısı
final contactsPermissionProvider =
    StateProvider<PermissionStatus>((ref) => PermissionStatus.denied);

// Maksimum ücretsiz kişi sayısı
final maxFreeContactsProvider = Provider<int>((ref) => 50);

// Uygulama için desteklenen diller
final supportedLocales = [
  const Locale('en'), // İngilizce
  const Locale('tr'), // Türkçe
  const Locale('es'), // İspanyolca
  const Locale('ja'), // Japonca
  const Locale('de'), // Almanca
  const Locale('fr'), // Fransızca
];

// Tema StateController için özel extension
extension ThemeStateControllerExtension on StateController<ThemeMode> {
  void toggleTheme() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

void main() async {
  // Splash screen'i preserve
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Ekran yönünü dikey olarak kilitliyoruz
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Paylaşılan tercihleri yüklüyoruz
  final prefs = await SharedPreferences.getInstance();

  // Premium durumunu yüklüyoruz
  final isPremium = prefs.getBool('is_premium') ?? false;

  // İlk çalıştırma kontrolünü yüklüyoruz
  final isFirstRun = prefs.getBool('onboarding_completed') ?? false;

  // Seçili dili yüklüyoruz (varsayılan olarak cihaz dili)
  final String preferredLanguage = prefs.getString('language') ?? 'tr';

  // Tema tercihini yüklüyoruz
  final bool isDarkMode = prefs.getBool('dark_theme') ?? false;
  final themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // İzin durumunu kontrol ediyoruz (mobil cihazlar için)
  final contactsPermissionStatus = await Permission.contacts.status;

  runApp(
    ProviderScope(
      overrides: [
        // Kayıtlı tercihlere dayalı provider değerlerini ayarlıyoruz
        isPremiumProvider.overrideWith((ref) => isPremium),
        isPremiumUserProvider.overrideWith((ref) => isPremium),
        isFirstRunProvider.overrideWith((ref) => !isFirstRun),
        localeProvider.overrideWith((ref) => Locale(preferredLanguage)),
        themeProvider.overrideWith((ref) => themeMode),
        contactsPermissionProvider
            .overrideWith((ref) => contactsPermissionStatus),
      ],
      child: const MyApp(),
    ),
  );

  // Splash screen'i kaldırıyoruz
  FlutterNativeSplash.remove();
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dil seçeneğini izliyoruz
    final locale = ref.watch(localeProvider);

    // İlk çalıştırma durumunu izliyoruz
    final isFirstRun = ref.watch(isFirstRunProvider);

    // Tema modunu izliyoruz
    final themeMode = ref.watch(themeProvider);

    // Tema ayarları
    final appTheme = AppTheme();

    return MaterialApp(
      title: 'Rehber Yedekleme',
      debugShowCheckedModeBanner: false,
      theme: appTheme.lightTheme,
      darkTheme: appTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales,
      locale: locale,
      initialRoute: isFirstRun ? '/onboarding' : '/home',
      routes: {
        '/home': (context) => const HomeScreen(),
        '/export': (context) => const ExportScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/premium': (context) => const PremiumScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
    );
  }
}
