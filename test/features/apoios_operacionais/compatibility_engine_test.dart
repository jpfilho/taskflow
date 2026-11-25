import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/features/apoios_operacionais/domain/engine/task_apoio_compatibility_engine.dart';
import 'package:task2026/features/apoios_operacionais/domain/enums/task_apoio_enums.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_periodo.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_requisito_recurso.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_solicitacao.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_tipo.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_vinculo.dart';
import 'package:task2026/models/task.dart';

Task _criarTask({
  required String id,
  required DateTime inicio,
  required DateTime fim,
  String status = 'PROG',
  List<String> locais = const ['SE A'],
  List<String> frotaIds = const [],
  String frota = '',
  List<String> executorIds = const [],
  List<GanttSegment> ganttSegments = const [],
  List<FrotaPeriod> frotaPeriods = const [],
}) {
  return Task(
    id: id,
    status: status,
    regional: 'REG',
    divisao: 'DIV',
    locais: locais,
    tipo: 'MANUT',
    tarefa: 'Task $id',
    frotaIds: frotaIds,
    frota: frota,
    executorIds: executorIds,
    coordenador: 'Coord',
    dataInicio: inicio,
    dataFim: fim,
    ganttSegments: ganttSegments,
    frotaPeriods: frotaPeriods,
  );
}

TaskApoioSolicitacao _criarSolicitacao({
  required DateTime inicio,
  required DateTime fim,
  TaskApoioStatus status = TaskApoioStatus.aceita,
  List<TaskApoioPeriodo> periodos = const [],
  TaskApoioRequisitoRecurso? requisitos,
}) {
  return TaskApoioSolicitacao(
    id: 'sol-1',
    taskSolicitanteId: 'task-p',
    taskSolicitanteTituloSnapshot: 'Principal',
    regionalSolicitanteId: 'r1',
    divisaoSolicitanteId: 'd1',
    regionalDestinoId: 'r2',
    divisaoDestinoId: 'd2',
    tipoApoioId: 'tipo-1',
    descricao: 'Apoio Munck',
    dataInicioSolicitada: inicio,
    dataFimSolicitada: fim,
    status: status,
    solicitanteUsuarioId: 'u1',
    periodos: periodos,
    requisitosRecursos: requisitos,
  );
}

void main() {
  final engine = TaskApoioCompatibilityEngine();

  group('Compatibilidade Temporal — Regras e Exemplo Obrigatório', () {
    test('Exemplo obrigatório 7.1: 23-27/11 com 23-24/11 e 26-27/11 => parcial, lacuna 25/11, 80%', () {
      // 5 dias exatos: [23/11 00:00, 28/11 00:00)
      final sol = _criarSolicitacao(
        inicio: DateTime.utc(2026, 11, 23, 0),
        fim: DateTime.utc(2026, 11, 28, 0),
      );
      final taskA = _criarTask(
        id: 'a',
        inicio: DateTime.utc(2026, 11, 23, 0),
        fim: DateTime.utc(2026, 11, 25, 0), // dias 23 e 24 (2 dias)
      );
      final taskB = _criarTask(
        id: 'b',
        inicio: DateTime.utc(2026, 11, 26, 0),
        fim: DateTime.utc(2026, 11, 28, 0), // dias 26 e 27 (2 dias)
      );

      final res = engine.avaliarSolicitacao(
        solicitacao: sol,
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: const TaskApoioVinculo(
              id: 'v1',
              taskPrincipalId: 'task-p',
              taskApoioId: 'a',
              taskPrincipalTituloSnapshot: 'Principal',
              taskApoioTituloSnapshot: 'A',
              createdBy: 'u1',
            ),
            taskApoio: taskA,
          ),
          TaskApoioVinculoComTask(
            vinculo: const TaskApoioVinculo(
              id: 'v2',
              taskPrincipalId: 'task-p',
              taskApoioId: 'b',
              taskPrincipalTituloSnapshot: 'Principal',
              taskApoioTituloSnapshot: 'B',
              createdBy: 'u1',
            ),
            taskApoio: taskB,
          ),
        ],
      );

      expect(res.statusTemporal, TaskApoioStatusCompatibilidadeTemporal.parcial);
      expect(res.percentualCobertura, 80.0);
      expect(res.lacunas.length, 1);
      expect(res.lacunas.first.inicio, DateTime.utc(2026, 11, 25, 0));
      expect(res.lacunas.first.fim, DateTime.utc(2026, 11, 26, 0));
    });

    test('Consolida intervalos sobrepostos sem dupla contabilização', () {
      final sol = _criarSolicitacao(
        inicio: DateTime.utc(2026, 11, 23, 8),
        fim: DateTime.utc(2026, 11, 23, 18), // 10h
      );
      final taskA = _criarTask(
        id: 'a',
        inicio: DateTime.utc(2026, 11, 23, 8),
        fim: DateTime.utc(2026, 11, 23, 14), // 6h
      );
      final taskB = _criarTask(
        id: 'b',
        inicio: DateTime.utc(2026, 11, 23, 10),
        fim: DateTime.utc(2026, 11, 23, 14), // 4h totalmente sobrepostas
      );

      final res = engine.avaliarSolicitacao(
        solicitacao: sol,
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: const TaskApoioVinculo(
              id: 'v1',
              taskPrincipalId: 'task-p',
              taskApoioId: 'a',
              taskPrincipalTituloSnapshot: 'P',
              taskApoioTituloSnapshot: 'A',
              createdBy: 'u1',
            ),
            taskApoio: taskA,
          ),
          TaskApoioVinculoComTask(
            vinculo: const TaskApoioVinculo(
              id: 'v2',
              taskPrincipalId: 'task-p',
              taskApoioId: 'b',
              taskPrincipalTituloSnapshot: 'P',
              taskApoioTituloSnapshot: 'B',
              createdBy: 'u1',
            ),
            taskApoio: taskB,
          ),
        ],
      );

      expect(res.statusTemporal, TaskApoioStatusCompatibilidadeTemporal.parcial);
      expect(res.percentualCobertura, 60.0); // 6h de 10h, nunca 100%!
    });

    test('Desconsidera atividade de apoio cancelada (CANC) e trata fuso horário corretamente', () {
      // 08:00-12:00 BRT (-03:00) == 11:00-15:00 UTC
      final inicioLocal = DateTime.parse('2026-11-23T08:00:00-03:00');
      final fimLocal = DateTime.parse('2026-11-23T12:00:00-03:00');
      final sol = _criarSolicitacao(inicio: inicioLocal, fim: fimLocal);

      final taskCanc = _criarTask(
        id: 'c',
        status: 'CANC',
        inicio: DateTime.utc(2026, 11, 23, 11),
        fim: DateTime.utc(2026, 11, 23, 15),
      );
      final taskValida = _criarTask(
        id: 'v',
        status: 'PROG',
        inicio: DateTime.utc(2026, 11, 23, 11),
        fim: DateTime.utc(2026, 11, 23, 15),
      );

      final resSemValida = engine.avaliarSolicitacao(
        solicitacao: sol,
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: const TaskApoioVinculo(
              id: 'vc',
              taskPrincipalId: 'task-p',
              taskApoioId: 'c',
              taskPrincipalTituloSnapshot: 'P',
              taskApoioTituloSnapshot: 'C',
              createdBy: 'u1',
            ),
            taskApoio: taskCanc,
          ),
        ],
      );
      expect(resSemValida.statusTemporal,
          TaskApoioStatusCompatibilidadeTemporal.semCobertura);

      final resComValida = engine.avaliarSolicitacao(
        solicitacao: sol,
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: const TaskApoioVinculo(
              id: 'vv',
              taskPrincipalId: 'task-p',
              taskApoioId: 'v',
              taskPrincipalTituloSnapshot: 'P',
              taskApoioTituloSnapshot: 'V',
              createdBy: 'u1',
            ),
            taskApoio: taskValida,
          ),
        ],
      );
      expect(resComValida.statusTemporal,
          TaskApoioStatusCompatibilidadeTemporal.integral);
      expect(resComValida.percentualCobertura, 100.0);
    });

    test('Gantt: ignora PLANEJAMENTO como execução e inclui DESLOCAMENTO para TRANSPORTE', () {
      final sol = _criarSolicitacao(
        inicio: DateTime.utc(2026, 11, 23, 8),
        fim: DateTime.utc(2026, 11, 23, 12),
      );
      final taskComGantt = _criarTask(
        id: 'g1',
        inicio: DateTime.utc(2026, 11, 23, 6),
        fim: DateTime.utc(2026, 11, 23, 18),
        ganttSegments: [
          GanttSegment(
            dataInicio: DateTime.utc(2026, 11, 23, 8),
            dataFim: DateTime.utc(2026, 11, 23, 10),
            label: 'Plan',
            tipo: 'ADM',
            tipoPeriodo: 'PLANEJAMENTO',
          ),
          GanttSegment(
            dataInicio: DateTime.utc(2026, 11, 23, 10),
            dataFim: DateTime.utc(2026, 11, 23, 12),
            label: 'Desloc',
            tipo: 'TRN',
            tipoPeriodo: 'DESLOCAMENTO',
          ),
        ],
      );

      final resManut = engine.avaliarSolicitacao(
        solicitacao: sol,
        tipoApoio: const TaskApoioTipo(
          id: 't1',
          codigo: 'FROTA_VEICULOS',
          nome: 'Frota',
        ),
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: const TaskApoioVinculo(
              id: 'v1',
              taskPrincipalId: 'task-p',
              taskApoioId: 'g1',
              taskPrincipalTituloSnapshot: 'P',
              taskApoioTituloSnapshot: 'G1',
              createdBy: 'u1',
            ),
            taskApoio: taskComGantt,
          ),
        ],
      );
      expect(resManut.statusTemporal,
          TaskApoioStatusCompatibilidadeTemporal.semCobertura);

      final resTransporte = engine.avaliarSolicitacao(
        solicitacao: sol,
        tipoApoio: const TaskApoioTipo(
          id: 't2',
          codigo: 'TRANSPORTE',
          nome: 'Transporte',
        ),
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: const TaskApoioVinculo(
              id: 'v1',
              taskPrincipalId: 'task-p',
              taskApoioId: 'g1',
              taskPrincipalTituloSnapshot: 'P',
              taskApoioTituloSnapshot: 'G1',
              createdBy: 'u1',
            ),
            taskApoio: taskComGantt,
          ),
        ],
      );
      expect(resTransporte.statusTemporal,
          TaskApoioStatusCompatibilidadeTemporal.parcial);
      expect(resTransporte.percentualCobertura, 50.0);
    });
  });

  group('Compatibilidade de Recursos e Apoios Compartilhados', () {
    test('Detecta recursos pendentes, incompatíveis, genéricos (não verificados) e compatíveis', () {
      final solReq = _criarSolicitacao(
        inicio: DateTime.utc(2026, 11, 23, 8),
        fim: DateTime.utc(2026, 11, 23, 12),
        requisitos: const TaskApoioRequisitoRecurso(
          tipoVeiculo: 'Munck',
          exigeVeiculo: true,
          exigeOperador: true,
        ),
      );

      final taskSemRecurso = _criarTask(
        id: 'r0',
        inicio: DateTime.utc(2026, 11, 23, 8),
        fim: DateTime.utc(2026, 11, 23, 12),
      );
      final sitPendente = engine.calcularSituacaoSolicitacao(
        solicitacao: solReq,
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: const TaskApoioVinculo(
              id: 'v0',
              taskPrincipalId: 'task-p',
              taskApoioId: 'r0',
              taskPrincipalTituloSnapshot: 'P',
              taskApoioTituloSnapshot: 'R0',
              createdBy: 'u1',
            ),
            taskApoio: taskSemRecurso,
          ),
        ],
      );
      expect(sitPendente.situacaoOperacional,
          TaskApoioSituacaoOperacional.programadaComRecursosPendentes);

      final taskIncompativel = _criarTask(
        id: 'r1',
        inicio: DateTime.utc(2026, 11, 23, 8),
        fim: DateTime.utc(2026, 11, 23, 12),
        frotaIds: const ['f1'],
        frota: 'Caminhonete 4x4',
        executorIds: const ['e1'],
      );
      final sitIncomp = engine.calcularSituacaoSolicitacao(
        solicitacao: solReq,
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: const TaskApoioVinculo(
              id: 'v1',
              taskPrincipalId: 'task-p',
              taskApoioId: 'r1',
              taskPrincipalTituloSnapshot: 'P',
              taskApoioTituloSnapshot: 'R1',
              createdBy: 'u1',
            ),
            taskApoio: taskIncompativel,
          ),
        ],
      );
      expect(sitIncomp.compatibilidade.statusRecursos,
          TaskApoioStatusCompatibilidadeRecurso.incompativel);

      final taskOk = _criarTask(
        id: 'r2',
        inicio: DateTime.utc(2026, 11, 23, 8),
        fim: DateTime.utc(2026, 11, 23, 12),
        frotaIds: const ['f2'],
        frota: 'Caminhão Munck 12t',
        executorIds: const ['e1'],
      );
      final sitOk = engine.calcularSituacaoSolicitacao(
        solicitacao: solReq,
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: const TaskApoioVinculo(
              id: 'v2',
              taskPrincipalId: 'task-p',
              taskApoioId: 'r2',
              taskPrincipalTituloSnapshot: 'P',
              taskApoioTituloSnapshot: 'R2',
              createdBy: 'u1',
            ),
            taskApoio: taskOk,
          ),
        ],
      );
      expect(sitOk.situacaoOperacional,
          TaskApoioSituacaoOperacional.programadaCompativel);

      // Solicitação genérica sem exigência de recurso
      final solGenerica = _criarSolicitacao(
        inicio: DateTime.utc(2026, 11, 23, 8),
        fim: DateTime.utc(2026, 11, 23, 12),
      );
      final sitGen = engine.calcularSituacaoSolicitacao(
        solicitacao: solGenerica,
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: const TaskApoioVinculo(
              id: 'v3',
              taskPrincipalId: 'task-p',
              taskApoioId: 'r2',
              taskPrincipalTituloSnapshot: 'P',
              taskApoioTituloSnapshot: 'R2',
              createdBy: 'u1',
            ),
            taskApoio: taskOk,
          ),
        ],
      );
      expect(sitGen.compatibilidade.statusRecursos,
          TaskApoioStatusCompatibilidadeRecurso.naoVerificado);
      expect(sitGen.situacaoOperacional,
          TaskApoioSituacaoOperacional.programadaComRecursosNaoVerificados);
    });

    test('Diferencia compartilhamento sucessivo (ok) de simultâneo em locais distintos (conflito)', () {
      final sol = _criarSolicitacao(
        inicio: DateTime.utc(2026, 11, 23, 8),
        fim: DateTime.utc(2026, 11, 23, 12),
      );
      final taskMunck = _criarTask(
        id: 'm1',
        inicio: DateTime.utc(2026, 11, 23, 8),
        fim: DateTime.utc(2026, 11, 23, 18),
        locais: const ['SE Norte'],
        frotaIds: const ['f-munck'],
        frota: 'Munck 01',
      );
      final taskMunckOutroLocal = _criarTask(
        id: 'm1',
        inicio: DateTime.utc(2026, 11, 23, 8),
        fim: DateTime.utc(2026, 11, 23, 18),
        locais: const ['SE Sul'],
        frotaIds: const ['f-munck'],
        frota: 'Munck 01',
      );

      final resConflito = engine.avaliarSolicitacao(
        solicitacao: sol,
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: TaskApoioVinculo(
              id: 'v1',
              taskPrincipalId: 'p1',
              taskApoioId: 'm1',
              taskPrincipalTituloSnapshot: 'Manut SE Norte',
              taskApoioTituloSnapshot: 'Munck 01',
              coberturaInicio: DateTime.utc(2026, 11, 23, 8),
              coberturaFim: DateTime.utc(2026, 11, 23, 12),
              createdBy: 'u1',
            ),
            taskApoio: taskMunck,
          ),
        ],
        outrosVinculosMesmasTasksApoio: [
          TaskApoioVinculoComTask(
            vinculo: TaskApoioVinculo(
              id: 'v2',
              taskPrincipalId: 'p2',
              taskApoioId: 'm1',
              taskPrincipalTituloSnapshot: 'Manut SE Sul',
              taskApoioTituloSnapshot: 'Munck 01',
              coberturaInicio: DateTime.utc(2026, 11, 23, 10),
              coberturaFim: DateTime.utc(2026, 11, 23, 14),
              createdBy: 'u2',
            ),
            taskApoio: taskMunckOutroLocal,
          ),
        ],
      );
      expect(resConflito.statusRecursos,
          TaskApoioStatusCompatibilidadeRecurso.conflitoCompartilhamento);
      expect(resConflito.alertasCompartilhamento, isNotEmpty);

      // Sucessivo (13h-17h) não gera conflito
      final resSucessivo = engine.avaliarSolicitacao(
        solicitacao: sol,
        vinculos: [
          TaskApoioVinculoComTask(
            vinculo: TaskApoioVinculo(
              id: 'v1',
              taskPrincipalId: 'p1',
              taskApoioId: 'm1',
              taskPrincipalTituloSnapshot: 'Manut SE Norte',
              taskApoioTituloSnapshot: 'Munck 01',
              coberturaInicio: DateTime.utc(2026, 11, 23, 8),
              coberturaFim: DateTime.utc(2026, 11, 23, 12),
              createdBy: 'u1',
            ),
            taskApoio: taskMunck,
          ),
        ],
        outrosVinculosMesmasTasksApoio: [
          TaskApoioVinculoComTask(
            vinculo: TaskApoioVinculo(
              id: 'v2',
              taskPrincipalId: 'p2',
              taskApoioId: 'm1',
              taskPrincipalTituloSnapshot: 'Manut SE Sul',
              taskApoioTituloSnapshot: 'Munck 01',
              coberturaInicio: DateTime.utc(2026, 11, 23, 13),
              coberturaFim: DateTime.utc(2026, 11, 23, 17),
              createdBy: 'u2',
            ),
            taskApoio: taskMunckOutroLocal,
          ),
        ],
      );
      expect(resSucessivo.alertasCompartilhamento, isEmpty);
    });
  });
}
