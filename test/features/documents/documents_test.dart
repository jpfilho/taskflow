import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/documents/data/models/document.dart';
import 'package:task2026/features/documents/data/models/document_status.dart';
import 'package:task2026/features/documents/presentation/widgets/document_card.dart';
import 'package:task2026/features/documents/presentation/widgets/document_status_badge.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('DocumentStatusBadge Tests', () {
    testWidgets('mapeia severidades e renderiza texto do status corretamente', (tester) async {
      expect(DocumentStatusBadge.mapSeverity('Aprovado'), TFStatusSeverity.success);
      expect(DocumentStatusBadge.mapSeverity('Pendente de Revisão'), TFStatusSeverity.warning);
      expect(DocumentStatusBadge.mapSeverity('Rejeitado'), TFStatusSeverity.danger);
      expect(DocumentStatusBadge.mapSeverity('Rascunho'), TFStatusSeverity.info);
      expect(DocumentStatusBadge.mapSeverity('Desconhecido'), TFStatusSeverity.neutral);

      const status = DocumentStatus(
        id: 'st-01',
        nome: 'Publicado',
      );

      await tester.pumpWidget(_wrap(const DocumentStatusBadge(status: status)));
      await tester.pumpAndSettle();

      expect(find.text('Publicado'), findsOneWidget);
    });

    testWidgets('renderiza status com cores personalizadas quando disponíveis', (tester) async {
      const customStatus = DocumentStatus(
        id: 'st-custom',
        nome: 'Personalizado',
        corFundo: '#1E88E5',
        corTexto: '#FFFFFF',
      );

      await tester.pumpWidget(_wrap(const DocumentStatusBadge(status: customStatus)));
      await tester.pumpAndSettle();

      expect(find.text('Personalizado'), findsOneWidget);
    });
  });

  group('DocumentCard Tests', () {
    final sampleDoc = Document(
      id: 'doc-001',
      title: 'Manual de Procedimentos Operacionais SE Central',
      description: 'Documento técnico descrevendo manutenção preventiva',
      file: const DocumentFile(
        path: 'documents/manual.pdf',
        mimeType: 'application/pdf',
        extension: 'pdf',
        size: 1048576,
      ),
      creatorName: 'Carlos Engenheiro',
      tags: ['Manutencao', '2026', 'Operacao'],
      regionalName: 'Regional Leste',
      divisaoName: 'Divisão Norte',
      statusDocument: const DocumentStatus(id: 'st-01', nome: 'Aprovado'),
      createdBy: 'user-1',
      createdAt: DateTime(2026, 3, 10),
      updatedAt: DateTime(2026, 3, 10),
    );

    testWidgets('renderiza metadados, título, tags, badge e autor', (tester) async {
      await tester.pumpWidget(_wrap(DocumentCard(document: sampleDoc)));
      await tester.pumpAndSettle();

      expect(find.text('Manual de Procedimentos Operacionais SE Central'), findsOneWidget);
      expect(find.text('Documento técnico descrevendo manutenção preventiva'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Aprovado'), findsOneWidget);
      expect(find.text('Carlos Engenheiro'), findsOneWidget);
      expect(find.text('#Manutencao'), findsOneWidget);
    });

    testWidgets('dispara callback de download e onTap', (tester) async {
      bool downloadTapped = false;
      bool cardTapped = false;

      await tester.pumpWidget(_wrap(DocumentCard(
        document: sampleDoc,
        onDownload: () => downloadTapped = true,
        onTap: () => cardTapped = true,
      )));
      await tester.pumpAndSettle();

      final downloadIcon = find.byIcon(TFIcons.download);
      expect(downloadIcon, findsOneWidget);
      await tester.tap(downloadIcon);
      expect(downloadTapped, isTrue);

      await tester.tap(find.byType(TFCard));
      expect(cardTapped, isTrue);
    });

    testWidgets('renderiza corretamente nos temas Light, Dark e AXIA', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(_wrap(DocumentCard(document: sampleDoc), theme: theme));
        await tester.pumpAndSettle();

        expect(find.text('Manual de Procedimentos Operacionais SE Central'), findsOneWidget);
        expect(find.text('Aprovado'), findsOneWidget);
      }
    });
  });
}
