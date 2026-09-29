import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/feriado.dart';
import 'package:task2026/models/regra_prazo_nota.dart';
import 'package:task2026/models/frota.dart';
import 'package:task2026/models/executor.dart';
import 'package:task2026/widgets/feriado_form_dialog.dart';
import 'package:task2026/widgets/regra_prazo_nota_form_dialog.dart';
import 'package:task2026/widgets/frota_form_dialog.dart';
import 'package:task2026/widgets/executor_form_dialog.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await SupabaseConfig.initialize();
    } catch (_) {}
  });

  group('Admin Closure — FeriadoFormDialog', () {
    testWidgets('renderiza em modo criacao', (tester) async {
      await tester.pumpWidget(_wrap(const FeriadoFormDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Novo Feriado'), findsOneWidget);
      expect(find.text('Criar Feriado'), findsOneWidget);
      expect(find.byType(TFTextField), findsWidgets);
    });

    testWidgets('renderiza em modo edicao com valores iniciais', (tester) async {
      final feriado = Feriado(
        id: 'fer-1',
        data: DateTime(2026, 12, 25),
        descricao: 'Natal',
        tipo: 'NACIONAL',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(_wrap(FeriadoFormDialog(feriado: feriado)));
      await tester.pumpAndSettle();

      expect(find.text('Editar Feriado'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('Natal'), findsOneWidget);
    });
  });

  group('Admin Closure — RegraPrazoNotaFormDialog', () {
    testWidgets('renderiza em modo criacao', (tester) async {
      await tester.pumpWidget(_wrap(const RegraPrazoNotaFormDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Nova Regra de Prazo'), findsOneWidget);
      expect(find.text('Criar Regra'), findsOneWidget);
      expect(find.byType(TFDropdown<String>), findsWidgets);
    });

    testWidgets('renderiza em modo edicao com dados existentes', (tester) async {
      final regra = RegraPrazoNota(
        id: 'reg-1',
        prioridade: 'Alta',
        diasPrazo: 5,
        dataReferencia: 'criacao',
        segmentoIds: [],
        ativo: true,
        descricao: 'Prazo normal para alta',
      );

      await tester.pumpWidget(_wrap(RegraPrazoNotaFormDialog(regra: regra)));
      await tester.pumpAndSettle();

      expect(find.text('Editar Regra de Prazo'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Prazo normal para alta'), findsOneWidget);
    });
  });

  group('Admin Closure — FrotaFormDialog', () {
    testWidgets('renderiza em modo criacao com campos TFDS', (tester) async {
      await tester.pumpWidget(_wrap(const FrotaFormDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Nova Frota'), findsOneWidget);
      expect(find.text('Criar Frota'), findsOneWidget);
      expect(find.byType(TFSwitch), findsWidgets);
    });

    testWidgets('renderiza em modo edicao com dados preenchidos', (tester) async {
      final frota = Frota(
        id: 'fr-1',
        nome: 'Picape 10',
        marca: 'Toyota',
        tipoVeiculo: 'PICKUP',
        placa: 'BRA2E19',
        ativo: true,
        emManutencao: false,
      );

      await tester.pumpWidget(_wrap(FrotaFormDialog(frota: frota)));
      await tester.pumpAndSettle();

      expect(find.text('Editar Frota'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('Picape 10'), findsOneWidget);
      expect(find.text('BRA2E19'), findsOneWidget);
    });
  });

  group('Admin Closure — ExecutorFormDialog', () {
    testWidgets('renderiza em modo criacao', (tester) async {
      await tester.pumpWidget(_wrap(const ExecutorFormDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Novo Executor'), findsOneWidget);
      expect(find.text('Criar Executor'), findsOneWidget);
      expect(find.byType(TFTextField), findsWidgets);
    });

    testWidgets('renderiza em modo edicao com valores iniciais', (tester) async {
      final executor = Executor(
        id: 'ex-1',
        nome: 'João Silva',
        nomeCompleto: 'João da Silva Sauro',
        matricula: '998877',
        login: 'jsilva',
        ramal: '1234',
        telefone: '11999998888',
        ativo: true,
      );

      await tester.pumpWidget(_wrap(ExecutorFormDialog(executor: executor)));
      await tester.pumpAndSettle();

      expect(find.text('Editar Executor'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('João Silva'), findsOneWidget);
      expect(find.text('998877'), findsOneWidget);
    });
  });
}
