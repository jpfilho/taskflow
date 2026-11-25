import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/apoios_operacionais/data/repositories/task_apoio_offline_store.dart';
import 'package:task2026/features/apoios_operacionais/domain/engine/task_apoio_compatibility_engine.dart';
import 'package:task2026/features/apoios_operacionais/domain/enums/task_apoio_enums.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_compatibilidade.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_gerencial.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_situacao.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_solicitacao.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_vinculo.dart';
import 'package:task2026/features/apoios_operacionais/presentation/task_apoio_ui_controller.dart';
import 'package:task2026/features/apoios_operacionais/presentation/views/apoios_gerencial_dashboard_view.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/gantt_integrado_apoios_widget.dart';
import 'package:task2026/features/apoios_operacionais/services/task_apoio_export_service.dart';
import 'package:task2026/features/apoios_operacionais/services/task_apoio_gerencial_calculator.dart';
import 'package:task2026/models/task.dart';

Task _mkTask(String id, String titulo, DateTime ini, DateTime fim, String div) {
  return Task(
    id: id,
    tarefa: titulo,
    dataInicio: ini,
    dataFim: fim,
    status: 'PROG',
    tipo: 'Manutenção',
    coordenador: 'Coord',
    regional: 'Reg 1',
    divisao: div,
    regionalId: 'reg-1',
    divisaoId: div,
  );
}

void main() {
  group('Fase 7 — Gantt Integrado, Indicadores Gerenciais e Escalabilidade', () {
    test('TaskApoioGerencialCalculator trata falta de base como null (Sem dados suficientes) e evita dupla contagem', () {
      final now = DateTime.now().toUtc();
      final t1 = _mkTask('t-1', 'Manutencao SE', now, now.add(const Duration(days: 5)), 'div-manut');
      final s1 = TaskApoioSolicitacao(
        id: 's-1',
        taskSolicitanteId: 't-1',
        taskSolicitanteTituloSnapshot: 'Manutencao SE',
        regionalSolicitanteId: 'reg-1',
        divisaoSolicitanteId: 'div-manut',
        regionalDestinoId: 'reg-1',
        divisaoDestinoId: 'div-frota',
        tipoApoioId: 'tipo-1',
        criticidade: TaskApoioCriticidade.essencial,
        descricao: 'Munck',
        dataInicioSolicitada: now,
        dataFimSolicitada: now.add(const Duration(days: 5)),
        status: TaskApoioStatus.aceita,
        solicitanteUsuarioId: 'u-1',
        createdAt: now.subtract(const Duration(hours: 4)),
      );
      final sit1 = TaskApoioSituacao(
        solicitacaoId: 's-1',
        statusSolicitacao: TaskApoioStatus.aceita,
        situacaoOperacional: TaskApoioSituacaoOperacional.parcialmenteProgramada,
        qtdVinculosAtivos: 2,
        compatibilidade: TaskApoioCompatibilidade(
          statusTemporal: TaskApoioStatusCompatibilidadeTemporal.parcial,
          statusRecursos: TaskApoioStatusCompatibilidadeRecurso.pendente,
          percentualCobertura: 80.0,
          duracaoNecessaria: const Duration(days: 5),
          duracaoCoberta: const Duration(days: 4),
          lacunas: [
            TaskApoioIntervalo(
              inicio: now.add(const Duration(days: 2)),
              fim: now.add(const Duration(days: 3)),
            ),
          ],
          resumoExplicativo: 'Cobertura parcial 80%',
        ),
      );

      final ind = TaskApoioGerencialCalculator.calcular(
        solicitacoes: [s1],
        situacoesPorSolicitacao: {'s-1': sit1},
        tasksPorId: {'t-1': t1},
        divisaoAtualId: 'div-manut',
        perspectiva: TaskApoioGerencialPerspectiva.solicitante,
      );

      expect(ind.totalSolicitacoes, 1);
      expect(ind.parcialmenteProgramados, 1);
      expect(ind.essenciaisEmRisco, 1);
      expect(ind.atividadesPrincipaisAfetadas, 1);
      expect(ind.coberturaTemporalMediaPercent, 80.0);
      expect(ind.tempoMedioPrimeiraRespostaHoras, isNull);
      expect(ind.taxaAtendimentoNoPrazoPercent, isNull);
      expect(ind.itensReuniaoSemanal, hasLength(1));

      final bytes = TaskApoioExportService.gerarRelatorioExcelBytes(
        solicitacoesAutorizadas: [s1],
        situacoesPorSolicitacao: {'s-1': sit1},
        indicadores: ind,
      );
      expect(bytes, isNotEmpty);
    });

    test('Benchmark de escalabilidade: 1.000 atividades e 10.000 solicitações em memória', () {
      final now = DateTime.now().toUtc();
      final tasks = <String, Task>{};
      for (int i = 0; i < 1000; i++) {
        tasks['t-$i'] = _mkTask(
          't-$i',
          'Atividade $i',
          now.add(Duration(days: i % 30)),
          now.add(Duration(days: (i % 30) + 2)),
          'div-manut',
        );
      }

      final sols = <TaskApoioSolicitacao>[];
      final sits = <String, TaskApoioSituacao>{};
      for (int i = 0; i < 10000; i++) {
        final sid = 's-$i';
        final tid = 't-${i % 1000}';
        sols.add(
          TaskApoioSolicitacao(
            id: sid,
            taskSolicitanteId: tid,
            taskSolicitanteTituloSnapshot: 'Atividade ${i % 1000}',
            regionalSolicitanteId: 'reg-1',
            divisaoSolicitanteId: 'div-manut',
            regionalDestinoId: 'reg-1',
            divisaoDestinoId: 'div-frota',
            tipoApoioId: 'tipo-${i % 5}',
            descricao: 'Apoio $i',
            dataInicioSolicitada: now,
            dataFimSolicitada: now.add(const Duration(days: 2)),
            status: TaskApoioStatus.aceita,
            solicitanteUsuarioId: 'u-1',
            createdAt: now,
          ),
        );
        sits[sid] = TaskApoioSituacao(
          solicitacaoId: sid,
          statusSolicitacao: TaskApoioStatus.aceita,
          situacaoOperacional: i % 3 == 0
              ? TaskApoioSituacaoOperacional.parcialmenteProgramada
              : TaskApoioSituacaoOperacional.programadaCompativel,
          qtdVinculosAtivos: 1,
          compatibilidade: const TaskApoioCompatibilidade(
            statusTemporal: TaskApoioStatusCompatibilidadeTemporal.integral,
            statusRecursos: TaskApoioStatusCompatibilidadeRecurso.compativel,
            percentualCobertura: 100,
            duracaoNecessaria: Duration(hours: 8),
            duracaoCoberta: Duration(hours: 8),
            resumoExplicativo: 'OK',
          ),
        );
      }

      final sw = Stopwatch()..start();
      final ind = TaskApoioGerencialCalculator.calcular(
        solicitacoes: sols,
        situacoesPorSolicitacao: sits,
        tasksPorId: tasks,
      );
      sw.stop();

      expect(ind.totalSolicitacoes, 10000);
      // Cálculo de 10.000 solicitações deve ser sub-segundo (< 1000 ms)
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    testWidgets('GanttIntegradoApoiosWidget e ApoiosGerencialDashboardView renderizam em Desktop e Mobile Escuro sem overflow', (tester) async {
      final ctrl = TaskApoioUiController(
        offlineStore: TaskApoioOfflineStore(),
      );
      await tester.runAsync(ctrl.ativarModoDemonstracaoDev);
      final sols = await tester.runAsync(() => ctrl.service.buscarSolicitacoes());
      final sits = <String, TaskApoioSituacao>{};
      for (final s in sols!) {
        sits[s.id] = await tester.runAsync(() => ctrl.avaliarSituacao(s)) as TaskApoioSituacao;
      }

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: TaskFlowTheme.light(),
          home: Scaffold(
            body: GanttIntegradoApoiosWidget(
              controller: ctrl,
              atividadesPrincipais: ctrl.tasksConhecidas.values.take(3).toList(),
              usuarioAtualId: 'demo-user',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Atividade principal'), findsOneWidget);
      expect(find.text('Lacuna / Incompatível'), findsOneWidget);

      String? clicado;
      await tester.pumpWidget(
        MaterialApp(
          theme: TaskFlowTheme.dark(),
          home: Scaffold(
            body: ApoiosGerencialDashboardView(
              controller: ctrl,
              solicitacoes: sols,
              situacoes: sits,
              usuarioAtualId: 'demo-user',
              onSelecionarIndicador: (c) => clicado = c,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Essenciais em risco'));
      await tester.pump();
      expect(clicado, 'emRisco');
    });

    test('Vínculo aguardando confirmação não compõe cobertura operacional', () {
      final engine = TaskApoioCompatibilityEngine();
      final ini = DateTime(2026, 12, 1, 8);
      final fim = DateTime(2026, 12, 1, 17);
      final sol = TaskApoioSolicitacao(
        id: 'sol-wait-1',
        taskSolicitanteId: 't-princ',
        taskSolicitanteTituloSnapshot: 'Principal',
        regionalSolicitanteId: 'reg-1',
        divisaoSolicitanteId: 'div-a',
        regionalDestinoId: 'reg-1',
        divisaoDestinoId: 'div-b',
        tipoApoioId: 'tipo-1',
        descricao: 'Munck',
        dataInicioSolicitada: ini,
        dataFimSolicitada: fim,
        solicitanteUsuarioId: 'u1',
        status: TaskApoioStatus.aceita,
      );
      final taskApoio = _mkTask('apoio-wait', 'Apoio não confirmado', ini, fim, 'div-b');
      final vincAguardando = TaskApoioVinculo(
        id: 'v-wait',
        solicitacaoId: sol.id,
        taskPrincipalId: sol.taskSolicitanteId,
        taskApoioId: taskApoio.id,
        taskPrincipalTituloSnapshot: sol.taskSolicitanteTituloSnapshot,
        taskApoioTituloSnapshot: taskApoio.tarefa,
        statusConfirmacao: TaskApoioStatusConfirmacaoVinculo.aguardandoConfirmacao,
        createdBy: 'u1',
      );
      final compWait = engine.avaliarSolicitacao(
        solicitacao: sol,
        vinculos: [TaskApoioVinculoComTask(vinculo: vincAguardando, taskApoio: taskApoio)],
      );
      expect(compWait.percentualCobertura, 0);
      expect(compWait.statusTemporal, TaskApoioStatusCompatibilidadeTemporal.semCobertura);

      final compConf = engine.avaliarSolicitacao(
        solicitacao: sol,
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: vincAguardando.copyWith(
              statusConfirmacao: TaskApoioStatusConfirmacaoVinculo.confirmado,
            ),
            taskApoio: taskApoio,
          ),
        ],
      );
      expect(compConf.percentualCobertura, 100);
    });
  });
}
