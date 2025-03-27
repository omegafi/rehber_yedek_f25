import 'dart:async';
import 'dart:math'; // min fonksiyonu için import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../main.dart' show isFirstRunProvider;
import '../services/contacts_service.dart'; // ContactsManager için import
import '../screens/settings_screen.dart'
    show
        includeContactsWithoutNumberProvider,
        includeNumbersWithoutNameProvider,
        refreshContactsCacheProvider; // Filtreleme provider'ları için import
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences için

// Splash Screen süresi (milisaniye) - Daha kısa süre
const int _splashDuration = 1000;

// Kişilerin yüklenme durumu için provider
final contactsLoadingProvider = StateProvider<bool>((ref) => true);
final contactsLoadingTextProvider = StateProvider<String>((ref) => "");

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animasyon controller'ı - daha kısa süre
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Fade-in animasyonu
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 0.65, curve: Curves.easeInOut),
    ));

    // Ölçek animasyonu
    _scaleAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 0.65, curve: Curves.easeInOut),
    ));

    // Animasyonu başlat
    _animationController.forward();

    // Kişileri yükleme işlemini başlat (arka planda devam eder)
    _loadContacts();

    // Belirli bir süre sonra uygun ekrana geçiş yap
    Timer(Duration(milliseconds: _splashDuration), () {
      // İlk çalıştırma durumunu kontrol et
      final isFirstRun = ref.read(isFirstRunProvider);

      // İlk çalıştırma ise onboarding ekranına git, değilse ana ekrana
      if (mounted) {
        Navigator.of(context)
            .pushReplacementNamed(isFirstRun ? '/onboarding' : '/home');
      }
    });
  }

  // Kişileri yükleme işlemi
  Future<void> _loadContacts() async {
    // Provider değişikliklerini widget ağacı oluşturulduktan sonra yapmak için Future ile sarmalıyoruz
    Future(() async {
      try {
        // Yükleme başladı mesajı
        ref.read(contactsLoadingTextProvider.notifier).state =
            "Kişileriniz hazırlanıyor...";

        // Filtreleme ayarlarını yükle
        await _loadFilterSettings();

        // ContactsManager'ı başlat
        final contactsManager = ContactsManager();

        // Maksimum yükleme süresi için timer
        bool isTimeout = false;
        Timer(Duration(seconds: 15), () {
          if (mounted) {
            isTimeout = true;
            // Future ile sarmala
            Future(() {
              ref.read(contactsLoadingTextProvider.notifier).state =
                  "Kişiler hala yükleniyor, lütfen bekleyin...";
            });
          }
        });

        // Kişileri arka planda yükle
        try {
          final contacts = await contactsManager.getAllContacts();

          // Kişi sayısını mesajda göster
          if (mounted && !isTimeout) {
            // Future ile sarmala
            Future(() {
              ref.read(contactsLoadingTextProvider.notifier).state =
                  "${contacts.length} kişi başarıyla yüklendi";
            });
          }
        } catch (e) {
          // Kişileri yükleme hatası
          if (mounted) {
            // Future ile sarmala
            Future(() {
              ref.read(contactsLoadingTextProvider.notifier).state =
                  "Kişileri yükleme hatası: ${e.toString().substring(0, min(50, e.toString().length))}";
            });
            debugPrint('Kişileri yükleme hatası: $e');
          }
        }
      } catch (e) {
        // Genel hata
        if (mounted) {
          // Future ile sarmala
          Future(() {
            ref.read(contactsLoadingTextProvider.notifier).state =
                "Kişiler yüklenirken hata oluştu, devam ediliyor...";
          });
          debugPrint('Kişiler işlemi sırasında hata: $e');
        }
      }
    });
  }

  // Filtreleme ayarlarını yükleme
  Future<void> _loadFilterSettings() async {
    // Provider değişikliklerini widget ağacı oluşturulduktan sonra yapmak için Future ile sarmalıyoruz
    return Future(() async {
      final prefs = await SharedPreferences.getInstance();
      final includeContactsWithoutNumber =
          prefs.getBool('include_contacts_without_number');
      final includeNumbersWithoutName =
          prefs.getBool('include_numbers_without_name');

      if (includeContactsWithoutNumber != null && mounted) {
        ref.read(includeContactsWithoutNumberProvider.notifier).state =
            includeContactsWithoutNumber;
      }

      if (includeNumbersWithoutName != null && mounted) {
        ref.read(includeNumbersWithoutNameProvider.notifier).state =
            includeNumbersWithoutName;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Karanlık mod / Aydınlık mod kontrolleri için yardımcı metotlar
  Color getBackgroundColor(bool isDarkMode) {
    return isDarkMode ? Colors.black : Colors.white;
  }

  Color getTextColor(bool isDarkMode) {
    return isDarkMode ? Colors.white : Colors.black;
  }

  Color getCardColor(bool isDarkMode) {
    return isDarkMode ? Color(0xFF1D1D1D) : Colors.white;
  }

  Color getSurfaceColor(bool isDarkMode) {
    return isDarkMode ? Color(0xFF121212) : Colors.white;
  }

  // Tema uyumlu container renkleri
  BoxDecoration getGradientDecoration(bool isDarkMode) {
    // Ana Google mavisi ve koyu tonu
    final primaryBlue = Color(0xFF4285F4);
    final darkBlue = Color(0xFF2A56C6);

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryBlue,
          darkBlue, // Daha koyu mavi ton
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ana Google mavisi ve koyu tonu
    final primaryBlue = Color(0xFF4285F4);
    final darkBlue = Color(0xFF2A56C6);

    // Sabit renkler - tema bağımsız
    final backgroundColor = primaryBlue;
    final textColor = Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        width: double.infinity,
        decoration: getGradientDecoration(false),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo ve isim animasyonu
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  // Uygulama İkonu - beyaz
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logorehber.png',
                        width: 80,
                        height: 80,
                        color: Color(
                            0xFF4285F4), // Ana Google mavisi rengine boyama
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Uygulama Adı - büyük, kalın
                  Text(
                    'Rehber Yedekleme',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Slogan
                  Text(
                    'Kişileriniz Güvende',
                    style: TextStyle(
                      fontSize: 18,
                      color: textColor.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
