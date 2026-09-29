import 'package:flutter/material.dart';
import '../design_system/foundations/tf_density.dart';
import '../services/theme_service.dart';

class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.light;
  TFDensityMode _currentDensity = TFDensityMode.comfortable;
  bool _isLoading = true;

  AppTheme get currentTheme => _currentTheme;
  TFDensityMode get currentDensity => _currentDensity;
  bool get isLoading => _isLoading;
  ThemeData get themeData => ThemeService.getThemeData(_currentTheme, densityMode: _currentDensity);

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _isLoading = true;
    notifyListeners();
    
    _currentTheme = await ThemeService.loadTheme();
    _currentDensity = await ThemeService.loadDensity();
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

  Future<void> setDensity(TFDensityMode density) async {
    if (_currentDensity != density) {
      _currentDensity = density;
      await ThemeService.saveDensity(density);
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

  String getDensityName(TFDensityMode density) {
    switch (density) {
      case TFDensityMode.comfortable:
        return 'Confortável';
      case TFDensityMode.compact:
        return 'Compacta';
      case TFDensityMode.dense:
        return 'Densa';
    }
  }

  String getDensityDescription(TFDensityMode density) {
    switch (density) {
      case TFDensityMode.comfortable:
        return 'Mais espaçamento. Padrão do sistema.';
      case TFDensityMode.compact:
        return 'Ideal para notebooks (14" a 15.6").';
      case TFDensityMode.dense:
        return 'Máxima informação em telas desktop.';
    }
  }
}
