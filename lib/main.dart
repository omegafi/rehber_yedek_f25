import 'dart:async'; // Completer için eklendi
import 'dart:io'; // Platform için eklendi
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // kIsWeb için eklendi
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
import 'screens/import_screen.dart';
import 'screens/backup_files_screen.dart';
import 'screens/splash_screen.dart';
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

  // Uygulama başlangıç zamanını kaydet
  final startTime = DateTime.now();
  debugPrint('Uygulama başlatılıyor...');

  // Verileri paralel olarak yüklüyoruz
  final prefsCompleter = Completer<SharedPreferences>();
  final permissionCompleter = Completer<PermissionStatus>();

  // Paylaşılan tercihleri yüklüyoruz - asenkron
  SharedPreferences.getInstance().then((prefs) {
    prefsCompleter.complete(prefs);
  });

  // İzin durumunu kontrol ediyoruz - asenkron (sadece mobil cihazlarda)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    Permission.contacts.status.then((status) {
      permissionCompleter.complete(status);
    });
  } else {
    permissionCompleter.complete(PermissionStatus.granted);
  }

  // İki işlemin de tamamlanmasını bekle
  final prefs = await prefsCompleter.future;
  final contactsPermissionStatus = await permissionCompleter.future;

  // Tercihleri al
  final isPremium = prefs.getBool('is_premium') ?? false;
  final isFirstRun = prefs.getBool('onboarding_completed') ?? false;
  final String preferredLanguage = prefs.getString('language') ?? 'tr';
  final bool isDarkMode = prefs.getBool('dark_theme') ?? false;
  final themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  final endTime = DateTime.now();
  final loadDuration = endTime.difference(startTime).inMilliseconds;
  debugPrint('Uygulama ayarları $loadDuration ms\'de yüklendi');

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

  // Yükleme işlemi tamamlandıktan sonra native splash'i kaldır
  // Daha pürüzsüz geçiş için biraz geciktir
  Future.delayed(Duration(milliseconds: 100), () {
    FlutterNativeSplash.remove();
    debugPrint('Native splash kaldırıldı');
  });
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

    // Performans metriği
    final buildStartTime = DateTime.now();

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
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/export': (context) => const ExportScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/premium': (context) => const PremiumScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/import': (context) => const ImportScreen(),
        '/backup_files': (context) => const BackupFilesScreen(),
      },
      builder: (context, child) {
        // Performans metriği için build süresini ölç
        final buildEndTime = DateTime.now();
        final buildDuration =
            buildEndTime.difference(buildStartTime).inMilliseconds;
        debugPrint('MaterialApp build süresi: $buildDuration ms');

        return child!;
      },
    );
  }
}
