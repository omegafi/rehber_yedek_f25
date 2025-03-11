import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Ana Temayı Oluştur (Açık Tema)
  static ThemeData lightTheme() {
    return ThemeData(
      // Ana Tema Rengi
      primaryColor: Colors.blue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
        primary: Colors.blue,
        secondary: Colors.teal,
        tertiary: Colors.amber,
        background: Colors.grey.shade50,
      ),

      // Scaffold Arka Plan Rengi
      scaffoldBackgroundColor: Colors.grey.shade100,

      // AppBar Teması
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Metin Teması
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32.0,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28.0,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 24.0,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20.0,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16.0,
          color: Colors.black87,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14.0,
          color: Colors.black87,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12.0,
          color: Colors.black54,
        ),
      ),

      // Buton Teması
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outline Buton Teması
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.blue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // İkon Buton Teması
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          padding: MaterialStateProperty.all(const EdgeInsets.all(8)),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textStyle: MaterialStateProperty.all(GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          )),
        ),
      ),

      // Card Teması
      cardTheme: CardTheme(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Input Dekorasyonu
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey.shade500,
        ),
      ),

      // Snackbar Teması
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        actionTextColor: Colors.white,
      ),

      // Divider Teması
      dividerTheme: const DividerThemeData(
        space: 24,
        thickness: 1,
        color: Colors.black12,
      ),
    );
  }

  // Koyu Tema (Kullanılmıyor)
  static ThemeData darkTheme() {
    return ThemeData.dark();
  }
}
