import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/media_albums/data/models/media_image.dart';
import 'package:task2026/features/media_albums/data/models/status_album.dart';
import 'package:task2026/features/media_albums/presentation/pages/status_album_form_dialog.dart';
import 'package:task2026/features/media_albums/presentation/widgets/media_card.dart';
import 'package:task2026/features/media_albums/presentation/widgets/status_badge.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('StatusBadge Tests', () {
    testWidgets('mapeia severidades e renderiza status do enum legado e do statusAlbum', (tester) async {
      expect(StatusBadge.mapSeverity('OK / Concluído'), TFStatusSeverity.success);
      expect(StatusBadge.mapSeverity('Alerta Crítico'), TFStatusSeverity.danger);
      expect(StatusBadge.mapSeverity('Em Revisão'), TFStatusSeverity.warning);
      expect(StatusBadge.mapSeverity('Desconhecido'), TFStatusSeverity.neutral);

      // Render com enum fallback
      await tester.pumpWidget(_wrap(const StatusBadge(status: MediaImageStatus.ok)));
      await tester.pumpAndSettle();
      expect(find.text('Aprovado'), findsOneWidget);

      // Render com statusAlbum customizado
      final customStatus = StatusAlbum(
        id: 'st-01',
        nome: 'Em Campo',
        corFundo: '#2E7D32',
        corTexto: '#FFFFFF',
        ordem: 1,
        ativo: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(_wrap(StatusBadge(
        status: MediaImageStatus.review,
        statusAlbum: customStatus,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Em Campo'), findsOneWidget);
    });
  });

  group('MediaCard Tests', () {
    final sampleImage = MediaImage(
      id: 'img-001',
      title: 'Foto Termográfica SE Leste',
      filePath: 'photos/photo1.jpg',
      status: MediaImageStatus.ok,
      tags: ['Subestacao', 'Transformador', 'Inspecao'],
      createdBy: 'user-01',
      creatorName: 'Carlos Silva',
      createdAt: DateTime(2026, 3, 10, 14, 30),
      updatedAt: DateTime(2026, 3, 10, 14, 30),
    );

    testWidgets('renderiza metadados, status e tags da imagem', (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        width: 320,
        height: 380,
        child: MediaCard(
          image: sampleImage,
          onTap: () {},
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Foto Termográfica SE Leste'), findsOneWidget);
      expect(find.text('Aprovado'), findsOneWidget);
      expect(find.text('#Subestacao'), findsOneWidget);
      expect(find.text('#Transformador'), findsOneWidget);
    });

    testWidgets('renderiza corretamente nos três temas oficiais', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(_wrap(
          SizedBox(
            width: 320,
            height: 380,
            child: MediaCard(image: sampleImage, onTap: () {}),
          ),
          theme: theme,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Foto Termográfica SE Leste'), findsOneWidget);
        expect(find.text('Aprovado'), findsOneWidget);
      }
    });
  });

  group('StatusAlbumFormDialog Tests', () {
    testWidgets('renderiza formulário com campos de nome, ordem, ativo e botões TFDS', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: TaskFlowTheme.light(),
        home: const Scaffold(
          body: StatusAlbumFormDialog(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(StatusAlbumFormDialog), findsOneWidget);
      expect(find.byType(TFFormDialog), findsOneWidget);
      expect(find.text('Novo Status de Álbum'), findsOneWidget);
    });
  });
}
