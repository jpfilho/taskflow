import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { light, dark, axia }

class ThemeService {
  static const String _themeKey = 'app_theme';
  static AppTheme _currentTheme = AppTheme.light;

  // Cores da paleta Axia
  static const Color axiaBlue = Color(0xFF0000FF); // #0000FF
  static const Color axiaNavy = Color(0xFF0A003C); // #0A003C
  static const Color axiaOffWhite = Color(0xFFFAF5F0); // #FAF5F0
  static const Color axiaGray = Color(0xFFA0B4D2); // #A0B4D2
  static const Color axiaYellow = Color(0xFFF9B50B); // #F9B50B

  // Carregar tema salvo
  static Future<AppTheme> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? 0;
      _currentTheme = AppTheme.values[themeIndex];
      return _currentTheme;
    } catch (e) {
      print('Erro ao carregar tema: $e');
      return AppTheme.light;
    }
  }

  // Salvar tema
  static Future<void> saveTheme(AppTheme theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, theme.index);
      _currentTheme = theme;
    } catch (e) {
      print('Erro ao salvar tema: $e');
    }
  }

  // Obter tema atual
  static AppTheme getCurrentTheme() => _currentTheme;

  // Obter ThemeData baseado no tema escolhido
  static ThemeData getThemeData(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return _lightTheme();
      case AppTheme.dark:
        return _darkTheme();
      case AppTheme.axia:
        return _axiaTheme();
    }
  }

  // Tema Light (atual)
  static ThemeData _lightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
    );
  }

  // Tema Dark
  static ThemeData _darkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF121212),
    );
  }

  // Tema Axia
  static ThemeData _axiaTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: axiaOffWhite,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: axiaBlue,
        onPrimary: Colors.white,
        secondary: axiaNavy,
        onSecondary: Colors.white,
        tertiary: axiaGray,
        onTertiary: axiaNavy,
        error: Colors.red,
        onError: Colors.white,
        surface: axiaOffWhite,
        onSurface: axiaNavy,
        surfaceVariant: axiaGray.withOpacity(0.3),
        onSurfaceVariant: axiaNavy,
        outline: axiaGray,
        shadow: axiaNavy.withOpacity(0.3),
        inverseSurface: axiaNavy,
        onInverseSurface: axiaOffWhite,
        inversePrimary: axiaBlue,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: axiaNavy,
        foregroundColor: axiaOffWhite,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: axiaBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: axiaBlue,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: axiaGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: axiaGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: axiaBlue, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: axiaGray,
        thickness: 1,
      ),
    );
  }

  // Obter cor de destaque (para uso em widgets específicos)
  static Color getAccentColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return Colors.blue;
      case AppTheme.dark:
        return Colors.blueAccent;
      case AppTheme.axia:
        return axiaBlue;
    }
  }

  // Obter cor de fundo principal
  static Color getBackgroundColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return Colors.white;
      case AppTheme.dark:
        return const Color(0xFF121212);
      case AppTheme.axia:
        return axiaOffWhite;
    }
  }

  // Obter cor de texto principal
  static Color getTextColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return Colors.black87;
      case AppTheme.dark:
        return Colors.white;
      case AppTheme.axia:
        return axiaNavy;
    }
  }

  // Obter cor de fundo para HeaderBar, Sidebar e Footbar
  static Color getBarBackgroundColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return const Color(0xFF1E3A5F); // Azul escuro padrão
      case AppTheme.dark:
        return const Color(0xFF0D1B2A); // Azul muito escuro para dark
      case AppTheme.axia:
        return axiaNavy; // Azul-marinho Axia
    }
  }

  // Obter cor de texto para HeaderBar, Sidebar e Footbar
  static Color getBarTextColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return Colors.white;
      case AppTheme.dark:
        return Colors.white;
      case AppTheme.axia:
        return axiaOffWhite; // Off-white para contraste com navy
    }
  }

  // Obter cor de ícone para HeaderBar, Sidebar e Footbar
  static Color getBarIconColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return Colors.white;
      case AppTheme.dark:
        return Colors.white;
      case AppTheme.axia:
        return axiaOffWhite; // Off-white para contraste com navy
    }
  }

  // Obter cor de botão selecionado para Sidebar e Footbar
  static Color getBarSelectedColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return Colors.white.withOpacity(0.2);
      case AppTheme.dark:
        return Colors.white.withOpacity(0.3);
      case AppTheme.axia:
        return axiaBlue.withOpacity(0.3); // Azul Axia com transparência
    }
  }
}
