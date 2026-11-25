import 'package:intl/intl.dart';

import '../../domain/enums/task_apoio_enums.dart';
import '../../domain/models/task_apoio_situacao.dart';
import '../../domain/models/task_apoio_solicitacao.dart';

/// Utilitários de apresentação humana para o módulo de Apoios Operacionais.
/// Garante ausência de UUIDs crus, ocultação de horários 00:00 quando representam
/// apenas datas e mensagens objetivas para gestores e programadores.
class TaskApoioFormatters {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final DateFormat _fmtData = DateFormat('dd/MM/yyyy');
  static final DateFormat _fmtDiaMes = DateFormat('dd/MM');
  static final DateFormat _fmtDataHora = DateFormat('dd/MM HH:mm');

  static bool isUuid(String? value) =>
      value != null && _uuidRegex.hasMatch(value.trim());

  static DateTime inicioVigente(TaskApoioSolicitacao sol) =>
      sol.dataInicioAcordada ?? sol.dataInicioSolicitada;

  static DateTime fimVigente(TaskApoioSolicitacao sol) =>
      sol.dataFimAcordada ?? sol.dataFimSolicitada;

  /// Formata intervalo omitindo `00:00` quando representar apenas datas.
  static String formatarPeriodoHumano(DateTime inicio, DateTime fim) {
    final ini = inicio.toLocal();
    final f = fim.toLocal();
    final iniDiaInteiro = ini.hour == 0 && ini.minute == 0;
    final fimDiaInteiro = (f.hour == 0 && f.minute == 0) ||
        (f.hour == 23 && f.minute >= 59);

    if (iniDiaInteiro && fimDiaInteiro) {
      final mesmoDia = ini.year == f.year &&
          ini.month == f.month &&
          ini.day == f.day;
      if (mesmoDia) return _fmtData.format(ini);

      final mesmoMesAno = ini.year == f.year && ini.month == f.month;
      if (mesmoMesAno) {
        return '${DateFormat('dd').format(ini)} a ${_fmtDiaMes.format(f)}';
      }
      return '${_fmtDiaMes.format(ini)} a ${_fmtDiaMes.format(f)}';
    }
    return '${_fmtDataHora.format(ini)} a ${_fmtDataHora.format(f)}';
  }

  static final RegExp _localToStringRegex = RegExp(
    r'Local\([^)]*?\blocal:\s*([^,)]+)',
  );

  /// Extrai apenas os nomes dos locais caso o texto salvo tenha `Local(id: ..., local: NOME, ...)`.
  static String formatarLocaisAtendimento(String? raw) {
    if (raw == null) return '';
    final texto = raw.trim();
    if (texto.isEmpty) return '';
    if (!texto.contains('Local(')) return texto;
    final matches = _localToStringRegex
        .allMatches(texto)
        .map((m) => m.group(1)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    if (matches.isNotEmpty) {
      return matches.join(', ');
    }
    return texto;
  }

  /// Resolve nome amigável para uma unidade organizacional sem jamais expor UUID.
  static String formatarUnidade({
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
    required Map<String, String> nomesUnidades,
    bool omitirRegional = false,
  }) {
    String? resolver(String? id) {
      if (id == null || id.trim().isEmpty) return null;
      final nome = nomesUnidades[id]?.trim();
      if (nome != null && nome.isNotEmpty && !isUuid(nome)) return nome;
      if (!isUuid(id)) return id.trim();
      return null;
    }

    final div = resolver(divisaoId);
    final reg = omitirRegional ? null : resolver(regionalId);
    final seg = resolver(segmentoId);

    final partes = <String>[
      if (div != null) div,
      if (reg != null) reg,
      if (seg != null) seg,
    ];
    if (partes.isEmpty) return 'Unidade não identificada';
    return partes.join(' • ');
  }

  /// Mensagem objetiva de pendência/compatibilidade para exibição na UI.
  static String formatarResumoCompatibilidade(
    TaskApoioSolicitacao sol,
    TaskApoioSituacao? sit,
  ) {
    if (sit == null) {
      return 'Aguardando avaliação operacional.';
    }
    final comp = sit.compatibilidade;
    if (comp.lacunas.isNotEmpty) {
      final l = comp.lacunas.first;
      return 'Apoio ainda não programado para ${formatarPeriodoHumano(l.inicio, l.fim)}.';
    }
    if (sit.situacaoOperacional ==
        TaskApoioSituacaoOperacional.aceitaSemProgramacao) {
      return 'Apoio ainda não programado para ${formatarPeriodoHumano(inicioVigente(sol), fimVigente(sol))}.';
    }
    if (comp.statusRecursos == TaskApoioStatusCompatibilidadeRecurso.naoVerificado) {
      return 'Recursos ainda não detalhados.';
    }
    if (comp.statusRecursos == TaskApoioStatusCompatibilidadeRecurso.incompativel) {
      return 'Recursos alocados divergem dos requisitos solicitados.';
    }
    if (comp.statusRecursos == TaskApoioStatusCompatibilidadeRecurso.pendente) {
      return 'Aguardando alocação completa de recursos na atividade de apoio.';
    }
    if (comp.statusRecursos ==
        TaskApoioStatusCompatibilidadeRecurso.conflitoCompartilhamento) {
      return 'Conflito de compartilhamento de recurso detectado.';
    }
    if (sit.situacaoOperacional ==
        TaskApoioSituacaoOperacional.programadaCompativel) {
      return 'Programado com cobertura integral (${comp.percentualCobertura.toStringAsFixed(0)}%).';
    }
    return comp.resumoExplicativo;
  }

  /// Retorna `(proximaProvidencia, responsavel)` coerentes com o estado real.
  static (String, String) proximaProvidencia(
    TaskApoioSolicitacao sol,
    TaskApoioSituacao? sit,
  ) {
    switch (sol.status) {
      case TaskApoioStatus.pendente:
        return ('Analisar viabilidade e responder solicitação', 'Unidade prestadora');
      case TaskApoioStatus.emAnalise:
        return ('Concluir análise (aceitar, contrapropor ou recusar)', 'Unidade prestadora');
      case TaskApoioStatus.contraproposta:
        return ('Avaliar e responder contraproposta de período', 'Unidade solicitante');
      case TaskApoioStatus.recusada:
        return ('Solicitação encerrada por recusa', 'Nenhuma providência pendente');
      case TaskApoioStatus.cancelada:
        return ('Solicitação cancelada', 'Nenhuma providência pendente');
      case TaskApoioStatus.aceita:
        final op = sit?.situacaoOperacional;
        if (op == TaskApoioSituacaoOperacional.aceitaSemProgramacao) {
          return ('Criar ou vincular atividade de apoio programada', 'Unidade prestadora');
        }
        if (op == TaskApoioSituacaoOperacional.parcialmenteProgramada ||
            op == TaskApoioSituacaoOperacional.programadaComIncompatibilidade ||
            op == TaskApoioSituacaoOperacional.programadaComRecursosPendentes) {
          return ('Ajustar período ou alocar recursos faltantes', 'Unidade prestadora');
        }
        if (op == TaskApoioSituacaoOperacional.emAndamento) {
          return ('Acompanhar execução até conclusão', 'Unidade prestadora');
        }
        if (op == TaskApoioSituacaoOperacional.concluida) {
          return ('Atendimento concluído', 'Nenhuma providência pendente');
        }
        return ('Acompanhar programação confirmada', 'Unidades envolvidas');
      case TaskApoioStatus.desconhecido:
        return ('Verificar situação da solicitação', 'Unidade responsável');
    }
  }
}
