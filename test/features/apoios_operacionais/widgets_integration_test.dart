import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/design_system/theme/taskflow_theme.dart';
import 'package:task2026/features/apoios_operacionais/data/repositories/in_memory_task_apoio_repository.dart';
import 'package:task2026/features/apoios_operacionais/domain/enums/task_apoio_enums.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_impacto_alteracao.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_situacao.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_solicitacao.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_tipo.dart';
import 'package:task2026/features/apoios_operacionais/presentation/task_apoio_ui_controller.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/task_apoio_form_section.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/task_apoio_solicitar_dialog.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/task_apoio_table_badge.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/task_apoio_view_section.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/task_apoio_vincular_dialog.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/task_table_column.dart';
import 'package:task2026/widgets/task_table.dart';

class _SpyLoteRepo extends InMemoryTaskApoioRepository {
  int chamadasLote = 0;
  List<String> ultimoLoteIds = const [];

  @override
  Future<Map<String, TaskApoioResumo>> buscarResumosEmLote(
    List<String> taskIds,
  ) {
    chamadasLote++;
    ultimoLoteIds = List<String>.from(taskIds);
    return super.buscarResumosEmLote(taskIds);
  }
}

Widget _wrapWithTheme(
  Widget child, {
  ThemeData? theme,
  Size size = const Size(1280, 800),
}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  group('Widgets de Apoios Operacionais — Fase 4', () {
    testWidgets('TaskApoioFormSection exibe estado protegido, rascunhos e alerta de impacto sem bloquear', (tester) async {
      final ctrl = TaskApoioUiController();
      var clicouSolicitar = false;

      final rascunho = TaskApoioSolicitacao(
        id: 'rasc-1',
        taskSolicitanteTituloSnapshot: 'Nova tarefa',
        regionalSolicitanteId: 'r1',
        divisaoSolicitanteId: 'd1',
        regionalDestinoId: 'r1',
        divisaoDestinoId: 'd2',
        tipoApoioId: 'tipo-frota',
        descricao: 'Munck rascunho',
        dataInicioSolicitada: DateTime.utc(2026, 11, 23, 8),
        dataFimSolicitada: DateTime.utc(2026, 11, 25, 17),
        solicitanteUsuarioId: 'u1',
      );

      final impacto = TaskApoioImpactoAlteracao(
        taskAlteradaId: 't1',
        tipoAlteracao: TaskApoioTipoAlteracaoOrigem.reprogramacao,
        solicitacoesAfetadasIds: const ['s1'],
        vinculosAfetadosIds: const ['v1'],
        requerReconfirmacao: true,
        quebrouCompatibilidade: true,
        descricaoImpacto: 'Datas alteradas',
        detectadoEm: DateTime.utc(2026, 11, 17),
      );

      await tester.pumpWidget(
        _wrapWithTheme(
          TaskApoioFormSection(
            controller: ctrl,
            rascunhosLocais: [rascunho],
            impactoAlteracao: impacto,
            onSolicitarApoio: () => clicouSolicitar = true,
          ),
        ),
      );

      expect(find.text('Apoios Operacionais (opcional)'), findsOneWidget);
      expect(find.textContaining('comprometer 1 apoio(s)'), findsOneWidget);

      // Expandir seção
      await tester.tap(find.text('Apoios Operacionais (opcional)'));
      await tester.pumpAndSettle();

      expect(find.text('Apoios Operacionais protegidos'), findsOneWidget);
      expect(find.text('Munck rascunho'), findsOneWidget);
      expect(find.text('Solicitar apoio'), findsOneWidget);

      await tester.tap(find.text('Solicitar apoio'));
      await tester.pump();
      expect(clicouSolicitar, isTrue);
    });

    testWidgets('TaskApoioSolicitarDialog valida campos e permite opções adicionais e temas claro/escuro', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      TaskApoioSolicitacao? resultado;
      await tester.pumpWidget(
        _wrapWithTheme(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                resultado = await showDialog<TaskApoioSolicitacao>(
                  context: ctx,
                  builder: (_) => TaskApoioSolicitarDialog(
                    taskSolicitanteTitulo: 'Manut SE',
                    regionalSolicitanteId: 'r1',
                    divisaoSolicitanteId: 'd1',
                    usuarioSolicitanteId: 'u1',
                    dataInicioSugerida: DateTime.utc(2026, 11, 23, 8),
                    dataFimSugerida: DateTime.utc(2026, 11, 25, 17),
                    tiposApoio: const [
                      TaskApoioTipo(
                        id: 'tipo-frota',
                        codigo: 'FROTA_VEICULOS',
                        nome: 'Frota e veículos',
                      ),
                    ],
                    regionais: const [
                      TaskApoioUnidadeOpcao(id: 'r1', nome: 'Regional Sul'),
                    ],
                    divisoes: const [
                      TaskApoioUnidadeOpcao(
                        id: 'd2',
                        nome: 'Divisão Frota',
                        parentId: 'r1',
                      ),
                    ],
                    segmentos: const [
                      TaskApoioUnidadeOpcao(
                        id: 's2',
                        nome: 'Linhas de Transmissão',
                        parentId: 'd2',
                      ),
                    ],
                    isRascunhoPreSalvamento: true,
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
          theme: TaskFlowTheme.dark(),
          size: const Size(390, 844), // Mobile viewport
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Tentar enviar vazio -> validação impede (descrição e segmento obrigatórios)
      await tester.tap(find.text('Adicionar rascunho'));
      await tester.pumpAndSettle();
      expect(find.text('Informe o que é necessário'), findsOneWidget);
      expect(find.text('Selecione o segmento de destino'), findsOneWidget);

      // Selecionar segmento obrigatório
      await tester.tap(find.text('Segmento de destino *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Linhas de Transmissão').last);
      await tester.pumpAndSettle();

      // Preencher descrição e abrir Opções adicionais
      await tester.enterText(
        find.byType(TextFormField).first,
        'Caminhão Munck com operador',
      );
      await tester.ensureVisible(find.text('Opções adicionais (opcional)'));
      await tester.tap(find.text('Opções adicionais (opcional)'));
      await tester.pumpAndSettle();
      expect(find.text('Necessita operador alocado'), findsOneWidget);

      await tester.tap(find.text('Adicionar rascunho'));
      await tester.pumpAndSettle();

      expect(resultado, isNotNull);
      expect(resultado!.descricao, 'Caminhão Munck com operador');
      expect(resultado!.syncStatus, TaskApoioSyncStatus.pendenteSync);
    });

    testWidgets('TaskApoioVincularDialog busca sob demanda e distingue vínculo direto vs aguardando confirmação', (tester) async {
      TaskApoioVincularResultado? res;
      final tOutraUnidade = Task(
        id: 't-ext',
        status: 'PROG',
        regional: 'Regional Sul',
        divisao: 'Frota',
        divisaoId: 'div-frota',
        locais: const ['SE Norte'],
        tipo: 'APOIO',
        tarefa: 'Munck Externo',
        frota: 'Munck 01',
        coordenador: 'Coord',
        dataInicio: DateTime.utc(2026, 11, 23, 8),
        dataFim: DateTime.utc(2026, 11, 25, 17),
      );

      await tester.pumpWidget(
        _wrapWithTheme(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                res = await showDialog<TaskApoioVincularResultado>(
                  context: ctx,
                  builder: (_) => TaskApoioVincularDialog(
                    taskPrincipalId: 't-princ',
                    divisaoPrincipalId: 'div-manut',
                    onBuscarAtividades: ({
                      String? termo,
                      String? regional,
                      String? divisao,
                      String? status,
                      int limit = 20,
                      int offset = 0,
                    }) async =>
                        [tOutraUnidade],
                  ),
                );
              },
              child: const Text('AbrirVinc'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('AbrirVinc'));
      await tester.pumpAndSettle();

      expect(find.text('Munck Externo'), findsOneWidget);
      await tester.tap(find.text('Munck Externo'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('aguardando confirmação da unidade responsável'),
        findsOneWidget,
      );
      await tester.tap(find.text('Solicitar confirmação de vínculo'));
      await tester.pumpAndSettle();

      expect(res, isNotNull);
      expect(res!.autorizadoDireto, isFalse);
      expect(res!.taskSelecionada.id, 't-ext');
    });

    testWidgets('TaskApoioViewSection exibe cenários DEV (parcial c/ lacuna, compartilhado e histórico)', (tester) async {
      final ctrl = TaskApoioUiController();
      await ctrl.ativarModoDemonstracaoDev();

      final taskB = ctrl.tasksConhecidas['demo-task-b']!;
      await tester.pumpWidget(
        _wrapWithTheme(
          TaskApoioViewSection(
            task: taskB,
            controller: ctrl,
            usuarioAtualId: 'demo-user-1',
            usuarioAtualNome: 'Usuário Demo',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MODO DEMONSTRAÇÃO (DEV)'), findsOneWidget);
      expect(find.text('Parcialmente programado'), findsOneWidget);
      expect(find.textContaining('ainda não programado'), findsOneWidget);

      // Expandir linha do tempo e detalhes
      await tester.tap(find.text('Linha do tempo e detalhes'));
      await tester.pumpAndSettle();
      expect(find.text('Linha do tempo do apoio'), findsOneWidget);
      expect(find.textContaining('Solicitação registrada'), findsOneWidget);

      // Atividade prestadora de apoio compartilhado (Cenário E)
      final taskMunck = ctrl.tasksConhecidas['demo-task-a-munck']!;
      await tester.pumpWidget(
        _wrapWithTheme(
          TaskApoioViewSection(
            task: taskMunck,
            controller: ctrl,
            usuarioAtualId: 'demo-user-frota',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Apoio compartilhado: atende 3 atividades'),
        findsOneWidget,
      );
    });

    testWidgets('TaskApoioTableBadge representa ausência neutra, risco e presta apoio', (tester) async {
      final ctrl = TaskApoioUiController();
      await ctrl.ativarModoDemonstracaoDev();
      final t = ctrl.tasksConhecidas['demo-task-h']!;

      await tester.pumpWidget(
        _wrapWithTheme(
          Row(
            children: [
              TaskApoioTableBadge(
                task: t,
                resumo: const TaskApoioResumo(taskId: 'demo-task-h'),
                controller: ctrl,
                usuarioAtualId: 'u1',
              ),
              TaskApoioTableBadge(
                task: t,
                resumo: const TaskApoioResumo(
                  taskId: 'demo-task-b',
                  totalSolicitacoes: 2,
                  qtdAguardandoResposta: 0,
                  situacaoGerencial:
                      TaskApoioSituacaoGerencial.programacaoComRiscoApoio,
                ),
                controller: ctrl,
                usuarioAtualId: 'u1',
              ),
              TaskApoioTableBadge(
                task: t,
                resumo: const TaskApoioResumo(
                  taskId: 'demo-task-a-munck',
                  totalSolicitacoes: 0,
                  qtdAtividadesApoiadas: 2,
                ),
                controller: ctrl,
                usuarioAtualId: 'u1',
              ),
            ],
          ),
        ),
      );

      expect(find.text('—'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.north_east_rounded), findsOneWidget);
      expect(find.byTooltip('Solicitou apoio: Em risco — apoio (2/2)'), findsOneWidget);
      expect(find.byIcon(Icons.handshake_outlined), findsOneWidget);
      expect(find.byIcon(Icons.south_west_rounded), findsOneWidget);
      expect(find.byTooltip('Apoio solicitado por outro setor (2)'), findsOneWidget);
    });

    testWidgets('TaskTable carrega resumos de apoios em lote único (zero consultas N+1)', (tester) async {
      await tester.runAsync(() => TaskTableColumnService.instance.saveColumns({
        TaskTableColumn.status,
        TaskTableColumn.tarefa,
        TaskTableColumn.apoios,
      }));

      final spyRepo = _SpyLoteRepo();
      final ctrl = TaskApoioUiController(
        repository: spyRepo,
        disponibilidadeInicial: TaskApoioDisponibilidadeEstado.disponivel,
      );

      final tasks = List.generate(
        5,
        (i) => Task(
          id: 't-lote-$i',
          status: 'PROG',
          regional: 'REG',
          divisao: 'DIV',
          tipo: 'MANUT',
          tarefa: 'Atividade Lote $i',
          coordenador: 'Coord',
          dataInicio: DateTime.utc(2026, 11, 23, 8),
          dataFim: DateTime.utc(2026, 11, 23, 17),
        ),
      );

      final scrollCtrl = ScrollController();
      addTearDown(scrollCtrl.dispose);

      await tester.pumpWidget(
        _wrapWithTheme(
          SizedBox(
            width: 1200,
            height: 500,
            child: TaskTable(
              tasks: tasks,
              scrollController: scrollCtrl,
              apoioController: ctrl,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(spyRepo.chamadasLote, 1);
      expect(spyRepo.ultimoLoteIds.length, 5);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 15));
    });
  });
}
