import 'package:flutter/foundation.dart';

import '../../../config/supabase_config.dart';
import '../../../models/task.dart';
import '../data/repositories/in_memory_task_apoio_repository.dart';
import '../domain/enums/task_apoio_enums.dart';
import '../domain/models/task_apoio_requisito_recurso.dart';
import '../domain/models/task_apoio_solicitacao.dart';
import '../domain/models/task_apoio_vinculo.dart';

/// Conjunto controlado de dados simulados para homologação no ambiente DEV (Cenários A–H).
/// Restrito estritamente ao ambiente de desenvolvimento: nunca pode ser ativado em produção.
class TaskApoioDemoData {
  final InMemoryTaskApoioRepository repository;
  final Map<String, Task> tasksPorId;
  final Map<String, String> nomesUnidades;

  const TaskApoioDemoData({
    required this.repository,
    required this.tasksPorId,
    required this.nomesUnidades,
  });
}

class TaskApoioDemoFixtures {
  /// Garante que o modo demonstração só é permitido em DEV / debug.
  static bool get isDevDemoAllowed {
    if (kDebugMode) return true;
    final url = SupabaseConfig.supabaseUrl;
    // Bloqueia explicitamente o host de produção
    if (url.contains('10.140.50.12')) return false;
    return url.contains('212.85.0.249') || url.contains('localhost');
  }

  static Future<TaskApoioDemoData> criarCenariosObrigatorios() async {
    if (!isDevDemoAllowed) {
      throw StateError(
        'Modo de demonstração de Apoios Operacionais não permitido em produção.',
      );
    }

    final repo = InMemoryTaskApoioRepository();

    // Unidades fictícias claramente marcadas como demonstração
    const regSul = 'demo-reg-sul';
    const divManut = 'demo-div-manut';
    const divFrota = 'demo-div-frota';
    const divOper = 'demo-div-oper';
    const divTec = 'demo-div-tec';

    final nomesUnidades = {
      regSul: 'Regional Sul (Demo)',
      divManut: 'Divisão de Manutenção (Demo)',
      divFrota: 'Divisão de Frota (Demo)',
      divOper: 'Divisão de Operação (Demo)',
      divTec: 'Divisão Técnica Especializada (Demo)',
    };

    // Tasks representativas dos cenários A–H
    final taskA = Task(
      id: 'demo-task-a',
      status: 'PROG',
      regional: 'Regional Sul',
      divisao: 'Manutenção',
      locais: const ['SE Boa Vista'],
      tipo: 'MANUT',
      tarefa: '[DEMONSTRAÇÃO] Cenário A: Manutenção de Disjuntor SE',
      coordenador: 'Coord. Manutenção',
      dataInicio: DateTime.utc(2026, 11, 23, 8),
      dataFim: DateTime.utc(2026, 11, 27, 17),
    );
    final taskAMunck = Task(
      id: 'demo-task-a-munck',
      status: 'PROG',
      regional: 'Regional Sul',
      divisao: 'Frota',
      locais: const ['SE Boa Vista'],
      tipo: 'APOIO',
      tarefa: '[DEMONSTRAÇÃO] Caminhão Munck 12t + Operador',
      frotaIds: const ['frota-munck-01'],
      frota: 'Caminhão Munck 01',
      executorIds: const ['op-01'],
      executores: const ['João Operador'],
      coordenador: 'Coord. Frota',
      dataInicio: DateTime.utc(2026, 11, 23, 8),
      dataFim: DateTime.utc(2026, 11, 25, 17),
    );

    // Cenário B: Parcialmente programado (23-27/11 com lacuna dia 25/11)
    final taskB = Task(
      id: 'demo-task-b',
      status: 'PROG',
      regional: 'Regional Sul',
      divisao: 'Manutenção',
      locais: const ['LT 138kV'],
      tipo: 'MANUT',
      tarefa: '[DEMONSTRAÇÃO] Cenário B: Roço e Manutenção LT',
      coordenador: 'Coord. Manutenção',
      dataInicio: DateTime.utc(2026, 11, 23, 0),
      dataFim: DateTime.utc(2026, 11, 28, 0),
    );
    final taskB1 = Task(
      id: 'demo-task-b1',
      status: 'PROG',
      regional: 'Regional Sul',
      divisao: 'Frota',
      locais: const ['LT 138kV'],
      tipo: 'APOIO',
      tarefa: '[DEMONSTRAÇÃO] Trator Frente 1 (23-24/11)',
      frotaIds: const ['frota-trator-1'],
      frota: 'Trator 01',
      executorIds: const ['op-02'],
      coordenador: 'Coord. Frota',
      dataInicio: DateTime.utc(2026, 11, 23, 0),
      dataFim: DateTime.utc(2026, 11, 25, 0),
    );
    final taskB2 = Task(
      id: 'demo-task-b2',
      status: 'PROG',
      regional: 'Regional Sul',
      divisao: 'Frota',
      locais: const ['LT 138kV'],
      tipo: 'APOIO',
      tarefa: '[DEMONSTRAÇÃO] Trator Frente 2 (26-27/11)',
      frotaIds: const ['frota-trator-2'],
      frota: 'Trator 02',
      executorIds: const ['op-03'],
      coordenador: 'Coord. Frota',
      dataInicio: DateTime.utc(2026, 11, 26, 0),
      dataFim: DateTime.utc(2026, 11, 28, 0),
    );

    // Cenário C, D, E, F, G, H
    final taskC = Task(
      id: 'demo-task-c',
      status: 'PROG',
      regional: 'Regional Sul',
      divisao: 'Manutenção',
      locais: const ['SE Centro'],
      tipo: 'MANUT',
      tarefa: '[DEMONSTRAÇÃO] Cenário C: Aceito s/ Programação',
      coordenador: 'Coord. Manutenção',
      dataInicio: DateTime.utc(2026, 11, 24, 8),
      dataFim: DateTime.utc(2026, 11, 24, 17),
    );
    final taskD = Task(
      id: 'demo-task-d',
      status: 'PROG',
      regional: 'Regional Sul',
      divisao: 'Manutenção',
      locais: const ['SE Leste'],
      tipo: 'MANUT',
      tarefa: '[DEMONSTRAÇÃO] Cenário D: Múltiplas Divisões',
      coordenador: 'Coord. Manutenção',
      dataInicio: DateTime.utc(2026, 11, 25, 8),
      dataFim: DateTime.utc(2026, 11, 26, 17),
    );
    final taskE1 = Task(
      id: 'demo-task-e1',
      status: 'PROG',
      regional: 'Regional Sul',
      divisao: 'Manutenção',
      locais: const ['SE Norte'],
      tipo: 'MANUT',
      tarefa: '[DEMONSTRAÇÃO] Cenário E1: Solicitante Norte',
      coordenador: 'Coord. Manutenção',
      dataInicio: DateTime.utc(2026, 11, 28, 8),
      dataFim: DateTime.utc(2026, 11, 28, 12),
    );
    final taskE2 = Task(
      id: 'demo-task-e2',
      status: 'PROG',
      regional: 'Regional Sul',
      divisao: 'Manutenção',
      locais: const ['SE Oeste'],
      tipo: 'MANUT',
      tarefa: '[DEMONSTRAÇÃO] Cenário E2: Solicitante Oeste',
      coordenador: 'Coord. Manutenção',
      dataInicio: DateTime.utc(2026, 11, 28, 10),
      dataFim: DateTime.utc(2026, 11, 28, 14),
    );
    final taskG = Task(
      id: 'demo-task-g',
      status: 'PROG',
      regional: 'Regional Sul',
      divisao: 'Manutenção',
      locais: const ['SE Sul'],
      tipo: 'MANUT',
      tarefa: '[DEMONSTRAÇÃO] Cenário G: Recursos Pendentes',
      coordenador: 'Coord. Manutenção',
      dataInicio: DateTime.utc(2026, 11, 29, 8),
      dataFim: DateTime.utc(2026, 11, 29, 17),
    );
    final taskGPendenteRec = Task(
      id: 'demo-task-g-apoio',
      status: 'PROG',
      regional: 'Regional Sul',
      divisao: 'Frota',
      locais: const ['SE Sul'],
      tipo: 'APOIO',
      tarefa: '[DEMONSTRAÇÃO] Apoio Frota s/ Veículo Alocado',
      coordenador: 'Coord. Frota',
      dataInicio: DateTime.utc(2026, 11, 29, 8),
      dataFim: DateTime.utc(2026, 11, 29, 17),
    );
    final taskH = Task(
      id: 'demo-task-h',
      status: 'PROG',
      regional: 'Regional Sul',
      divisao: 'Manutenção',
      locais: const ['SE Padrão'],
      tipo: 'MANUT',
      tarefa: '[DEMONSTRAÇÃO] Cenário H: Atividade Sem Apoios',
      coordenador: 'Coord. Manutenção',
      dataInicio: DateTime.utc(2026, 11, 30, 8),
      dataFim: DateTime.utc(2026, 11, 30, 17),
    );

    final tasks = {
      for (final t in [
        taskA,
        taskAMunck,
        taskB,
        taskB1,
        taskB2,
        taskC,
        taskD,
        taskE1,
        taskE2,
        taskG,
        taskGPendenteRec,
        taskH,
      ])
        t.id: t,
    };

    // Popular Cenário A
    final solA = await repo.criarSolicitacao(
      TaskApoioSolicitacao(
        id: 'demo-sol-a',
        taskSolicitanteId: taskA.id,
        taskSolicitanteTituloSnapshot: taskA.tarefa,
        regionalSolicitanteId: regSul,
        divisaoSolicitanteId: divManut,
        regionalDestinoId: regSul,
        divisaoDestinoId: divFrota,
        tipoApoioId: 'tipo-frota',
        prioridade: TaskApoioPrioridade.alta,
        descricao: '[DEMONSTRAÇÃO] Caminhão Munck com operador',
        dataInicioSolicitada: DateTime.utc(2026, 11, 23, 8),
        dataFimSolicitada: DateTime.utc(2026, 11, 25, 17),
        solicitanteUsuarioId: 'demo-user-1',
        requisitosRecursos: const TaskApoioRequisitoRecurso(
          tipoVeiculo: 'Munck',
          exigeVeiculo: true,
          exigeOperador: true,
        ),
      ),
    );
    await repo.atualizarSolicitacao(
      solA.copyWith(status: TaskApoioStatus.aceita),
      atorUsuarioId: 'demo-user-frota',
      atorNome: 'Gestor Frota (Demo)',
    );
    await repo.criarVinculo(
      TaskApoioVinculo(
        id: 'demo-vinc-a',
        solicitacaoId: solA.id,
        taskPrincipalId: taskA.id,
        taskApoioId: taskAMunck.id,
        taskPrincipalTituloSnapshot: taskA.tarefa,
        taskApoioTituloSnapshot: taskAMunck.tarefa,
        tipoApoioId: 'tipo-frota',
        createdBy: 'demo-user-frota',
      ),
      atorNome: 'Gestor Frota (Demo)',
    );

    // Popular Cenário B (Parcialmente programado — lacuna dia 25/11)
    final solB = await repo.criarSolicitacao(
      TaskApoioSolicitacao(
        id: 'demo-sol-b',
        taskSolicitanteId: taskB.id,
        taskSolicitanteTituloSnapshot: taskB.tarefa,
        regionalSolicitanteId: regSul,
        divisaoSolicitanteId: divManut,
        regionalDestinoId: regSul,
        divisaoDestinoId: divFrota,
        tipoApoioId: 'tipo-maquinas',
        descricao: '[DEMONSTRAÇÃO] Trator para roço de faixa',
        dataInicioSolicitada: DateTime.utc(2026, 11, 23, 0),
        dataFimSolicitada: DateTime.utc(2026, 11, 28, 0),
        solicitanteUsuarioId: 'demo-user-1',
      ),
    );
    await repo.atualizarSolicitacao(
      solB.copyWith(status: TaskApoioStatus.aceita),
      atorUsuarioId: 'demo-user-frota',
      atorNome: 'Gestor Frota (Demo)',
    );
    await repo.criarVinculo(
      TaskApoioVinculo(
        id: 'demo-vinc-b1',
        solicitacaoId: solB.id,
        taskPrincipalId: taskB.id,
        taskApoioId: taskB1.id,
        taskPrincipalTituloSnapshot: taskB.tarefa,
        taskApoioTituloSnapshot: taskB1.tarefa,
        createdBy: 'demo-user-frota',
      ),
    );
    await repo.criarVinculo(
      TaskApoioVinculo(
        id: 'demo-vinc-b2',
        solicitacaoId: solB.id,
        taskPrincipalId: taskB.id,
        taskApoioId: taskB2.id,
        taskPrincipalTituloSnapshot: taskB.tarefa,
        taskApoioTituloSnapshot: taskB2.tarefa,
        createdBy: 'demo-user-frota',
      ),
    );

    // Popular Cenário C (Aceito sem programação)
    final solC = await repo.criarSolicitacao(
      TaskApoioSolicitacao(
        id: 'demo-sol-c',
        taskSolicitanteId: taskC.id,
        taskSolicitanteTituloSnapshot: taskC.tarefa,
        regionalSolicitanteId: regSul,
        divisaoSolicitanteId: divManut,
        regionalDestinoId: regSul,
        divisaoDestinoId: divOper,
        tipoApoioId: 'tipo-manobra',
        descricao: '[DEMONSTRAÇÃO] Equipe para manobras na SE Centro',
        dataInicioSolicitada: DateTime.utc(2026, 11, 24, 8),
        dataFimSolicitada: DateTime.utc(2026, 11, 24, 12),
        solicitanteUsuarioId: 'demo-user-1',
      ),
    );
    await repo.atualizarSolicitacao(
      solC.copyWith(status: TaskApoioStatus.aceita),
      atorUsuarioId: 'demo-user-oper',
      atorNome: 'Gestor Operação (Demo)',
    );

    // Popular Cenário D (3 divisões diferentes)
    await repo.criarSolicitacao(
      TaskApoioSolicitacao(
        id: 'demo-sol-d1',
        taskSolicitanteId: taskD.id,
        taskSolicitanteTituloSnapshot: taskD.tarefa,
        regionalSolicitanteId: regSul,
        divisaoSolicitanteId: divManut,
        regionalDestinoId: regSul,
        divisaoDestinoId: divFrota,
        tipoApoioId: 'tipo-frota',
        descricao: '[DEMONSTRAÇÃO] Prancha transporte',
        dataInicioSolicitada: DateTime.utc(2026, 11, 25, 8),
        dataFimSolicitada: DateTime.utc(2026, 11, 26, 17),
        solicitanteUsuarioId: 'demo-user-1',
      ),
    );
    await repo.criarSolicitacao(
      TaskApoioSolicitacao(
        id: 'demo-sol-d2',
        taskSolicitanteId: taskD.id,
        taskSolicitanteTituloSnapshot: taskD.tarefa,
        regionalSolicitanteId: regSul,
        divisaoSolicitanteId: divManut,
        regionalDestinoId: regSul,
        divisaoDestinoId: divOper,
        tipoApoioId: 'tipo-manobra',
        descricao: '[DEMONSTRAÇÃO] Manobra de linha',
        dataInicioSolicitada: DateTime.utc(2026, 11, 25, 8),
        dataFimSolicitada: DateTime.utc(2026, 11, 25, 10),
        solicitanteUsuarioId: 'demo-user-1',
      ),
    );
    await repo.criarSolicitacao(
      TaskApoioSolicitacao(
        id: 'demo-sol-d3',
        taskSolicitanteId: taskD.id,
        taskSolicitanteTituloSnapshot: taskD.tarefa,
        regionalSolicitanteId: regSul,
        divisaoSolicitanteId: divManut,
        regionalDestinoId: regSul,
        divisaoDestinoId: divTec,
        tipoApoioId: 'tipo-outros',
        criticidade: TaskApoioCriticidade.complementar,
        descricao: '[DEMONSTRAÇÃO] Apoio técnico especializado',
        dataInicioSolicitada: DateTime.utc(2026, 11, 25, 13),
        dataFimSolicitada: DateTime.utc(2026, 11, 26, 17),
        solicitanteUsuarioId: 'demo-user-1',
      ),
    );

    // Popular Cenário E (Apoio compartilhado atendendo 2 solicitantes)
    final solE1 = await repo.criarSolicitacao(
      TaskApoioSolicitacao(
        id: 'demo-sol-e1',
        taskSolicitanteId: taskE1.id,
        taskSolicitanteTituloSnapshot: taskE1.tarefa,
        regionalSolicitanteId: regSul,
        divisaoSolicitanteId: divManut,
        regionalDestinoId: regSul,
        divisaoDestinoId: divFrota,
        tipoApoioId: 'tipo-frota',
        descricao: '[DEMONSTRAÇÃO] Munck compartilhado Norte',
        dataInicioSolicitada: DateTime.utc(2026, 11, 28, 8),
        dataFimSolicitada: DateTime.utc(2026, 11, 28, 12),
        solicitanteUsuarioId: 'demo-user-1',
      ),
    );
    await repo.atualizarSolicitacao(
      solE1.copyWith(status: TaskApoioStatus.aceita),
      atorUsuarioId: 'demo-user-frota',
    );
    await repo.criarVinculo(
      TaskApoioVinculo(
        id: 'demo-vinc-e1',
        solicitacaoId: solE1.id,
        taskPrincipalId: taskE1.id,
        taskApoioId: taskAMunck.id,
        taskPrincipalTituloSnapshot: taskE1.tarefa,
        taskApoioTituloSnapshot: taskAMunck.tarefa,
        createdBy: 'demo-user-frota',
      ),
    );

    final solE2 = await repo.criarSolicitacao(
      TaskApoioSolicitacao(
        id: 'demo-sol-e2',
        taskSolicitanteId: taskE2.id,
        taskSolicitanteTituloSnapshot: taskE2.tarefa,
        regionalSolicitanteId: regSul,
        divisaoSolicitanteId: divManut,
        regionalDestinoId: regSul,
        divisaoDestinoId: divFrota,
        tipoApoioId: 'tipo-frota',
        descricao: '[DEMONSTRAÇÃO] Munck compartilhado Oeste',
        dataInicioSolicitada: DateTime.utc(2026, 11, 28, 10),
        dataFimSolicitada: DateTime.utc(2026, 11, 28, 14),
        solicitanteUsuarioId: 'demo-user-1',
      ),
    );
    await repo.atualizarSolicitacao(
      solE2.copyWith(status: TaskApoioStatus.aceita),
      atorUsuarioId: 'demo-user-frota',
    );
    await repo.criarVinculo(
      TaskApoioVinculo(
        id: 'demo-vinc-e2',
        solicitacaoId: solE2.id,
        taskPrincipalId: taskE2.id,
        taskApoioId: taskAMunck.id,
        taskPrincipalTituloSnapshot: taskE2.tarefa,
        taskApoioTituloSnapshot: taskAMunck.tarefa,
        createdBy: 'demo-user-frota',
      ),
    );

    // Popular Cenário G (Recursos pendentes)
    final solG = await repo.criarSolicitacao(
      TaskApoioSolicitacao(
        id: 'demo-sol-g',
        taskSolicitanteId: taskG.id,
        taskSolicitanteTituloSnapshot: taskG.tarefa,
        regionalSolicitanteId: regSul,
        divisaoSolicitanteId: divManut,
        regionalDestinoId: regSul,
        divisaoDestinoId: divFrota,
        tipoApoioId: 'tipo-frota',
        descricao: '[DEMONSTRAÇÃO] Munck c/ operador (sem alocação)',
        dataInicioSolicitada: DateTime.utc(2026, 11, 29, 8),
        dataFimSolicitada: DateTime.utc(2026, 11, 29, 17),
        solicitanteUsuarioId: 'demo-user-1',
        requisitosRecursos: const TaskApoioRequisitoRecurso(
          tipoVeiculo: 'Munck',
          exigeVeiculo: true,
          exigeOperador: true,
        ),
      ),
    );
    await repo.atualizarSolicitacao(
      solG.copyWith(status: TaskApoioStatus.aceita),
      atorUsuarioId: 'demo-user-frota',
    );
    await repo.criarVinculo(
      TaskApoioVinculo(
        id: 'demo-vinc-g',
        solicitacaoId: solG.id,
        taskPrincipalId: taskG.id,
        taskApoioId: taskGPendenteRec.id,
        taskPrincipalTituloSnapshot: taskG.tarefa,
        taskApoioTituloSnapshot: taskGPendenteRec.tarefa,
        createdBy: 'demo-user-frota',
      ),
    );

    return TaskApoioDemoData(
      repository: repo,
      tasksPorId: tasks,
      nomesUnidades: nomesUnidades,
    );
  }
}
