import 'package:flutter/material.dart';

enum SituacaoPrazo {
  atrasada,
  venceHoje,
  venceEmAte7Dias,
  noPrazo,
  concluidaOuCancelada
}

class DemandaPrazoHelper {
  static SituacaoPrazo obterSituacao(DateTime prazo, String status) {
    if (status == 'Concluída' || status == 'Cancelada') {
      return SituacaoPrazo.concluidaOuCancelada;
    }

    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final prazoSemHora = DateTime(prazo.year, prazo.month, prazo.day);

    if (prazoSemHora.isBefore(hojeSemHora)) {
      return SituacaoPrazo.atrasada;
    } else if (prazoSemHora.isAtSameMomentAs(hojeSemHora)) {
      return SituacaoPrazo.venceHoje;
    } else {
      final diferencaDias = prazoSemHora.difference(hojeSemHora).inDays;
      if (diferencaDias > 0 && diferencaDias <= 7) {
        return SituacaoPrazo.venceEmAte7Dias;
      }
    }

    return SituacaoPrazo.noPrazo;
  }

  static Color obterCorSituacao(SituacaoPrazo situacao) {
    switch (situacao) {
      case SituacaoPrazo.atrasada:
        return Colors.red;
      case SituacaoPrazo.venceHoje:
        return Colors.orange;
      case SituacaoPrazo.venceEmAte7Dias:
        return Colors.amber;
      case SituacaoPrazo.noPrazo:
        return Colors.green;
      case SituacaoPrazo.concluidaOuCancelada:
        return Colors.grey;
    }
  }

  static String obterTexto(SituacaoPrazo situacao, DateTime prazo) {
    final formatado = "${prazo.day.toString().padLeft(2, '0')}/${prazo.month.toString().padLeft(2, '0')}/${prazo.year}";
    switch (situacao) {
      case SituacaoPrazo.atrasada:
        return "Atrasada ($formatado)";
      case SituacaoPrazo.venceHoje:
        return "Vence Hoje ($formatado)";
      case SituacaoPrazo.venceEmAte7Dias:
        return "Vence em até 7 dias ($formatado)";
      case SituacaoPrazo.noPrazo:
        return "Prazo: $formatado";
      case SituacaoPrazo.concluidaOuCancelada:
        return "Finalizada ($formatado)";
    }
  }
}
