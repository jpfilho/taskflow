import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/features/apoios_operacionais/domain/enums/task_apoio_enums.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_historico.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_periodo.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_requisito_recurso.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_situacao.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_solicitacao.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_tipo.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_vinculo.dart';
import 'package:task2026/features/apoios_operacionais/domain/rules/task_apoio_state_machine.dart';
import 'package:task2026/features/apoios_operacionais/domain/validators/task_apoio_validator.dart';

void main() {
  group('Models e Serialização', () {
    test('TaskApoioTipo serializa e desserializa JSON corretamente', () {
      const tipo = TaskApoioTipo(
        id: 't1',
        codigo: 'FROTA_VEICULOS',
        nome: 'Frota e veículos',
        exigeRecursoFrota: true,
        ordem: 1,
      );
      final roundtrip = TaskApoioTipo.fromJson(tipo.toJson());
      expect(roundtrip, equals(tipo));
      expect(roundtrip.exigeRecursoFrota, isTrue);
      expect(roundtrip.exigeRecursoEquipe, isFalse);
    });

    test('Enums tratam estados conhecidos e desconhecidos com segurança', () {
      expect(TaskApoioStatus.fromDb('PENDENTE'), TaskApoioStatus.pendente);
      expect(TaskApoioStatus.fromDb('urgente_invalido'), TaskApoioStatus.desconhecido);
      expect(TaskApoioPrioridade.fromDb('URGENTE'), TaskApoioPrioridade.urgente);
      expect(TaskApoioPrioridade.fromDb('X'), TaskApoioPrioridade.desconhecido);
      expect(TaskApoioCriticidade.fromDb('ESSENCIAL'), TaskApoioCriticidade.essencial);
      expect(TaskApoioCriticidade.fromDb(null), TaskApoioCriticidade.desconhecido);
    });

    test('TaskApoioSolicitacao preserva períodos solicitados quando contraproposta não foi aceita', () {
      final sol = TaskApoioSolicitacao(
        id: 's1',
        taskSolicitanteId: 'task-1',
        taskSolicitanteTituloSnapshot: 'Manutenção SE',
        regionalSolicitanteId: 'r1',
        divisaoSolicitanteId: 'd1',
        regionalDestinoId: 'r2',
        divisaoDestinoId: 'd2',
        tipoApoioId: 't1',
        prioridade: TaskApoioPrioridade.urgente,
        descricao: 'Munck',
        dataInicioSolicitada: DateTime.utc(2026, 11, 23, 8),
        dataFimSolicitada: DateTime.utc(2026, 11, 27, 17),
        contrapropostaInicio: DateTime.utc(2026, 11, 24, 8),
        contrapropostaFim: DateTime.utc(2026, 11, 28, 17),
        status: TaskApoioStatus.contraproposta,
        solicitanteUsuarioId: 'u1',
        requisitosRecursos: const TaskApoioRequisitoRecurso(
          tipoVeiculo: 'Munck',
          exigeVeiculo: true,
          exigeOperador: true,
        ),
      );

      final json = sol.toJson();
      final decoded = TaskApoioSolicitacao.fromJson(json);

      expect(decoded.prioridade, TaskApoioPrioridade.urgente);
      expect(decoded.periodosNecessidadeVigentes.first.dataInicio,
          DateTime.utc(2026, 11, 23, 8));
      expect(decoded.requisitosRecursos?.tipoVeiculo, 'Munck');
    });

    test('TaskApoioVinculo, Periodo, Historico e Resumo fazem roundtrip JSON', () {
      final periodo = TaskApoioPeriodo(
        id: 'p1',
        solicitacaoId: 's1',
        origemPeriodo: TaskApoioOrigemPeriodo.solicitacao,
        tipoPeriodo: TaskApoioTipoPeriodo.descontinuo,
        dataInicio: DateTime.utc(2026, 11, 23, 8),
        dataFim: DateTime.utc(2026, 11, 23, 12),
      );
      expect(TaskApoioPeriodo.fromJson(periodo.toJson()), equals(periodo));

      final vinculo = TaskApoioVinculo(
        id: 'v1',
        solicitacaoId: 's1',
        taskPrincipalId: 't1',
        taskApoioId: 't2',
        taskPrincipalTituloSnapshot: 'Principal',
        taskApoioTituloSnapshot: 'Apoio',
        createdBy: 'u1',
      );
      expect(TaskApoioVinculo.fromJson(vinculo.toJson()), equals(vinculo));

      final hist = TaskApoioHistorico(
        id: 'h1',
        solicitacaoId: 's1',
        evento: 'SOLICITACAO_CRIADA',
        createdAt: DateTime.utc(2026, 11, 17, 10),
      );
      expect(TaskApoioHistorico.fromJson(hist.toJson()), equals(hist));

      final resumo = TaskApoioResumo.fromViewJson({
        'task_id': 't1',
        'total_solicitacoes': 2,
        'qtd_aguardando_resposta': 1,
        'qtd_essenciais_pendentes': 1,
        'situacao_integrada': 'AGUARDANDO_ESSENCIAL',
      });
      expect(resumo.situacaoGerencial,
          TaskApoioSituacaoGerencial.aguardandoConfirmacaoEssencial);
    });

    test('Validadores rejeitam datas invertidas, auto-vínculo e campos vazios', () {
      final solInvalida = TaskApoioSolicitacao(
        id: 's1',
        taskSolicitanteTituloSnapshot: '',
        regionalSolicitanteId: '',
        divisaoSolicitanteId: 'd1',
        regionalDestinoId: 'r2',
        divisaoDestinoId: 'd2',
        tipoApoioId: '',
        descricao: '',
        dataInicioSolicitada: DateTime.utc(2026, 11, 25),
        dataFimSolicitada: DateTime.utc(2026, 11, 23),
        solicitanteUsuarioId: '',
      );
      expect(TaskApoioValidator.validarSolicitacao(solInvalida).length,
          greaterThanOrEqualTo(5));

      const vincInvalido = TaskApoioVinculo(
        id: 'v1',
        taskPrincipalId: 't1',
        taskApoioId: 't1',
        taskPrincipalTituloSnapshot: 'A',
        taskApoioTituloSnapshot: 'A',
        createdBy: '',
      );
      expect(TaskApoioValidator.validarVinculo(vincInvalido).length,
          greaterThanOrEqualTo(2));
    });
  });

  group('Máquina de Estados', () {
    test('Bloqueia transições inválidas e exige justificativa em recusa/cancelamento/contraproposta', () {
      expect(
        () => TaskApoioStateMachine.validarTransicao(
          atual: TaskApoioStatus.cancelada,
          destino: TaskApoioStatus.aceita,
        ),
        throwsStateError,
      );

      expect(
        () => TaskApoioStateMachine.validarTransicao(
          atual: TaskApoioStatus.pendente,
          destino: TaskApoioStatus.recusada,
          justificativa: '   ',
        ),
        throwsArgumentError,
      );

      expect(
        () => TaskApoioStateMachine.validarTransicao(
          atual: TaskApoioStatus.emAnalise,
          destino: TaskApoioStatus.contraproposta,
          contrapropostaInicio: DateTime.utc(2026, 11, 24),
          contrapropostaFim: DateTime.utc(2026, 11, 25),
          justificativa: '',
        ),
        throwsArgumentError,
      );
    });

    test('Lista ações coerentes por papel do ator', () {
      final acoesSol = TaskApoioStateMachine.acoesDisponiveis(
        statusAtual: TaskApoioStatus.contraproposta,
        papel: TaskApoioPapelAtor.solicitante,
      );
      expect(acoesSol, contains(TaskApoioAcao.aceitarContraproposta));
      expect(acoesSol, contains(TaskApoioAcao.recusarContraproposta));

      final acoesApoio = TaskApoioStateMachine.acoesDisponiveis(
        statusAtual: TaskApoioStatus.pendente,
        papel: TaskApoioPapelAtor.unidadeApoio,
      );
      expect(acoesApoio, contains(TaskApoioAcao.aceitar));
      expect(acoesApoio, contains(TaskApoioAcao.enviarContraproposta));
    });
  });
}
