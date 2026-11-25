import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/apoios_operacionais/data/repositories/in_memory_task_apoio_repository.dart';
import 'package:task2026/features/apoios_operacionais/data/repositories/task_apoio_offline_store.dart';
import 'package:task2026/features/apoios_operacionais/data/services/apoios_auth_session_service.dart';
import 'package:task2026/features/apoios_operacionais/domain/enums/task_apoio_enums.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_solicitacao.dart';
import 'package:task2026/features/apoios_operacionais/presentation/task_apoio_ui_controller.dart';
import 'package:task2026/features/notificacoes/data/notificacoes_gateway_service.dart';
import 'package:task2026/features/notificacoes/domain/models/notificacao_interna.dart';
import 'package:task2026/features/notificacoes/presentation/notificacoes_controller.dart';
import 'package:task2026/features/notificacoes/presentation/widgets/notificacoes_bell_button.dart';
import 'package:task2026/features/notificacoes/presentation/widgets/notificacoes_panel_dialog.dart';

String _jwtValid() {
  final h = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final p = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'u-1', 'exp': now + 3600})))
      .replaceAll('=', '');
  return '$h.$p.sig';
}

void main() {
  group('Fase 6 — Infraestrutura de Notificações Internas', () {
    tearDown(() async {
      await ApoiosAuthSessionService().clearSession(usuarioId: 'u-1');
    });

    test('Controller autenticado carrega contador, notificações, marca lida e isola cache no logout', () async {
      final session = ApoiosAuthSessionService();
      await session.setToken(usuarioId: 'u-1', token: _jwtValid());
      final kv = InMemoryApoioPersistence();

      bool marcada = false;
      final client = MockClient((req) async {
        if (req.url.path == '/api/apoios/notificacoes/contador') {
          return http.Response(
            jsonEncode({'ok': true, 'data': {'naoLidas': marcada ? 0 : 1}}),
            200,
          );
        }
        if (req.url.path == '/api/apoios/notificacoes') {
          return http.Response(
            jsonEncode({
              'ok': true,
              'data': [
                {
                  'id': 'n-1',
                  'modulo': 'APOIOS_OPERACIONAIS',
                  'categoria': 'SOLICITACAO',
                  'evento_tipo': 'SOLICITACAO_CRIADA',
                  'severidade': 'ATENCAO',
                  'titulo': 'NOVA SOLICITAÇÃO DE APOIO',
                  'mensagem': 'Munck solicitado para SE Centro.',
                  'entidade_tipo': 'SOLICITACAO',
                  'entidade_id': 'sol-1',
                  'solicitacao_id': 'sol-1',
                  'lida': marcada,
                  'created_at': DateTime.now().toIso8601String(),
                }
              ],
            }),
            200,
          );
        }
        if (req.url.path == '/api/apoios/notificacoes/n-1/lida') {
          marcada = true;
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final gateway = NotificacoesGatewayService(
        sessionService: session,
        httpClient: client,
        baseUrlOverride: 'http://localhost:3001',
      );
      final ctrl = NotificacoesController(
        gateway: gateway,
        sessionService: session,
        persistence: kv,
      );

      ctrl.iniciarParaUsuario('u-1');
      await ctrl.carregarNotificacoes(reset: true);
      expect(ctrl.naoLidas, 1);
      expect(ctrl.notificacoes, hasLength(1));

      await ctrl.marcarComoLida('n-1');
      expect(ctrl.naoLidas, 0);
      expect(ctrl.notificacoes.first.lida, isTrue);

      ctrl.parar();
      expect(ctrl.notificacoes, isEmpty);
      expect(ctrl.naoLidas, 0);
      ctrl.dispose();
    });

    testWidgets('NotificacoesBellButton e NotificacoesPanelDialog renderizam e navegam sem overflow', (tester) async {
      final ctrl = NotificacoesController(
        persistence: InMemoryApoioPersistence(),
      );
      ctrl.ativarModoDemonstracaoDev();

      NotificacaoInterna? selecionada;
      await tester.pumpWidget(
        MaterialApp(
          theme: TaskFlowTheme.light(),
          home: Scaffold(
            appBar: AppBar(
              actions: [
                Builder(
                  builder: (ctx) => NotificacoesBellButton(
                    controller: ctrl,
                    onPressed: () {
                      showDialog(
                        context: ctx,
                        builder: (_) => NotificacoesPanelDialog(
                          controller: ctrl,
                          onSelecionar: (n) async {
                            selecionada = n;
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byType(NotificacoesBellButton));
      await tester.pumpAndSettle();

      expect(find.text('Notificações Operacionais'), findsOneWidget);
      expect(find.text('NOVA SOLICITAÇÃO DE APOIO'), findsOneWidget);

      await tester.tap(find.text('NOVA SOLICITAÇÃO DE APOIO'));
      await tester.pumpAndSettle();
      expect(selecionada?.id, 'demo-notif-1');
      ctrl.dispose();
    });

    testWidgets('Exibe estado vazio, filtros, 1 notificação com apoio e layout mobile sem overflow', (tester) async {
      // 1. Estado vazio
      final emptyCtrl = NotificacoesController(
        persistence: InMemoryApoioPersistence(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: TaskFlowTheme.light(),
          home: Scaffold(
            body: NotificacoesPanelDialog(controller: emptyCtrl),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma notificação operacional no momento.'), findsOneWidget);
      expect(find.text('Em dia'), findsOneWidget);
      emptyCtrl.dispose();

      // 2. Uma notificação integrada com TaskApoioUiController (marcar lida sem remover)
      final apoioRepo = InMemoryTaskApoioRepository();
      await tester.runAsync(() async {
        await ApoiosAuthSessionService().setToken(
          usuarioId: 'u-1',
          token: _jwtValid(),
        );
        await apoioRepo.criarSolicitacao(
          TaskApoioSolicitacao(
            id: 'sol-100',
            taskSolicitanteId: 'task-100',
            taskSolicitanteTituloSnapshot: 'Inspeção SE Teresina',
            regionalSolicitanteId: 'reg-1',
            divisaoSolicitanteId: 'div-1',
            segmentoSolicitanteId: 'seg-1',
            solicitanteUsuarioId: 'u-2',
            regionalDestinoId: 'reg-1',
            divisaoDestinoId: 'div-1',
            segmentoDestinoId: 'seg-2',
            tipoApoioId: 'tipo-1',
            descricao: 'Apoio da operação na inspeção',
            criticidade: TaskApoioCriticidade.essencial,
            prioridade: TaskApoioPrioridade.alta,
            dataInicioSolicitada: DateTime(2026, 11, 24, 8),
            dataFimSolicitada: DateTime(2026, 11, 25, 17),
            status: TaskApoioStatus.pendente,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      });
      final session = ApoiosAuthSessionService();
      final apoioCtrl = TaskApoioUiController(
        repository: apoioRepo,
      );

      final client = MockClient((req) async {
        if (req.url.path == '/api/apoios/notificacoes/contador') {
          return http.Response(jsonEncode({'ok': true, 'data': {'naoLidas': 1}}), 200);
        }
        if (req.url.path == '/api/apoios/notificacoes') {
          return http.Response(
            jsonEncode({
              'ok': true,
              'data': [
                {
                  'id': 'n-100',
                  'modulo': 'APOIOS_OPERACIONAIS',
                  'categoria': 'SOLICITACAO',
                  'evento_tipo': 'SOLICITACAO_CRIADA',
                  'severidade': 'ATENCAO',
                  'titulo': 'NOVA SOLICITAÇÃO DE APOIO',
                  'mensagem': 'Atividade: Inspeção SE Teresina\nNecessidade: Apoio da operação na inspeção\nSituação: Aguardando resposta. Consultar no TaskFlow.',
                  'entidade_tipo': 'SOLICITACAO',
                  'entidade_id': 'sol-100',
                  'solicitacao_id': 'sol-100',
                  'lida': false,
                  'created_at': DateTime.now().toIso8601String(),
                },
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final ctrl = NotificacoesController(
        gateway: NotificacoesGatewayService(
          sessionService: session,
          httpClient: client,
          baseUrlOverride: 'http://localhost:3001',
        ),
        sessionService: session,
        persistence: InMemoryApoioPersistence(),
      );
      await tester.runAsync(() => ctrl.carregarNotificacoes(reset: true));

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: TaskFlowTheme.light(),
          home: Scaffold(
            body: NotificacoesPanelDialog(
              controller: ctrl,
              apoioController: apoioCtrl,
              onSelecionar: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Inspeção SE Teresina'), findsOneWidget);
      expect(find.text('Apoio solicitado: Apoio da operação na inspeção'), findsOneWidget);
      expect(find.text('Aguardando resposta'), findsOneWidget);
      expect(find.text('Abrir solicitação'), findsOneWidget);
      expect(find.text('Marcar como lida'), findsOneWidget);

      await tester.tap(find.text('Marcar como lida'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Não remove da lista quando filtro é "Todas", apenas muda o indicador para "Lida"
      expect(find.text('Inspeção SE Teresina'), findsOneWidget);
      expect(find.text('Lida'), findsOneWidget);

      ctrl.dispose();
      apoioCtrl.dispose();
    });
  });
}

