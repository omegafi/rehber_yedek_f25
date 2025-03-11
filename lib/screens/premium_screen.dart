import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    // Açık tema renkleri
    final backgroundColor = Colors.white;
    final textColor = Colors.black;
    final accentColor = const Color(0xFF4285F4);

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
          : _buildPremiumOffer(context, textColor, accentColor, ref),
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
      BuildContext context, Color textColor, Color accentColor, WidgetRef ref) {
    return SingleChildScrollView(
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
            _buildFeatureItem(
                Icons.contacts, context.l10n.backup_all_contacts, textColor),
            _buildFeatureItem(Icons.block, context.l10n.no_ads, textColor),
            _buildFeatureItem(
                Icons.support_agent, context.l10n.priority_support, textColor),
            _buildFeatureItem(
                Icons.update, context.l10n.auto_backup, textColor),

            const SizedBox(height: 40),

            // Yaşam boyu premium yazısı
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
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

            const SizedBox(height: 40),

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
                onPressed: () => _handlePurchase(context, ref),
                child: Text(
                  context.l10n.premium_button,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4285F4)),
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

  void _handlePurchase(BuildContext context, WidgetRef ref) {
    // Gerçek uygulamada burada in-app satın alma işlemi başlatılır

    // Test amacıyla, premium durumunu aktif olarak değiştiriyoruz
    ref.read(isPremiumProvider.notifier).state = true;
    ref.read(isPremiumUserProvider.notifier).state = true;

    // Başarılı satın alma mesajı
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.premium_active),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Bir süre sonra ekranı kapat
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    });
  }
}
