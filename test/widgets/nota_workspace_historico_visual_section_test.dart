import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_historico_visual.dart';
import 'package:task2026/services/nota_historico_visual_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_historico_visual_section.dart';
import 'package:task2026/features/media_albums/data/models/media_image.dart';

class MockNotaHistoricoVisualService extends NotaHistoricoVisualService {
  final Future<HistoricoVisualResultado> Function(NotaSAP nota)? onBuscar;

  MockNotaHistoricoVisualService({this.onBuscar});

  @override
  Future<HistoricoVisualResultado> buscarHistoricoVisual(
    NotaSAP nota, {
    int limitePorNivel = 12,
  }) async {
    if (onBuscar != null) {
      return onBuscar!(nota);
    }
    return HistoricoVisualResultado.vazio(localNome: nota.local);
  }
}

Widget _wrapComTema(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: [
        TaskFlowThemeExtension.light(),
      ],
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: child,
      ),
    ),
  );
}

void main() {
  final notaMock = NotaSAP(
    id: 'nota-uuid-1',
    nota: '11007985',
    descricao: 'Subst. Isol. 085/3',
    localInstalacao: 'H-L-SIBDSSBD-RB4L01-4LT1',
    local: 'IBDSBD U1',
    sala: '085/3',
    equipamento: '11400868',
  );

  group('NotaWorkspaceHistoricoVisualSection - Testes de Widget', () {
    testWidgets('Exibe estado vazio quando nenhuma foto for encontrada', (tester) async {
      final mockService = MockNotaHistoricoVisualService(
        onBuscar: (n) async => HistoricoVisualResultado.vazio(localNome: n.local),
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoVisualSection(
            nota: notaMock,
            service: mockService,
          ),
        ),
      );

      // Aguarda resolver Future
      await tester.pumpAndSettle();

      expect(find.text('Histórico Visual do Local'), findsOneWidget);
      expect(find.text('SOMENTE LEITURA'), findsOneWidget);
      expect(find.text('IBDSBD U1'), findsOneWidget);
      expect(find.text('Sala: 085/3'), findsOneWidget);
      expect(
        find.text('Nenhuma fotografia encontrada para o local "IBDSBD U1" e sala "085/3".'),
        findsOneWidget,
      );
    });

    testWidgets('Exibe resultado com contadores e badges quando houver histórico', (tester) async {
      final itemEquip = HistoricoVisualItem(
        mediaImage: MediaImage(
          id: 'img-1',
          title: 'Isolador quebrado',
          filePath: 'path/1.jpg',
          createdBy: 'user-1',
          createdAt: DateTime(2025, 3, 14),
          updatedAt: DateTime(2025, 3, 14),
        ),
        nivel: HistoricoVisualNivel.equipamento,
        motivoCorrespondencia: 'Mesmo Equipamento SAP (11400868)',
        localNome: 'IBDSBD U1',
        createdAt: DateTime(2025, 3, 14),
      );

      final itemSala = HistoricoVisualItem(
        mediaImage: MediaImage(
          id: 'img-2',
          title: 'Base da torre',
          filePath: 'path/2.jpg',
          createdBy: 'user-1',
          createdAt: DateTime(2025, 2, 10),
          updatedAt: DateTime(2025, 2, 10),
        ),
        nivel: HistoricoVisualNivel.sala,
        motivoCorrespondencia: 'Mesma Estrutura (085/3)',
        localNome: 'IBDSBD U1',
        createdAt: DateTime(2025, 2, 10),
      );

      final mockService = MockNotaHistoricoVisualService(
        onBuscar: (n) async => HistoricoVisualResultado(
          itens: [itemEquip, itemSala],
          totalEquipamento: 1,
          totalSala: 1,
          totalLocal: 15,
          localNome: 'IBDSBD U1',
        ),
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoVisualSection(
            nota: notaMock,
            service: mockService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica cabeçalho e contadores
      expect(find.text('Histórico Visual do Local'), findsOneWidget);
      expect(find.text('Abrir no Módulo de Álbuns'), findsOneWidget);
      expect(find.text('Equipamento'), findsWidgets);
      expect(find.text('Sala / Estrutura'), findsWidgets);

      // Verifica cards com títulos e motivos
      expect(find.text('Isolador quebrado'), findsOneWidget);
      expect(find.text('Base da torre'), findsOneWidget);
      expect(find.text('Mesmo Equipamento SAP (11400868)'), findsOneWidget);
      expect(find.text('Mesma Estrutura (085/3)'), findsOneWidget);

      // Verifica botão para alternar fotos amplas do local
      expect(find.text('Ver +15 fotos do mesmo local'), findsOneWidget);
    });

    testWidgets('Exibe estado de erro e botão tentar novamente quando falhar', (tester) async {
      int chamadas = 0;
      final mockService = MockNotaHistoricoVisualService(
        onBuscar: (n) async {
          chamadas++;
          if (chamadas == 1) {
            throw Exception('Falha de rede simulada');
          }
          return HistoricoVisualResultado.vazio(localNome: n.local);
        },
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoVisualSection(
            nota: notaMock,
            service: mockService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Não foi possível carregar o histórico visual.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);

      // Clica em tentar novamente
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(chamadas, 2);
      expect(
        find.text('Nenhuma fotografia encontrada para o local "IBDSBD U1" e sala "085/3".'),
        findsOneWidget,
      );
    });

    testWidgets('Abre visualizador em galeria e permite passar para o lado', (tester) async {
      final mockService = MockNotaHistoricoVisualService(
        onBuscar: (n) async => HistoricoVisualResultado(
          itens: [
            HistoricoVisualItem(
              mediaImage: MediaImage(
                id: 'foto-1',
                title: 'Isolador quebrado',
                filePath: 'caminho/1.jpg',
                fileUrl: 'http://localhost/1.jpg',
                createdBy: 'user-1',
                createdAt: DateTime.now().subtract(const Duration(days: 30)),
                updatedAt: DateTime.now(),
              ),
              nivel: HistoricoVisualNivel.equipamento,
              motivoCorrespondencia: 'Mesmo Equipamento SAP (11400868)',
              localNome: 'IBDSBD U1',
              createdAt: DateTime.now().subtract(const Duration(days: 30)),
            ),
            HistoricoVisualItem(
              mediaImage: MediaImage(
                id: 'foto-2',
                title: 'Base da torre',
                filePath: 'caminho/2.jpg',
                fileUrl: 'http://localhost/2.jpg',
                createdBy: 'user-2',
                createdAt: DateTime.now().subtract(const Duration(days: 60)),
                updatedAt: DateTime.now(),
              ),
              nivel: HistoricoVisualNivel.sala,
              motivoCorrespondencia: 'Mesma Estrutura (085/3)',
              localNome: 'IBDSBD U1',
              createdAt: DateTime.now().subtract(const Duration(days: 60)),
            ),
          ],
          totalEquipamento: 1,
          totalSala: 1,
          totalLocal: 0,
          raizSapIdentificada: 'SIBDSSBD',
          localNome: 'IBDSBD U1',
        ),
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoVisualSection(
            nota: notaMock,
            service: mockService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Rola até o card da primeira foto e clica para abrir o viewer
      await tester.ensureVisible(find.text('Isolador quebrado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Isolador quebrado'));
      await tester.pumpAndSettle();

      // Verifica que o viewer de histórico abriu com contador 1 de 2
      expect(find.text('1 de 2'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      expect(find.byIcon(Icons.rotate_90_degrees_cw_outlined), findsOneWidget);

      // Clica para navegar para a próxima foto (passar para o lado)
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pumpAndSettle();

      // Verifica que o viewer avançou para a foto 2 de 2
      expect(find.text('2 de 2'), findsOneWidget);
      expect(find.text('Base da torre'), findsWidgets);

      // Fecha o viewer
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Confirma que voltou para a tela da seção
      expect(find.text('Histórico Visual do Local'), findsOneWidget);
    });
  });
}
