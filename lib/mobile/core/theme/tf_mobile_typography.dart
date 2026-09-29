import 'package:flutter/material.dart';

/// Escala tipográfica oficial do TaskFlow Mobile.
/// Regra estrita: Nenhum texto operacional ou informativo inferior a 11px.
abstract class TFMobileTypography {
  /// Título de telas e cabeçalhos principais (Display: 24sp / line-height 32)
  static const TextStyle display = TextStyle(
    fontSize: 24.0,
    height: 1.33,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  /// Títulos de cards, seções e destaques de tarefas (Title Large: 18sp / line-height 24)
  static const TextStyle titleLarge = TextStyle(
    fontSize: 18.0,
    height: 1.33,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// Títulos de subseções, nomes de ativos e grupos (Title Medium: 16sp / line-height 22)
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16.0,
    height: 1.38,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  /// Texto de corpo principal, mensagens e entradas de texto (Body Large: 16sp / line-height 24)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16.0,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  /// Texto de corpo secundário, descrições e observações (Body Medium: 14sp / line-height 20)
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14.0,
    height: 1.43,
    fontWeight: FontWeight.w400,
  );

  /// Rótulos de chips de status, badges, botões e tabs (Label: 12sp / line-height 16)
  static const TextStyle label = TextStyle(
    fontSize: 12.0,
    height: 1.33,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// Rótulos de metadados, carimbos de data/hora (Caption: 11sp / line-height 14)
  /// Mínimo absoluto permitido no sistema.
  static const TextStyle caption = TextStyle(
    fontSize: 11.0,
    height: 1.27,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );
}
