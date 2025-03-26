import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';

// Ürün ID'leri - Apple ve Google için aynı ID kullanmak mümkündür
// ancak farklı ID'ler kullanmak da tercih edilebilir
const String _kPremiumProductId = 'premium_lifetime';
const String _kAppleProductId = 'com.rehberyedek.premium_lifetime';
const String _kGoogleProductId = 'premium_lifetime';

// Satın alma işlemleri state provider
final purchaseLoadingProvider = StateProvider<bool>((ref) => false);
final purchaseErrorProvider = StateProvider<String?>((ref) => null);
final productDetailsProvider = StateProvider<ProductDetails?>((ref) => null);

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initInAppPurchase();
  }

  Future<void> _initInAppPurchase() async {
    // Mağaza kullanılabilir mi kontrol et
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      setState(() {
        _isAvailable = false;
        _isLoading = false;
        _errorMessage = 'Mağaza şu anda kullanılamıyor.';
      });
      return;
    }

    // Satın alma stream'ini dinle
    _subscription = _inAppPurchase.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        _handleError(error);
      },
    );

    // Ürün bilgilerini al
    await _getProductDetails();
  }

  Future<void> _getProductDetails() async {
    setState(() {
      _isLoading = true;
    });

    // Platform için doğru ürün ID'sini seç
    final String productId =
        Platform.isIOS ? _kAppleProductId : _kGoogleProductId;

    final Set<String> _kIds = {productId};
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(_kIds);

    if (response.notFoundIDs.isNotEmpty) {
      // Ürün bulunamadı
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ürün bulunamadı: ${response.notFoundIDs.join(", ")}';
      });
      return;
    }

    if (response.error != null) {
      // Hata oluştu
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ürün bilgileri alınamadı: ${response.error}';
      });
      return;
    }

    if (response.productDetails.isEmpty) {
      // Ürün yok
      setState(() {
        _isLoading = false;
        _errorMessage = 'Premium paket şu anda mevcut değil.';
      });
      return;
    }

    // Ürün bilgilerini kaydet
    setState(() {
      _products = response.productDetails;
      _isAvailable = true;
      _isLoading = false;

      // İlk ürünü provider'a kaydet
      if (_products.isNotEmpty) {
        ref.read(productDetailsProvider.notifier).state = _products.first;
      }
    });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      _handlePurchaseDetails(purchaseDetails);
    }
  }

  void _handlePurchaseDetails(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.status == PurchaseStatus.pending) {
      // Satın alma bekliyor
      ref.read(purchaseLoadingProvider.notifier).state = true;
    } else if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      // Satın alma başarılı veya geri yüklendi

      // Doğrulama yapılması gerekebilir (güvenlik için)
      bool valid = true; // Doğrulama işlemini burada yapın

      if (valid) {
        // Premium durumunu aktif et
        ref.read(isPremiumProvider.notifier).state = true;
        ref.read(isPremiumUserProvider.notifier).state = true;

        // Kullanıcıya başarılı mesajı göster
        _showSuccessDialog();
      }

      // Satın alma işlemi tamamlandı - kaldırılabilir
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }

      ref.read(purchaseLoadingProvider.notifier).state = false;
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      // Satın alma hatası
      ref.read(purchaseErrorProvider.notifier).state =
          purchaseDetails.error?.message ??
              'Satın alma sırasında bir hata oluştu.';
      ref.read(purchaseLoadingProvider.notifier).state = false;

      // Hata mesajını göster
      _showErrorDialog(purchaseDetails.error?.message ??
          'Satın alma sırasında bir hata oluştu.');
    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      // Satın alma iptal edildi
      ref.read(purchaseLoadingProvider.notifier).state = false;
    }
  }

  void _handleError(dynamic error) {
    ref.read(purchaseErrorProvider.notifier).state = error.toString();
    ref.read(purchaseLoadingProvider.notifier).state = false;
    _showErrorDialog(error.toString());
  }

  Future<void> _buy() async {
    if (_products.isEmpty) {
      _showErrorDialog('Premium paket şu anda mevcut değil.');
      return;
    }

    ref.read(purchaseLoadingProvider.notifier).state = true;

    // Satın alma parametreleri oluştur
    final ProductDetails productDetails = _products.first;
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
      applicationUserName: null, // Burada kullanıcı kimliği belirtilebilir
    );

    try {
      // Satın alma işlemini başlat
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      ref.read(purchaseLoadingProvider.notifier).state = false;
      ref.read(purchaseErrorProvider.notifier).state = e.toString();
      _showErrorDialog('Satın alma işlemi başlatılamadı: $e');
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  // Başarılı satın alma dialog'unu göster
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Text(
          'Premium Aktifleştirildi',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Premium özellikler başarıyla aktifleştirildi! Artık tüm premium özelliklere erişebilirsiniz.',
              style: TextStyle(
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Hata dialog'unu göster
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Text(
          'Hata Oluştu',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final isPremium = ref.watch(isPremiumProvider);
    final isLoading = ref.watch(purchaseLoadingProvider);

    // Tema renkleri
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextColor : Colors.black;
    final accentColor = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          context.l10n.premium_title,
          style: TextStyle(color: textColor),
        ),
      ),
      body: isPremium
          ? _buildPremiumActive(context, textColor, accentColor)
          : _buildPremiumOffer(context, textColor, accentColor),
    );
  }

  Widget _buildPremiumActive(
      BuildContext context, Color textColor, Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star,
              size: 60,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            context.l10n.premium_active,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
              Icons.contacts, context.l10n.backup_all_contacts, textColor),
          _buildFeatureItem(Icons.block, context.l10n.no_ads, textColor),
          _buildFeatureItem(
              Icons.support_agent, context.l10n.priority_support, textColor),
          _buildFeatureItem(Icons.update, context.l10n.auto_backup, textColor),
        ],
      ),
    );
  }

  Widget _buildPremiumOffer(
      BuildContext context, Color textColor, Color accentColor) {
    final isLoading = ref.watch(purchaseLoadingProvider);
    final productDetails = ref.watch(productDetailsProvider);

    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Premium başlık
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.star,
                      size: 60,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  context.l10n.premium_features,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.premium_subtitle,
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Premium özellikleri
                _buildFeatureItem(Icons.contacts,
                    context.l10n.backup_all_contacts, textColor),
                _buildFeatureItem(Icons.block, context.l10n.no_ads, textColor),
                _buildFeatureItem(Icons.support_agent,
                    context.l10n.priority_support, textColor),
                _buildFeatureItem(
                    Icons.update, context.l10n.auto_backup, textColor),

                const SizedBox(height: 40),

                // Yaşam boyu premium yazısı
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    context.l10n.lifetime_premium,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Fiyat bilgisi
                if (productDetails != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Fiyat: ${productDetails.price}',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // Satın alma butonu
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: isLoading || !_isAvailable || _products.isEmpty
                        ? null
                        : _buy,
                    child: Text(
                      isLoading
                          ? 'İşlem Yapılıyor...'
                          : (_errorMessage != null
                              ? 'Yeniden Dene'
                              : context.l10n.premium_button),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Geliştirici Test Butonu
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: isLoading ? null : _handleTestPurchase,
                    icon: const Icon(Icons.developer_mode),
                    label: const Text(
                      "Geliştirici Testi (Premium'a Yükselt)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Hata mesajı
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 20),

                // Gizlilik ve kullanım koşulları linkleri
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        // Gizlilik politikası sayfasına yönlendir
                      },
                      child: Text(
                        'Gizlilik Politikası',
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text('|',
                        style: TextStyle(color: textColor.withOpacity(0.5))),
                    TextButton(
                      onPressed: () {
                        // Kullanım koşulları sayfasına yönlendir
                      },
                      child: Text(
                        'Kullanım Koşulları',
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Yükleniyor göstergesi
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: CircularProgressIndicator(
                color: accentColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Geliştirici test satın alma işlemi
  void _handleTestPurchase() {
    setState(() {
      _isLoading = true;
    });

    // 2 saniye bekleme süresi ekliyoruz
    Future.delayed(const Duration(seconds: 2), () {
      // Premium durumunu aktif et
      ref.read(isPremiumProvider.notifier).state = true;
      ref.read(isPremiumUserProvider.notifier).state = true;

      setState(() {
        _isLoading = false;
      });

      // Başarılı mesajını göster
      _showSuccessDialog();
    });
  }
}
