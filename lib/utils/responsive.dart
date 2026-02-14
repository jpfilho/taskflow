import 'package:flutter/material.dart';

class Responsive {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  /// Altura da faixa acima do cabeçalho de colunas (tabela de atividades e linha de mês do Gantt).
  /// Deve ser igual em ambos os lados para o cabeçalho da tabela e o cabeçalho dos dias do Gantt
  /// iniciarem e terminarem exatamente na mesma altura.
  static const double kActivitiesHeaderTopHeight = 25.0;

  /// Altura do cabeçalho de colunas da tabela de atividades e da linha de dias do Gantt.
  static const double kActivitiesHeaderRowHeight = 50.0;

  // Verifica se é mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Usado para decisão pós-login: abrir tela de atalhos em vez da Programação.
  /// Breakpoint 768px (mobile/tablet estreito) vs desktop.
  static bool isMobileForHome(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  // Verifica se é tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  // Verifica se é desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  // Retorna o tipo de dispositivo
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return DeviceType.mobile;
    } else if (width < tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  // Retorna largura otimizada para tabela
  static double getTableWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return width; // Mobile: usa toda largura
    } else if (width < tabletBreakpoint) {
      return width * 0.6; // Tablet: 60% da largura
    } else {
      return 1200; // Desktop: largura fixa
    }
  }
}

enum DeviceType {
  mobile,
  tablet,
  desktop,
}












