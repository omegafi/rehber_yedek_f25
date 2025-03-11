import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Ana renk: Mavi (sadece vurgu için)
  static const Color primaryColor = Color(0xFF4285F4); // Google mavi

  // Koyu tema ana renkleri - Siyah arka plan, beyaz metin
  static const Color darkBackgroundColor = Colors.black; // Tam siyah arka plan
  static const Color darkSurfaceColor = Color(0xFF121212); // Koyu siyah yüzey
  static const Color darkCardColor =
      Color(0xFF1D1D1D); // Kartlar için koyu siyah
  static const Color darkTextColor = Colors.white; // Beyaz metin
  static const Color darkTextSecondaryColor =
      Colors.white; // Tam beyaz (görünürlük için)
  static const Color darkTextTertiaryColor =
      Colors.white; // Tam beyaz (görünürlük için)
  static const Color darkTextPrimaryColor = Colors.white; // Tam beyaz
  static const Color darkDividerColor =
      Colors.white38; // %38 beyaz (daha görünür)

  // Açık tema ana renkleri - Beyaz arka plan, siyah metin
  static const Color lightBackgroundColor = Colors.white; // Beyaz arka plan
  static const Color lightSurfaceColor = Colors.white; // Beyaz yüzey
  static const Color lightCardColor = Color(0xFFF5F5F5); // Açık gri kartlar
  static const Color lightTextColor = Colors.black; // Siyah metin
  static const Color lightTextSecondaryColor =
      Colors.black; // Tam siyah (görünürlük için)
  static const Color lightTextTertiaryColor =
      Colors.black; // Tam siyah (görünürlük için)
  static const Color lightTextPrimaryColor = Colors.black; // Tam siyah
  static const Color lightDividerColor =
      Colors.black26; // %26 siyah (daha görünür)

  // Uyarı ve bildirim renkleri (hepsi mavi - tutarlılık için)
  static const Color warningColor = primaryColor;
  static const Color errorColor = primaryColor;
  static const Color successColor = primaryColor;
  static const Color secondaryColor = primaryColor;

  // Tema yardımcı metodları
  static Color getBackgroundColor(bool isDarkMode) {
    return isDarkMode ? darkBackgroundColor : lightBackgroundColor;
  }

  static Color getSurfaceColor(bool isDarkMode) {
    return isDarkMode ? darkSurfaceColor : lightSurfaceColor;
  }

  static Color getCardColor(bool isDarkMode) {
    return isDarkMode ? darkCardColor : lightCardColor;
  }

  static Color getTextPrimaryColor(bool isDarkMode) {
    return isDarkMode ? darkTextPrimaryColor : lightTextPrimaryColor;
  }

  static Color getTextSecondaryColor(bool isDarkMode) {
    return isDarkMode ? darkTextSecondaryColor : lightTextSecondaryColor;
  }

  static Color getTextTertiaryColor(bool isDarkMode) {
    return isDarkMode ? darkTextTertiaryColor : lightTextTertiaryColor;
  }

  static Color getDividerColor(bool isDarkMode) {
    return isDarkMode ? darkDividerColor : lightDividerColor;
  }

  // ThemeData için kullanışlı metod
  static Color getColor(
      BuildContext context, Color lightColor, Color darkColor) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkColor : lightColor;
  }

  // Gölgeler
  static const List<BoxShadow> smallShadow = [
    BoxShadow(
      color: Color(0x25000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    )
  ];

  static const List<BoxShadow> mediumShadow = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    )
  ];

  // Border Radius - Daha minimal tasarım için daha küçük kenar yuvarlamaları
  static const double borderRadiusSmall = 6.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusLarge = 12.0;
  static const double borderRadiusXLarge = 16.0;

  // Boşluklar - Daha kompakt UI için daha küçük boşluklar
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 12.0; // 16 yerine 12
  static const double spacingLarge = 20.0; // 24 yerine 20
  static const double spacingXLarge = 28.0; // 32 yerine 28

  // Açık tema
  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor,
        surface: lightSurfaceColor,
        background: lightBackgroundColor,
        error: primaryColor,
        onBackground: lightTextPrimaryColor,
        onSurface: lightTextPrimaryColor,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: lightBackgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackgroundColor,
        foregroundColor: lightTextPrimaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: lightTextPrimaryColor),
      ),
      cardTheme: CardTheme(
        elevation: 1, // Daha az gölge
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        color: lightCardColor,
        shadowColor: Colors.black12,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: lightTextPrimaryColor,
        displayColor: lightTextPrimaryColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
              vertical: 12, horizontal: 20), // Daha küçük padding
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(
              vertical: 6, horizontal: 12), // Daha küçük
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: primaryColor,
        size: 22, // Daha küçük ikonlar
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.3);
        }),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Daha kompakt
        tileColor: lightSurfaceColor,
        iconColor: primaryColor,
        textColor: lightTextPrimaryColor,
      ),
      dividerTheme: const DividerThemeData(
        color: lightDividerColor,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightCardColor,
        contentTextStyle: TextStyle(color: lightTextPrimaryColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
        ),
      ),
    );
  }

  // Koyu tema
  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        surface: darkSurfaceColor,
        background: darkBackgroundColor,
        error: primaryColor,
        onBackground: darkTextPrimaryColor,
        onSurface: darkTextPrimaryColor,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackgroundColor,
        foregroundColor: darkTextPrimaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: darkTextPrimaryColor),
      ),
      cardTheme: CardTheme(
        elevation: 1, // Daha az gölge
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        color: darkCardColor, // Daha açık bir kart rengi ile kontrast artışı
        shadowColor: Colors.black38,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: darkTextPrimaryColor,
        displayColor: darkTextPrimaryColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
              vertical: 12, horizontal: 20), // Daha küçük padding
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(
              vertical: 6, horizontal: 12), // Daha küçük
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusSmall),
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: primaryColor,
        size: 22, // Daha küçük ikonlar
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.3);
        }),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Daha kompakt
        tileColor: darkCardColor,
        iconColor: primaryColor,
        textColor: darkTextPrimaryColor,
      ),
      dividerTheme: const DividerThemeData(
        color: darkDividerColor,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCardColor,
        contentTextStyle: TextStyle(color: darkTextPrimaryColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusSmall),
        ),
      ),
      // Tüm metin stillerinin rengini beyaz yap
      primaryTextTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white),
        displayLarge: TextStyle(color: Colors.white),
        displayMedium: TextStyle(color: Colors.white),
        displaySmall: TextStyle(color: Colors.white),
        headlineLarge: TextStyle(color: Colors.white),
        headlineMedium: TextStyle(color: Colors.white),
        headlineSmall: TextStyle(color: Colors.white),
        labelLarge: TextStyle(color: Colors.white),
        labelMedium: TextStyle(color: Colors.white),
        labelSmall: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
      ),
    );
  }
}
