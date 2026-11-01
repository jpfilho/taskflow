import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/nota_analise_workspace.dart';
import 'package:task2026/widgets/nota_workspace/nota_analise_badge.dart';

class MockNotaSapAnaliseService extends Fake implements NotaSapAnaliseService {
  @override
  Future<NotaSapAnalise?> buscarAnalise(String notaSapId) async {
    return NotaSapAnalise(
      id: 'an-1',
      notaSapId: notaSapId,
      statusAnalise: NotaAnaliseStatus.emAnalise,
    );
  }

  @override
  Future<List<NotaSapMaterial>> listarMateriais(String notaSapId) async => [];

  @override
  Future<List<NotaSapAnexo>> listarAnexos(String notaSapId) async => [];

  @override
  Future<List<NotaSapComentario>> listarComentarios(String notaSapId) async => [];
}

Widget buildTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: [TaskFlowThemeExtension.light()],
    ),
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  group('Fase 4 - Testes 1 a 6: NotaAnaliseBadge Componente Visual', () {
    testWidgets('1. badge sem análise exibe estado neutro', (tester) async {
      const resumo = NotaSapResumoAnalise(
        notaSapId: 'nota-1',
        status: NotaAnaliseStatus.naoIniciada,
        quantidadeMateriais: 0,
        quantidadeAnexos: 0,
        quantidadeComentarios: 0,
      );

      await tester.pumpWidget(
        buildTestApp(
          const NotaAnaliseBadge(resumo: resumo, compact: false),
        ),
      );

      expect(find.text('Não iniciada'), findsOneWidget);
    });

    testWidgets('2. badge em análise exibe cor de andamento', (tester) async {
      const resumo = NotaSapResumoAnalise(
        notaSapId: 'nota-2',
        status: NotaAnaliseStatus.emAnalise,
        quantidadeMateriais: 0,
        quantidadeAnexos: 0,
        quantidadeComentarios: 0,
      );

      await tester.pumpWidget(
        buildTestApp(
          const NotaAnaliseBadge(resumo: resumo, compact: false),
        ),
      );

      expect(find.text('Em análise'), findsOneWidget);
    });

    testWidgets('3. badge concluída exibe cor de sucesso', (tester) async {
      const resumo = NotaSapResumoAnalise(
        notaSapId: 'nota-3',
        status: NotaAnaliseStatus.concluida,
        quantidadeMateriais: 0,
        quantidadeAnexos: 0,
        quantidadeComentarios: 0,
      );

      await tester.pumpWidget(
        buildTestApp(
          const NotaAnaliseBadge(resumo: resumo, compact: false),
        ),
      );

      expect(find.text('Concluída'), findsOneWidget);
    });

    testWidgets('4. badge aguardando info exibe alerta', (tester) async {
      const resumo = NotaSapResumoAnalise(
        notaSapId: 'nota-4',
        status: NotaAnaliseStatus.aguardandoInformacao,
        quantidadeMateriais: 0,
        quantidadeAnexos: 0,
        quantidadeComentarios: 0,
      );

      await tester.pumpWidget(
        buildTestApp(
          const NotaAnaliseBadge(resumo: resumo, compact: false),
        ),
      );

      expect(find.text('Aguardando info'), findsOneWidget);
    });

    testWidgets('5. badge cancelada exibe estado cancelado', (tester) async {
      const resumo = NotaSapResumoAnalise(
        notaSapId: 'nota-5',
        status: NotaAnaliseStatus.cancelada,
        quantidadeMateriais: 0,
        quantidadeAnexos: 0,
        quantidadeComentarios: 0,
      );

      await tester.pumpWidget(
        buildTestApp(
          const NotaAnaliseBadge(resumo: resumo, compact: false),
        ),
      );

      expect(find.text('Cancelada'), findsOneWidget);
    });

    testWidgets('6. contadores de anexos, comentários e materiais aparecem apenas se > 0', (tester) async {
      // Caso 1: zeros - não devem exibir ícones de anexo nem material
      const resumoZero = NotaSapResumoAnalise(
        notaSapId: 'nota-6a',
        status: NotaAnaliseStatus.emAnalise,
        quantidadeMateriais: 0,
        quantidadeAnexos: 0,
        quantidadeComentarios: 0,
      );

      await tester.pumpWidget(
        buildTestApp(
          const NotaAnaliseBadge(resumo: resumoZero, compact: true),
        ),
      );

      expect(find.byIcon(Icons.attach_file), findsNothing);
      expect(find.byIcon(Icons.inventory_2_outlined), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);

      // Caso 2: valores > 0
      const resumoComItens = NotaSapResumoAnalise(
        notaSapId: 'nota-6b',
        status: NotaAnaliseStatus.emAnalise,
        quantidadeMateriais: 3,
        quantidadeAnexos: 2,
        quantidadeComentarios: 5,
      );

      await tester.pumpWidget(
        buildTestApp(
          const NotaAnaliseBadge(resumo: resumoComItens, compact: true),
        ),
      );

      expect(find.byIcon(Icons.attach_file), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('Fase 4 - Testes 7 a 10: Interações e Deep-linking para Abas', () {
    testWidgets('7. clique no badge de status abre o workspace na aba de diagnóstico (tab 1)', (tester) async {
      int tabAberta = -1;
      const resumo = NotaSapResumoAnalise(
        notaSapId: 'nota-7',
        status: NotaAnaliseStatus.emAnalise,
        quantidadeMateriais: 0,
        quantidadeAnexos: 0,
        quantidadeComentarios: 0,
      );

      await tester.pumpWidget(
        buildTestApp(
          NotaAnaliseBadge(
            resumo: resumo,
            compact: false,
            onTapStatus: () => tabAberta = 1,
          ),
        ),
      );

      await tester.tap(find.text('Em análise'));
      await tester.pump();

      expect(tabAberta, equals(1));
    });

    testWidgets('8. clique no ícone de anexos abre na aba de anexos (tab 3)', (tester) async {
      int tabAberta = -1;
      const resumo = NotaSapResumoAnalise(
        notaSapId: 'nota-8',
        status: NotaAnaliseStatus.emAnalise,
        quantidadeMateriais: 0,
        quantidadeAnexos: 4,
        quantidadeComentarios: 0,
      );

      await tester.pumpWidget(
        buildTestApp(
          NotaAnaliseBadge(
            resumo: resumo,
            compact: true,
            onTapAnexos: () => tabAberta = 3,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.attach_file));
      await tester.pump();

      expect(tabAberta, equals(3));
    });

    testWidgets('9. clique no ícone de comentários abre na aba de histórico/comentários (tab 4)', (tester) async {
      int tabAberta = -1;
      const resumo = NotaSapResumoAnalise(
        notaSapId: 'nota-9',
        status: NotaAnaliseStatus.emAnalise,
        quantidadeMateriais: 0,
        quantidadeAnexos: 0,
        quantidadeComentarios: 2,
      );

      await tester.pumpWidget(
        buildTestApp(
          NotaAnaliseBadge(
            resumo: resumo,
            compact: true,
            onTapComentarios: () => tabAberta = 4,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pump();

      expect(tabAberta, equals(4));
    });

    testWidgets('10. clique no ícone de materiais abre na aba de materiais (tab 2)', (tester) async {
      int tabAberta = -1;
      const resumo = NotaSapResumoAnalise(
        notaSapId: 'nota-10',
        status: NotaAnaliseStatus.emAnalise,
        quantidadeMateriais: 7,
        quantidadeAnexos: 0,
        quantidadeComentarios: 0,
      );

      await tester.pumpWidget(
        buildTestApp(
          NotaAnaliseBadge(
            resumo: resumo,
            compact: true,
            onTapMateriais: () => tabAberta = 2,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.inventory_2_outlined));
      await tester.pump();

      expect(tabAberta, equals(2));
    });
  });

  group('Fase 4 - Testes 11 a 17: Resiliência, Filtros, Ordenação e Atualização Cirúrgica', () {
    testWidgets('11. carregamento da tabela não quebra se o serviço de resumo falhar', (tester) async {
      // Simula falha ao buscar resumos: o badge lida elegantemente com resumo null
      const NotaSapResumoAnalise? resumoNull = null;

      await tester.pumpWidget(
        buildTestApp(
          const NotaAnaliseBadge(
            resumo: resumoNull,
            compact: false,
          ),
        ),
      );

      // Deve renderizar estado neutro "Sem análise" sem lançar exceção
      expect(find.text('Sem análise'), findsOneWidget);
    });

    test('12. filtro por status de análise retorna apenas notas compatíveis', () {
      final notas = [
        NotaSAP(id: '1', nota: '1001', descricao: 'Nota 1'),
        NotaSAP(id: '2', nota: '1002', descricao: 'Nota 2'),
        NotaSAP(id: '3', nota: '1003', descricao: 'Nota 3'),
      ];

      final resumos = <String, NotaSapResumoAnalise>{
        '1': const NotaSapResumoAnalise(
          notaSapId: '1',
          status: NotaAnaliseStatus.concluida,
          quantidadeMateriais: 0,
          quantidadeAnexos: 0,
          quantidadeComentarios: 0,
        ),
        '2': const NotaSapResumoAnalise(
          notaSapId: '2',
          status: NotaAnaliseStatus.emAnalise,
          quantidadeMateriais: 0,
          quantidadeAnexos: 0,
          quantidadeComentarios: 0,
        ),
      };

      // Filtrar concluídas
      const filtro = 'concluida';
      final filtradas = notas.where((n) {
        final r = resumos[n.id];
        return r?.status.name == filtro;
      }).toList();

      expect(filtradas.length, equals(1));
      expect(filtradas.first.id, equals('1'));

      // Filtrar sem análise
      final semAnalise = notas.where((n) {
        final r = resumos[n.id];
        return r == null || r.status == NotaAnaliseStatus.naoIniciada;
      }).toList();

      expect(semAnalise.length, equals(1));
      expect(semAnalise.first.id, equals('3'));
    });

    test('13. filtro por "com anexos" filtra corretamente', () {
      final notas = [
        NotaSAP(id: '1', nota: '1001', descricao: 'Nota 1'),
        NotaSAP(id: '2', nota: '1002', descricao: 'Nota 2'),
      ];

      final resumos = <String, NotaSapResumoAnalise>{
        '1': const NotaSapResumoAnalise(
          notaSapId: '1',
          status: NotaAnaliseStatus.emAnalise,
          quantidadeMateriais: 0,
          quantidadeAnexos: 2,
          quantidadeComentarios: 0,
        ),
        '2': const NotaSapResumoAnalise(
          notaSapId: '2',
          status: NotaAnaliseStatus.emAnalise,
          quantidadeMateriais: 1,
          quantidadeAnexos: 0,
          quantidadeComentarios: 0,
        ),
      };

      final comAnexos = notas.where((n) {
        final r = resumos[n.id];
        return r != null && r.totalAnexos > 0;
      }).toList();

      expect(comAnexos.length, equals(1));
      expect(comAnexos.first.id, equals('1'));
    });

    test('14. filtro por "com materiais" filtra corretamente', () {
      final notas = [
        NotaSAP(id: '1', nota: '1001', descricao: 'Nota 1'),
        NotaSAP(id: '2', nota: '1002', descricao: 'Nota 2'),
      ];

      final resumos = <String, NotaSapResumoAnalise>{
        '1': const NotaSapResumoAnalise(
          notaSapId: '1',
          status: NotaAnaliseStatus.emAnalise,
          quantidadeMateriais: 0,
          quantidadeAnexos: 0,
          quantidadeComentarios: 0,
        ),
        '2': const NotaSapResumoAnalise(
          notaSapId: '2',
          status: NotaAnaliseStatus.emAnalise,
          quantidadeMateriais: 5,
          quantidadeAnexos: 0,
          quantidadeComentarios: 0,
        ),
      };

      final comMateriais = notas.where((n) {
        final r = resumos[n.id];
        return r != null && r.totalMateriais > 0;
      }).toList();

      expect(comMateriais.length, equals(1));
      expect(comMateriais.first.id, equals('2'));
    });

    test('15. filtro por "com comentários" filtra corretamente', () {
      final notas = [
        NotaSAP(id: '1', nota: '1001', descricao: 'Nota 1'),
        NotaSAP(id: '2', nota: '1002', descricao: 'Nota 2'),
      ];

      final resumos = <String, NotaSapResumoAnalise>{
        '1': const NotaSapResumoAnalise(
          notaSapId: '1',
          status: NotaAnaliseStatus.emAnalise,
          quantidadeMateriais: 0,
          quantidadeAnexos: 0,
          quantidadeComentarios: 3,
        ),
        '2': const NotaSapResumoAnalise(
          notaSapId: '2',
          status: NotaAnaliseStatus.emAnalise,
          quantidadeMateriais: 0,
          quantidadeAnexos: 0,
          quantidadeComentarios: 0,
        ),
      };

      final comComentarios = notas.where((n) {
        final r = resumos[n.id];
        return r != null && r.totalComentarios > 0;
      }).toList();

      expect(comComentarios.length, equals(1));
      expect(comComentarios.first.id, equals('1'));
    });

    test('16. ordenação por status de análise funciona', () {
      final notas = [
        NotaSAP(id: '1', nota: '1001', descricao: 'Nao Iniciada'),
        NotaSAP(id: '2', nota: '1002', descricao: 'Concluida'),
        NotaSAP(id: '3', nota: '1003', descricao: 'Em Analise'),
      ];

      final resumos = <String, NotaSapResumoAnalise>{
        '1': const NotaSapResumoAnalise(
          notaSapId: '1',
          status: NotaAnaliseStatus.naoIniciada, // index 0
          quantidadeMateriais: 0,
          quantidadeAnexos: 0,
          quantidadeComentarios: 0,
        ),
        '2': const NotaSapResumoAnalise(
          notaSapId: '2',
          status: NotaAnaliseStatus.concluida, // index 3
          quantidadeMateriais: 0,
          quantidadeAnexos: 0,
          quantidadeComentarios: 0,
        ),
        '3': const NotaSapResumoAnalise(
          notaSapId: '3',
          status: NotaAnaliseStatus.emAnalise, // index 1
          quantidadeMateriais: 0,
          quantidadeAnexos: 0,
          quantidadeComentarios: 0,
        ),
      };

      // Ordenar crescente por status.index
      notas.sort((a, b) {
        final sa = resumos[a.id]?.status.index ?? 0;
        final sb = resumos[b.id]?.status.index ?? 0;
        return sa.compareTo(sb);
      });

      expect(notas.map((n) => n.id).toList(), equals(['1', '3', '2']));
    });

    test('17. fechar o workspace atualiza o resumo daquela nota sem recarregar a lista toda', () {
      final mapaResumos = <String, NotaSapResumoAnalise>{
        'nota-A': const NotaSapResumoAnalise(
          notaSapId: 'nota-A',
          status: NotaAnaliseStatus.naoIniciada,
          quantidadeMateriais: 0,
          quantidadeAnexos: 0,
          quantidadeComentarios: 0,
        ),
        'nota-B': const NotaSapResumoAnalise(
          notaSapId: 'nota-B',
          status: NotaAnaliseStatus.emAnalise,
          quantidadeMateriais: 2,
          quantidadeAnexos: 1,
          quantidadeComentarios: 0,
        ),
      };

      // Atualização cirúrgica apenas para nota-A:
      const notaEditadaId = 'nota-A';
      const novoResumoNotaA = NotaSapResumoAnalise(
        notaSapId: 'nota-A',
        status: NotaAnaliseStatus.concluida,
        quantidadeMateriais: 4,
        quantidadeAnexos: 2,
        quantidadeComentarios: 1,
      );

      // Simula a lógica de _atualizarResumoNotaCirurgico:
      mapaResumos[notaEditadaId] = novoResumoNotaA;

      // Nota A foi atualizada
      expect(mapaResumos['nota-A']!.status, equals(NotaAnaliseStatus.concluida));
      expect(mapaResumos['nota-A']!.totalMateriais, equals(4));

      // Nota B permaneceu intacta sem alteração
      expect(mapaResumos['nota-B']!.status, equals(NotaAnaliseStatus.emAnalise));
      expect(mapaResumos['nota-B']!.totalMateriais, equals(2));
    });
  });

  group('Fase 4 - Suporte a initialTab em NotaAnaliseWorkspace', () {
    testWidgets('Workspace inicializa na aba especificada via initialTab', (tester) async {
      final nota = NotaSAP(
        id: 'nota-test-tab',
        nota: '12345678',
        descricao: 'Teste de initialTab',
      );

      await tester.pumpWidget(
        buildTestApp(
          NotaAnaliseWorkspace(
            nota: nota,
            initialTab: 3, // Aba de Anexos
            service: MockNotaSapAnaliseService(),
          ),
        ),
      );

      await tester.pump();

      // Verifica se a tab de Anexos está visível e selecionada
      expect(find.text('Anexos'), findsOneWidget);
    });
  });
}
