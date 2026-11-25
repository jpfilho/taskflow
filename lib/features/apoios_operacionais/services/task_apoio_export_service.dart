import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../domain/models/task_apoio_gerencial.dart';
import '../domain/models/task_apoio_situacao.dart';
import '../domain/models/task_apoio_solicitacao.dart';

/// Serviço de exportação Excel (.xlsx) para Apoios Operacionais (Fase 7).
/// Exporta exclusivamente os registros já filtrados e autorizados para o usuário,
/// registrando data de extração e filtros aplicados.
class TaskApoioExportService {
  const TaskApoioExportService._();

  static Uint8List gerarRelatorioExcelBytes({
    required List<TaskApoioSolicitacao> solicitacoesAutorizadas,
    required Map<String, TaskApoioSituacao> situacoesPorSolicitacao,
    required TaskApoioGerencialIndicadores indicadores,
    Map<String, String> nomesUnidades = const {},
    Map<String, String> nomesTipos = const {},
    String filtrosAplicados = 'Todos os registros autorizados',
  }) {
    final excel = Excel.createExcel();
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final agoraStr = fmt.format(DateTime.now());

    // 1. Aba Solicitações
    final sheetSol = excel['Solicitacoes'];
    excel.setDefaultSheet('Solicitacoes');

    sheetSol.appendRow(['Relatório de Solicitações de Apoio Operacional']);
    sheetSol.appendRow(['Extraído em: $agoraStr', 'Filtros: $filtrosAplicados']);
    sheetSol.appendRow([
      'ID',
      'Atividade Solicitante',
      'Unidade Solicitante',
      'Unidade Prestadora',
      'Tipo de Apoio',
      'Descrição',
      'Local',
      'Período Solicitado',
      'Período Acordado',
      'Status',
      'Criticidade',
      'Situação Operacional',
      'Cobertura (%)',
    ]);

    for (final s in solicitacoesAutorizadas) {
      final sit = situacoesPorSolicitacao[s.id];
      final perSol =
          '${fmt.format(s.dataInicioSolicitada.toLocal())} - ${fmt.format(s.dataFimSolicitada.toLocal())}';
      final perAcord = (s.dataInicioAcordada != null && s.dataFimAcordada != null)
          ? '${fmt.format(s.dataInicioAcordada!.toLocal())} - ${fmt.format(s.dataFimAcordada!.toLocal())}'
          : '-';
      sheetSol.appendRow([
        s.id,
        s.taskSolicitanteTituloSnapshot,
        nomesUnidades[s.divisaoSolicitanteId] ?? s.divisaoSolicitanteId,
        nomesUnidades[s.divisaoDestinoId] ?? s.divisaoDestinoId,
        nomesTipos[s.tipoApoioId] ?? s.tipoApoioId,
        s.descricao,
        s.locaisAtendimento ?? '-',
        perSol,
        perAcord,
        s.status.label,
        s.criticidade.label,
        sit?.situacaoOperacional.label ?? '-',
        sit != null
            ? '${sit.compatibilidade.percentualCobertura.toStringAsFixed(0)}%'
            : '-',
      ]);
    }

    // 2. Aba Pendências Críticas
    final sheetPend = excel['Pendencias_Criticas'];
    sheetPend.appendRow([
      'Relatório de Pendências Críticas — Reunião Semanal',
      'Extraído em: $agoraStr',
    ]);
    sheetPend.appendRow([
      'Atividade Afetada',
      'Apoio Necessário',
      'Situação / Motivo',
      'Unidade Responsável',
      'Prazo',
      'Providência',
    ]);
    for (final item in indicadores.itensReuniaoSemanal) {
      final s = item.solicitacao;
      sheetPend.appendRow([
        s.taskSolicitanteTituloSnapshot,
        s.descricao,
        item.situacao.situacaoOperacional.label,
        item.unidadeResponsavelNome,
        s.prazoResposta != null ? fmt.format(s.prazoResposta!.toLocal()) : '-',
        item.providenciaSugerida,
      ]);
    }

    // 3. Aba Gerencial Consolidado
    final sheetGer = excel['Gerencial_Consolidado'];
    sheetGer.appendRow([
      'Indicadores Gerenciais Consolidados',
      'Extraído em: $agoraStr',
    ]);
    sheetGer.appendRow(['Indicador', 'Valor']);
    void addMetric(String nome, Object valor) {
      sheetGer.appendRow([nome, '$valor']);
    }

    addMetric('Total de solicitações', indicadores.totalSolicitacoes);
    addMetric('Aguardando resposta', indicadores.aguardandoResposta);
    addMetric('Em negociação (contraproposta)', indicadores.emNegociacao);
    addMetric('Aceitas sem programação', indicadores.aceitasSemProgramacao);
    addMetric('Parcialmente programados', indicadores.parcialmenteProgramados);
    addMetric('Programados e compatíveis', indicadores.programadosCompativeis);
    addMetric('Essenciais em risco', indicadores.essenciaisEmRisco);
    addMetric('Recursos pendentes', indicadores.recursosPendentes);
    addMetric('Reconfirmação pendente', indicadores.reconfirmacaoPendente);
    addMetric('Prazo ultrapassado', indicadores.prazoUltrapassado);
    addMetric(
      'Cobertura temporal média',
      indicadores.coberturaTemporalMediaPercent != null
          ? '${indicadores.coberturaTemporalMediaPercent!.toStringAsFixed(1)}%'
          : 'Sem dados suficientes',
    );
    addMetric(
      'Tempo médio 1ª resposta',
      indicadores.tempoMedioPrimeiraRespostaHoras != null
          ? '${indicadores.tempoMedioPrimeiraRespostaHoras!.toStringAsFixed(1)} h'
          : 'Sem dados suficientes',
    );

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? const []);
  }
}
