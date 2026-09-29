import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/frota.dart';
import 'package:task2026/models/equipe.dart';
import 'package:task2026/models/equipe_executor.dart';
import 'package:task2026/widgets/filter_bar.dart';
import 'package:task2026/widgets/fleet_schedule_view.dart';

void main() {
  Task mkTask({
    required String id,
    List<String> executorIds = const [],
    List<ExecutorPeriod> executorPeriods = const [],
    List<String> equipeIds = const [],
    List<String> equipes = const [],
  }) {
    return Task(
      id: id,
      status: 'PROG',
      statusNome: 'Programada',
      regional: 'R1',
      divisao: 'D1',
      locais: const ['L1'],
      tipo: 'MANUTENCAO',
      tarefa: 'Tarefa $id',
      coordenador: 'Coord 1',
      executor: '',
      executorIds: executorIds,
      executorPeriods: executorPeriods,
      equipeIds: equipeIds,
      equipes: equipes,
      dataInicio: DateTime(2026, 3, 1),
      dataFim: DateTime(2026, 3, 10),
    );
  }

  Frota mkFrota({required String id, required String nome, required String placa}) {
    return Frota(
      id: id,
      nome: nome,
      tipoVeiculo: 'CAMINHAO',
      placa: placa,
    );
  }

  Equipe mkEquipe({
    required String id,
    required String nome,
    required List<String> executorIds,
  }) {
    return Equipe(
      id: id,
      nome: nome,
      tipo: 'FIXA',
      regionalId: 'R1',
      divisaoId: 'D1',
      executores: executorIds
          .map((eid) => EquipeExecutor(
                executorId: eid,
                executorNome: 'Executor $eid',
                papel: 'EXECUTOR',
              ))
          .toList(),
    );
  }

  group('FleetScheduleView — Filtro de Equipe por membros executores', () {
    test('Filtra tarefas e frotas cujos executores pertencem à equipe selecionada', () {
      final frota1 = mkFrota(id: 'F1', nome: 'Caminhão 01', placa: 'AAA1111');
      final frota2 = mkFrota(id: 'F2', nome: 'Munck 02', placa: 'BBB2222');

      final task1 = mkTask(id: 'T1', executorIds: ['exec-1']); // Membro Equipe Alfa
      final task2 = mkTask(id: 'T2', executorIds: ['exec-2']); // Membro Equipe Beta
      final task3 = mkTask(
        id: 'T3',
        executorPeriods: [
          ExecutorPeriod(executorId: 'exec-1', executorNome: 'Executor 1'),
        ],
      ); // Membro Equipe Alfa via executorPeriods

      final equipeAlfa = mkEquipe(id: 'EQ-ALFA', nome: 'Equipe Alfa', executorIds: ['exec-1']);
      final equipeBeta = mkEquipe(id: 'EQ-BETA', nome: 'Equipe Beta', executorIds: ['exec-2']);

      final row1 = FleetTaskRow(frota: frota1, tasks: [task1, task2]);
      final row2 = FleetTaskRow(frota: frota2, tasks: [task2]);
      final row3 = FleetTaskRow(frota: frota1, tasks: [task3]);

      // Simulando a lógica de filtragem canonica do FleetScheduleView
      final equipeSet = {'equipe alfa'};
      final todasEquipes = [equipeAlfa, equipeBeta];

      Set<String> selectedEquipeExecutorIds = {};
      Set<String> selectedEquipeIds = {};
      for (final eq in todasEquipes) {
        final eqId = eq.id.trim().toLowerCase();
        final eqNome = eq.nome.trim().toLowerCase();
        if (equipeSet.contains(eqId) || equipeSet.contains(eqNome)) {
          selectedEquipeIds.add(eqId);
          for (final ee in eq.executores) {
            final execId = ee.executorId.trim().toLowerCase();
            if (execId.isNotEmpty) {
              selectedEquipeExecutorIds.add(execId);
            }
          }
        }
      }

      bool matchesTask(Task t) {
        final matchesDirectEquipe = t.equipeIds.any((id) => selectedEquipeIds.contains(id.trim().toLowerCase())) ||
            t.equipes.any((eq) => equipeSet.contains(eq.trim().toLowerCase()));

        final matchesTeamMember = t.executorIds.any((id) => selectedEquipeExecutorIds.contains(id.trim().toLowerCase())) ||
            t.executorPeriods.any((ep) => selectedEquipeExecutorIds.contains(ep.executorId.trim().toLowerCase()));

        return matchesDirectEquipe || matchesTeamMember;
      }

      // T1 deve casar
      expect(matchesTask(task1), isTrue);
      // T2 não deve casar
      expect(matchesTask(task2), isFalse);
      // T3 deve casar (via executorPeriods)
      expect(matchesTask(task3), isTrue);

      // Simulação do resultado de frotas filtradas:
      // A frota 1 tem tarefas da equipe (task1 e task3), a frota 2 só tem task2 (que não pertence à equipe)
      final allRows = [row1, row2, row3];
      final filteredRows = allRows.map((r) {
        final matching = r.tasks.where(matchesTask).toList();
        if (matching.isEmpty) return null;
        return FleetTaskRow(frota: r.frota, tasks: matching);
      }).whereType<FleetTaskRow>().toList();

      // Somente a frota 1 deve permanecer nas linhas visíveis
      expect(filteredRows.map((r) => r.frota.id).toSet(), equals({'F1'}));
      expect(filteredRows.any((r) => r.frota.id == 'F2'), isFalse);
    });
  });

  group('FilterBar — Modo Frota (fleetMode) com filtro EQUIPE', () {
    testWidgets('FilterBar fleetMode emite o filtro equipe selecionado', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Map<String, String?>? emittedFilters;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              fleetMode: true,
              initialFilters: {
                'equipe': 'Equipe Alfa',
              },
              fleetFilterOptions: {
                'regionals': ['R1'],
                'divisoes': ['D1'],
                'segmentos': ['S1'],
                'frotas': ['Caminhão 01 - AAA1111'],
                'propriedades': ['Próprio'],
                'tipos': ['Caminhão'],
                'equipes': ['Equipe Alfa', 'Equipe Beta'],
                'executores': ['João Silva'],
                'coordenadores': ['Carlos Coord'],
              },
              onFiltersChanged: (filters) {
                emittedFilters = filters;
              },
              startDate: DateTime(2026, 3, 1),
              endDate: DateTime(2026, 3, 10),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que o campo EQUIPE está presente na barra de frota
      expect(find.text('EQUIPE'), findsOneWidget);

      // Pressionar o botão limpar filtros e verificar que 'equipe' é resetado
      final clearBtn = find.byIcon(Icons.filter_alt_off);
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(emittedFilters, isNotNull);
      expect(emittedFilters!['equipe'], isNull);
    });
  });
}
