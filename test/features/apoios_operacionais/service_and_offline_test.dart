import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/features/apoios_operacionais/data/repositories/in_memory_task_apoio_repository.dart';
import 'package:task2026/features/apoios_operacionais/data/repositories/protected_backend_task_apoio_adapter.dart';
import 'package:task2026/features/apoios_operacionais/data/repositories/task_apoio_offline_store.dart';
import 'package:task2026/features/apoios_operacionais/domain/enums/task_apoio_enums.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_solicitacao.dart';
import 'package:task2026/features/apoios_operacionais/domain/repositories/task_apoio_repository.dart';
import 'package:task2026/features/apoios_operacionais/services/task_apoio_reprogramacao_watcher.dart';
import 'package:task2026/features/apoios_operacionais/services/task_apoio_service.dart';
import 'package:task2026/models/task.dart';

Task _taskSimples(String id, DateTime ini, DateTime fim, {String status = 'PROG'}) {
  return Task(
    id: id,
    status: status,
    regional: 'REG',
    divisao: 'DIV',
    tipo: 'MANUT',
    tarefa: 'Atividade $id',
    coordenador: 'Coord',
    dataInicio: ini,
    dataFim: fim,
  );
}

void main() {
  group('TaskApoioService + InMemoryTaskApoioRepository', () {
    late InMemoryTaskApoioRepository repo;
    late TaskApoioService service;

    setUp(() {
      repo = InMemoryTaskApoioRepository();
      service = TaskApoioService(repository: repo);
    });

    test('Fluxo completo: criar, encaminhar, contrapropor, aceitar contraproposta, vincular e consultar em lote', () async {
      final sol = await service.criarSolicitacao(
        TaskApoioSolicitacao(
          id: 'sol-1',
          idempotencyKey: 'idem-1',
          taskSolicitanteId: 't-p1',
          taskSolicitanteTituloSnapshot: 'Manut SE',
          regionalSolicitanteId: 'r1',
          divisaoSolicitanteId: 'd1',
          regionalDestinoId: 'r2',
          divisaoDestinoId: 'd2',
          tipoApoioId: 'tipo-frota',
          prioridade: TaskApoioPrioridade.urgente,
          descricao: 'Caminhão Munck',
          dataInicioSolicitada: DateTime.utc(2026, 12, 1, 8),
          dataFimSolicitada: DateTime.utc(2026, 12, 2, 17),
          solicitanteUsuarioId: 'u-sol',
        ),
      );
      expect(sol.status, TaskApoioStatus.pendente);
      expect(sol.versao, 1);

      // Idempotência: mesma chave retorna a mesma solicitação sem duplicar
      final solDup = await service.criarSolicitacao(sol);
      expect(solDup.id, sol.id);

      final emAnalise = await service.encaminharParaAnalise(
        solicitacaoId: sol.id,
        versaoEsperada: 1,
        responsavelId: 'u-ap',
      );
      expect(emAnalise.versao, 2);

      final contra = await service.apresentarContraproposta(
        solicitacaoId: sol.id,
        versaoEsperada: 2,
        atorUsuarioId: 'u-ap',
        inicioProposto: DateTime.utc(2026, 12, 3, 8),
        fimProposto: DateTime.utc(2026, 12, 4, 17),
        justificativa: 'Munck livre dia 3',
      );
      expect(contra.status, TaskApoioStatus.contraproposta);
      expect(contra.dataInicioSolicitada, DateTime.utc(2026, 12, 1, 8));

      final aceita = await service.aceitarContraproposta(
        solicitacaoId: sol.id,
        versaoEsperada: 3,
        atorUsuarioId: 'u-sol',
      );
      expect(aceita.status, TaskApoioStatus.aceita);
      expect(aceita.dataInicioAcordada, DateTime.utc(2026, 12, 3, 8));

      // Vincular atividade de apoio
      final tP = _taskSimples('t-p1', DateTime.utc(2026, 12, 1, 8), DateTime.utc(2026, 12, 5, 17));
      final tA = _taskSimples('t-a1', DateTime.utc(2026, 12, 3, 8), DateTime.utc(2026, 12, 4, 17));
      await service.vincularAtividadeExistente(
        id: 'v-1',
        solicitacaoId: sol.id,
        taskPrincipal: tP,
        taskApoio: tA,
        autorizadoDireto: false,
        createdBy: 'u-ap',
      );

      // Visão bidirecional
      expect((await service.buscarAtividadesApoioVinculadas('t-p1')).length, 1);
      expect((await service.buscarAtividadesAtendidas('t-a1')).length, 1);

      // Lote e indicadores
      final resumos = await service.buscarResumosEmLote(['t-p1', 't-a1']);
      expect(resumos['t-p1']?.totalSolicitacoes, 1);
      expect(resumos['t-a1']?.qtdAtividadesApoiadas, 1);

      final ind = await service.calcularIndicadoresGerenciais(
        tasksPorId: {'t-p1': tP, 't-a1': tA},
      );
      expect(ind.totalSolicitacoes, 1);
      expect(ind.aceitas, 1);
      expect(ind.urgentesAbertas, 1);

      final hist = await service.buscarHistorico(solicitacaoId: sol.id);
      expect(hist.length, greaterThanOrEqualTo(5));
    });

    test('Programação conjunta bloqueia duplicidade simétrica e Watcher detecta impacto de reprogramação', () async {
      final t1 = _taskSimples('t1', DateTime.utc(2026, 12, 1, 8), DateTime.utc(2026, 12, 1, 17));
      final t2 = _taskSimples('t2', DateTime.utc(2026, 12, 1, 8), DateTime.utc(2026, 12, 1, 17));

      await service.criarProgramacaoConjunta(
        id: 'vc-1',
        taskA: t1,
        taskB: t2,
        createdBy: 'u1',
      );

      expect(
        () => service.criarProgramacaoConjunta(
          id: 'vc-2',
          taskA: t2,
          taskB: t1,
          createdBy: 'u2',
        ),
        throwsStateError,
      );

      final watcher = TaskApoioReprogramacaoWatcher(repository: repo, service: service);
      final t2Alterada = _taskSimples(
        't2',
        DateTime.utc(2026, 12, 5, 8),
        DateTime.utc(2026, 12, 5, 17),
      );
      final impacto = await watcher.avaliarImpactoAlteracao(
        taskAntes: t2,
        taskDepois: t2Alterada,
      );
      expect(impacto, isNotNull);
      expect(impacto!.requerReconfirmacao, isTrue);
      expect(impacto.vinculosAfetadosIds, contains('vc-1'));
    });
  });

  group('Offline-first e Segurança do Backend Adapter', () {
    test('ProtectedBackendTaskApoioAdapter bloqueia operações operacionais sem identidade verificável', () async {
      const adapter = ProtectedBackendTaskApoioAdapter();
      expect(
        () => adapter.buscarSolicitacoes(),
        throwsA(isA<TaskApoioAuthRequiredException>()),
      );
    });

    test('TaskApoioOfflineStore diferencia estados locais, impede aceite offline, persiste e isola troca de usuário', () async {
      final persistence = InMemoryApoioPersistence();
      final store = TaskApoioOfflineStore(
        usuarioAtualId: 'user-A',
        isOnline: false,
        backendAutenticadoDisponivel: false,
        persistence: persistence,
      );

      final sol = TaskApoioSolicitacao(
        id: 'sol-off-1',
        idempotencyKey: 'idem-off-1',
        taskSolicitanteTituloSnapshot: 'Principal Off',
        regionalSolicitanteId: 'r1',
        divisaoSolicitanteId: 'd1',
        regionalDestinoId: 'r2',
        divisaoDestinoId: 'd2',
        tipoApoioId: 'tipo-frota',
        descricao: 'Offline',
        dataInicioSolicitada: DateTime.utc(2026, 12, 1, 8),
        dataFimSolicitada: DateTime.utc(2026, 12, 1, 12),
        solicitanteUsuarioId: 'user-A',
      );

      final preparada = await store.prepararSolicitacaoOffline(sol);
      expect(preparada.syncStatus, TaskApoioSyncStatus.pendenteSync);
      expect(store.listarFila().length, 1);

      // Tentativa repetida com mesma idempotencyKey não duplica fila
      await store.prepararSolicitacaoOffline(sol);
      expect(store.listarFila().length, 1);

      // Decisão crítica offline exige conexão
      expect(
        () => store.validarOperacaoCriticaOffline('ACEITAR_SOLICITACAO'),
        throwsStateError,
      );

      // Recuperou conexão, mas sem backend autenticado => bloqueia envio seguro
      store.definirConectividade(true);
      expect(
        () => store.processarFilaSync(InMemoryTaskApoioRepository()),
        throwsA(isA<TaskApoioAuthRequiredException>()),
      );

      // Troca de usuário isola sessão de user-B, sem destruir dados pendentes de user-A
      await store.trocarUsuario('user-B');
      expect(store.listarSolicitacoesLocais(), isEmpty);
      expect(store.listarFila(), isEmpty);

      // Retorno de user-A (e simulação de reinício com nova instância) restaura pendência
      final storeReinicio = TaskApoioOfflineStore(
        usuarioAtualId: 'user-A',
        isOnline: false,
        backendAutenticadoDisponivel: false,
        persistence: persistence,
      );
      await storeReinicio.restaurarEstadoUsuarioAtual();
      expect(storeReinicio.listarSolicitacoesLocais().length, 1);
      expect(storeReinicio.listarFila().length, 1);
    });
  });
}
