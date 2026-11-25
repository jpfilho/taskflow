import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:task2026/features/apoios_operacionais/data/repositories/supabase_apoios_gateway_repository.dart';
import 'package:task2026/features/apoios_operacionais/data/repositories/task_apoio_offline_store.dart';
import 'package:task2026/features/apoios_operacionais/data/services/apoios_auth_session_service.dart';
import 'package:task2026/features/apoios_operacionais/domain/enums/task_apoio_enums.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_solicitacao.dart';
import 'package:task2026/features/apoios_operacionais/domain/repositories/task_apoio_repository.dart';
import 'package:task2026/features/apoios_operacionais/presentation/task_apoio_ui_controller.dart';
import 'package:task2026/models/task.dart';

String _buildTestJwt({required int expOffsetSeconds}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({
        'sub': 'user-div-a',
        'exp': now + expOffsetSeconds,
        'scope': 'apoios_operacionais',
      })))
      .replaceAll('=', '');
  return '$header.$payload.sig';
}

class _SqlBackedKvPersistence implements TaskApoioKeyValuePersistence {
  final Database db;
  _SqlBackedKvPersistence(this.db);

  @override
  Future<String?> read(String key) async {
    final rows = await db.query(
      'tasks_apoios_kv_local',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  @override
  Future<void> write(String key, String value) async {
    await db.insert(
      'tasks_apoios_kv_local',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String key) async {
    await db.delete(
      'tasks_apoios_kv_local',
      where: 'key = ?',
      whereArgs: [key],
    );
  }
}

void main() {
  sqfliteFfiInit();

  group('Fase 5B — Gateway Autenticado e Persistência SQLite', () {
    tearDown(() async {
      await ApoiosAuthSessionService().clearSession(usuarioId: 'user-div-a');
    });

    test('Bloqueia chamadas reais sem token válido', () async {
      final session = ApoiosAuthSessionService();
      await session.clearSession(usuarioId: 'user-div-a');

      final repo = SupabaseApoiosGatewayRepository(
        sessionService: session,
        httpClient: MockClient((_) async => http.Response('{}', 200)),
        baseUrlOverride: 'http://localhost:3001',
      );

      expect(
        () => repo.listarTiposAtivos(),
        throwsA(isA<TaskApoioAuthRequiredException>()),
      );
    });

    test('Executa fluxo autenticado e resumo em lote (zero N+1)', () async {
      final session = ApoiosAuthSessionService();
      await session.setToken(
        usuarioId: 'user-div-a',
        token: _buildTestJwt(expOffsetSeconds: 3600),
      );

      int resumosRequests = 0;
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], startsWith('Bearer '));
        if (request.url.path == '/api/apoios/tipos') {
          return http.Response(
            jsonEncode({
              'ok': true,
              'data': [
                {
                  'id': 'tipo-1',
                  'codigo': 'FROTA_VEICULOS',
                  'nome': 'Frota e veículos',
                  'ativo': true,
                  'ordem': 1,
                }
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/apoios/resumos') {
          resumosRequests++;
          return http.Response(
            jsonEncode({
              'ok': true,
              'data': {
                'solicitacoes': [
                  {
                    'id': 'sol-1',
                    'task_solicitante_id': 'task-1',
                    'status': 'PENDENTE',
                    'criticidade': 'ESSENCIAL',
                    'situacao': {'situacao_geral': 'AGUARDANDO_RESPOSTA'},
                  }
                ],
                'vinculosComoApoio': [
                  {'id': 'v-1', 'task_apoio_id': 'task-2', 'ativo': true}
                ],
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/apoios/solicitacoes/sol-conflict') {
          return http.Response(
            jsonEncode({'ok': false, 'error': 'Conflito de versão'}),
            409,
          );
        }
        return http.Response(jsonEncode({'ok': false}), 404);
      });

      final repo = SupabaseApoiosGatewayRepository(
        sessionService: session,
        httpClient: mockClient,
        baseUrlOverride: 'http://localhost:3001',
      );

      final tipos = await repo.listarTiposAtivos();
      expect(tipos, hasLength(1));
      expect(tipos.first.codigo, 'FROTA_VEICULOS');

      final resumos = await repo.buscarResumosEmLote(['task-1', 'task-2']);
      expect(resumosRequests, 1);
      expect(resumos['task-1']?.totalSolicitacoes, 1);
      expect(resumos['task-1']?.qtdAguardandoResposta, 1);
      expect(resumos['task-2']?.qtdAtividadesApoiadas, 1);

      final now = DateTime.now().toUtc();
      expect(
        () => repo.atualizarSolicitacao(
          TaskApoioSolicitacao(
            id: 'sol-conflict',
            taskSolicitanteId: 'task-1',
            taskSolicitanteTituloSnapshot: 'T',
            regionalSolicitanteId: 'reg-1',
            divisaoSolicitanteId: 'div-1',
            regionalDestinoId: 'reg-2',
            divisaoDestinoId: 'div-2',
            tipoApoioId: 'tipo-1',
            descricao: 'Teste',
            dataInicioSolicitada: now,
            dataFimSolicitada: now.add(const Duration(hours: 2)),
            solicitanteUsuarioId: 'user-div-a',
            createdAt: now,
            updatedAt: now,
          ),
          atorUsuarioId: 'user-div-a',
        ),
        throwsA(isA<TaskApoioVersionConflictException>()),
      );
    });

    test('TaskApoioUiController alterna disponibilidade conforme sessão e cria apoio no modo demo', () async {
      final session = ApoiosAuthSessionService();
      await session.clearSession(usuarioId: 'user-div-a');

      final controller = TaskApoioUiController(
        sessionService: session,
        offlineStore: TaskApoioOfflineStore(),
      );
      expect(
        controller.disponibilidade,
        TaskApoioDisponibilidadeEstado.autenticacaoPendente,
      );

      await session.setToken(
        usuarioId: 'user-div-a',
        token: _buildTestJwt(expOffsetSeconds: 3600),
      );
      await controller.sincronizarSessaoAutenticada(sessionService: session);
      expect(
        controller.disponibilidade,
        TaskApoioDisponibilidadeEstado.disponivel,
      );

      await session.clearSession(usuarioId: 'user-div-a');
      await controller.sincronizarSessaoAutenticada(sessionService: session);
      expect(
        controller.disponibilidade,
        TaskApoioDisponibilidadeEstado.autenticacaoPendente,
      );

      await controller.ativarModoDemonstracaoDev();
      final sols = await controller.service.buscarSolicitacoes();
      final solAceita = sols.firstWhere(
        (s) => s.status == TaskApoioStatus.aceita,
      );
      final Task criada = await controller.criarAtividadeDeApoioEVincular(
        solicitacao: solAceita,
        titulo: 'Apoio criado via Central (Teste)',
        inicio: solAceita.dataInicioSolicitada,
        fim: solAceita.dataFimSolicitada,
        atorUsuarioId: 'demo-user',
        atorNome: 'Demo',
      );
      expect(criada.tarefa, 'Apoio criado via Central (Teste)');
    });

    test('Persistência SQLite preserva fila isolada por usuário após reinicialização', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE tasks_apoios_kv_local (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      try {
        final kv = _SqlBackedKvPersistence(db);
        final store1 = TaskApoioOfflineStore(
          usuarioAtualId: 'user-div-a',
          isOnline: false,
          persistence: kv,
        );
        final now = DateTime.now().toUtc();
        await store1.prepararSolicitacaoOffline(
          TaskApoioSolicitacao(
            id: 'local-sql-1',
            taskSolicitanteId: 'task-1',
            taskSolicitanteTituloSnapshot: 'Atividade A',
            regionalSolicitanteId: 'reg-1',
            divisaoSolicitanteId: 'div-a',
            regionalDestinoId: 'reg-1',
            divisaoDestinoId: 'div-b',
            tipoApoioId: 'tipo-1',
            descricao: 'Munck offline SQLite',
            dataInicioSolicitada: now,
            dataFimSolicitada: now.add(const Duration(hours: 3)),
            solicitanteUsuarioId: 'user-div-a',
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Simula fechamento e reabertura do app com troca de usuário
        final store2 = TaskApoioOfflineStore(
          isOnline: false,
          persistence: kv,
        );
        await store2.trocarUsuario('user-div-b');
        expect(store2.listarFila(), isEmpty);

        await store2.trocarUsuario('user-div-a');
        expect(store2.listarFila(), hasLength(1));
        expect(store2.listarFila().first.entidadeId, 'local-sql-1');
      } finally {
        await db.close();
      }
    });
  });
}
