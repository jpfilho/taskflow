import 'package:flutter/material.dart';

/// Modal seletor de período de datas padronizado para o TaskFlow Design System.
/// Renderiza o DateRangePicker em uma janela modal compacta, centralizada
/// e com proporções elegantes tanto para Web/Desktop quanto para Mobile.
Future<DateTimeRange?> showTFDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialDateRange,
  DateTime? firstDate,
  DateTime? lastDate,
  DateTime? currentDate,
  String? helpText,
  String? cancelText,
  String? confirmText,
  String? saveText,
  Locale? locale,
}) {
  return showDateRangePicker(
    context: context,
    initialDateRange: initialDateRange,
    firstDate: firstDate ?? DateTime(2020),
    lastDate: lastDate ?? DateTime(2030),
    currentDate: currentDate,
    helpText: helpText ?? 'Selecione o período',
    cancelText: cancelText ?? 'Cancelar',
    confirmText: confirmText ?? saveText ?? 'Confirmar',
    saveText: saveText ?? 'Salvar',
    locale: locale ?? const Locale('pt', 'BR'),
    builder: (context, child) {
      final media = MediaQuery.of(context);
      final isSmallScreen = media.size.width < 600;

      if (isSmallScreen) {
        return child!;
      }

      return Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 460,
            maxHeight: 580,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
        ),
      );
    },
  );
}
