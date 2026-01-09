import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.light;
  bool _isLoading = true;

  AppTheme get currentTheme => _currentTheme;
  bool get isLoading => _isLoading;
  ThemeData get themeData => ThemeService.getThemeData(_currentTheme);

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _isLoading = true;
    notifyListeners();
    
    _currentTheme = await ThemeService.loadTheme();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setTheme(AppTheme theme) async {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      await ThemeService.saveTheme(theme);
      notifyListeners();
    }
  }

  String getThemeName(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return 'Claro';
      case AppTheme.dark:
        return 'Escuro';
      case AppTheme.axia:
        return 'Axia';
    }
  }
}
