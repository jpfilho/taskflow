import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

enum AppTheme { light, dark, axia }

// StreamController para notificar mudanças nas cores personalizadas
class ColorThemeNotifier {
  static final ColorThemeNotifier _instance = ColorThemeNotifier._internal();
  factory ColorThemeNotifier() => _instance;
  ColorThemeNotifier._internal();

  final _colorChangeController = StreamController<String>.broadcast();
  
  Stream<String> get colorChangeStream => _colorChangeController.stream;
  
  void notifyColorChanged(String barType) {
    _colorChangeController.add(barType);
  }
  
  void dispose() {
    _colorChangeController.close();
  }
}

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

  // Salvar cor personalizada
  static Future<void> saveCustomColor(String key, Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, color.value);
      
      // Notificar mudança de cor
      if (key.contains('appbar')) {
        ColorThemeNotifier().notifyColorChanged('appbar');
      } else if (key.contains('sidebar')) {
        ColorThemeNotifier().notifyColorChanged('sidebar');
      } else if (key.contains('footbar')) {
        ColorThemeNotifier().notifyColorChanged('footbar');
      }
    } catch (e) {
      print('Erro ao salvar cor personalizada: $e');
    }
  }

  // Carregar cor personalizada
  static Future<Color?> loadCustomColor(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorValue = prefs.getInt(key);
      if (colorValue != null) {
        return Color(colorValue);
      }
    } catch (e) {
      print('Erro ao carregar cor personalizada: $e');
    }
    return null;
  }

  // Remover cor personalizada
  static Future<void> removeCustomColor(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      
      // Notificar mudança de cor
      if (key.contains('appbar')) {
        ColorThemeNotifier().notifyColorChanged('appbar');
      } else if (key.contains('sidebar')) {
        ColorThemeNotifier().notifyColorChanged('sidebar');
      } else if (key.contains('footbar')) {
        ColorThemeNotifier().notifyColorChanged('footbar');
      }
    } catch (e) {
      print('Erro ao remover cor personalizada: $e');
    }
  }

  // Obter cor de fundo para HeaderBar, Sidebar e Footbar
  static Future<Color> getBarBackgroundColor(AppTheme theme, {String? barType}) async {
    final key = barType != null ? '${barType}_background_color' : null;
    if (key != null) {
      final customColor = await loadCustomColor(key);
      if (customColor != null) return customColor;
    }
    
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
  static Future<Color> getBarTextColor(AppTheme theme, {String? barType}) async {
    final key = barType != null ? '${barType}_text_color' : null;
    if (key != null) {
      final customColor = await loadCustomColor(key);
      if (customColor != null) return customColor;
    }
    
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
  static Future<Color> getBarIconColor(AppTheme theme, {String? barType}) async {
    final key = barType != null ? '${barType}_icon_color' : null;
    if (key != null) {
      final customColor = await loadCustomColor(key);
      if (customColor != null) return customColor;
    }
    
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

  // Métodos síncronos para compatibilidade (usam valores padrão se não houver cor personalizada)
  static Color getBarBackgroundColorSync(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return const Color(0xFF1E3A5F);
      case AppTheme.dark:
        return const Color(0xFF0D1B2A);
      case AppTheme.axia:
        return axiaNavy;
    }
  }

  static Color getBarTextColorSync(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return Colors.white;
      case AppTheme.dark:
        return Colors.white;
      case AppTheme.axia:
        return axiaOffWhite;
    }
  }

  static Color getBarIconColorSync(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return Colors.white;
      case AppTheme.dark:
        return Colors.white;
      case AppTheme.axia:
        return axiaOffWhite;
    }
  }
}
