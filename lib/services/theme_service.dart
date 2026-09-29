import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../design_system/taskflow_design_system.dart';

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
  static const String _densityKey = 'ui_density';
  static AppTheme _currentTheme = AppTheme.light;
  static TFDensityMode _currentDensity = TFDensityMode.comfortable;

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

  // Carregar densidade salva (default: comfortable)
  static Future<TFDensityMode> loadDensity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final densityString = prefs.getString(_densityKey);
      if (densityString == null) {
        _currentDensity = TFDensityMode.comfortable;
        return _currentDensity;
      }
      switch (densityString) {
        case 'compact':
          _currentDensity = TFDensityMode.compact;
          break;
        case 'dense':
          _currentDensity = TFDensityMode.dense;
          break;
        case 'comfortable':
        default:
          _currentDensity = TFDensityMode.comfortable;
          break;
      }
      return _currentDensity;
    } catch (e) {
      print('Erro ao carregar densidade: $e');
      return TFDensityMode.comfortable;
    }
  }

  // Salvar densidade
  static Future<void> saveDensity(TFDensityMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_densityKey, mode.name);
      _currentDensity = mode;
    } catch (e) {
      print('Erro ao salvar densidade: $e');
    }
  }

  // Obter tema atual
  static AppTheme getCurrentTheme() => _currentTheme;

  // Obter densidade atual
  static TFDensityMode getCurrentDensity() => _currentDensity;

  // Obter ThemeData baseado no tema e densidade escolhidos
  static ThemeData getThemeData(AppTheme theme, {TFDensityMode? densityMode}) {
    final mode = densityMode ?? _currentDensity;
    final density = TFDensity.fromMode(mode);
    switch (theme) {
      case AppTheme.light:
        return _lightTheme(density);
      case AppTheme.dark:
        return _darkTheme(density);
      case AppTheme.axia:
        return _axiaTheme(density);
    }
  }

  static ThemeData _lightTheme(TFDensity density) =>
      TaskFlowTheme.light(customExtension: TaskFlowThemeExtension.light(customDensity: density));
  static ThemeData _darkTheme(TFDensity density) =>
      TaskFlowTheme.dark(customExtension: TaskFlowThemeExtension.dark(customDensity: density));
  static ThemeData _axiaTheme(TFDensity density) =>
      TaskFlowTheme.axia(customExtension: TaskFlowThemeExtension.axia(customDensity: density));

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
