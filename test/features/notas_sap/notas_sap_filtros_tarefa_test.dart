import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/equipe.dart';
import 'package:task2026/models/equipe_executor.dart';

void main() {
  group('Filtros de Executores e Equipes das Tarefas Vinculadas na Tela de Notas SAP', () {
    final nota1 = NotaSAP(
      id: 'nota-1',
      nota: '1001',
      descricao: 'Manutencao LT',
    );
    final nota2 = NotaSAP(
      id: 'nota-2',
      nota: '1002',
      descricao: 'Revisao Disjuntor SE',
    );
    final nota3 = NotaSAP(
      id: 'nota-3',
      nota: '1003',
      descricao: 'Troca de isoladores',
    );
    final notaSemVinculo = NotaSAP(
      id: 'nota-4',
      nota: '1004',
      descricao: 'Nota sem programacao',
    );

    final todasEquipes = [
      Equipe(
        id: 'eq-1',
        nome: 'EQUIPE LINHA 1',
        tipo: 'FIXA',
        executores: [
          EquipeExecutor(executorId: 'ex-joao', executorNome: 'JOAO SILVA', papel: 'EXECUTOR'),
          EquipeExecutor(executorId: 'ex-carlos', executorNome: 'CARLOS ALBERTO', papel: 'ENCARREGADO'),
        ],
      ),
      Equipe(
        id: 'eq-2',
        nome: 'EQUIPE SUBESTACAO',
        tipo: 'FIXA',
        executores: [
          EquipeExecutor(executorId: 'ex-marcos', executorNome: 'MARCOS SOUZA', papel: 'EXECUTOR'),
        ],
      ),
    ];

    final notasProgramadasInfo = <String, List<Map<String, dynamic>>>{
      'nota-1': [
        {
          'task_id': 'task-1',
          'tarefa': {
            'id': 'task-1',
            'tarefa': 'Tarefa LT 1',
            'executor': 'CARLOS ALBERTO',
            'lista_executores': ['CARLOS ALBERTO'],
            'lista_equipes': ['EQUIPE LINHA 1'],
            'lista_equipes_executores': ['JOAO SILVA', 'CARLOS ALBERTO'],
          },
        },
      ],
      'nota-2': [
        {
          'task_id': 'task-2',
          'tarefa': {
            'id': 'task-2',
            'tarefa': 'Tarefa SE 2',
            'executor': 'MARCOS SOUZA',
            'lista_executores': ['MARCOS SOUZA'],
            'lista_equipes': ['EQUIPE SUBESTACAO'],
            'lista_equipes_executores': ['MARCOS SOUZA'],
          },
        },
      ],
      'nota-3': [
        {
          'task_id': 'task-3',
          'tarefa': {
            'id': 'task-3',
            'tarefa': 'Tarefa Isoladores',
            // Tarefa sem equipe cadastrada no campo equipe, mas executada por JOAO SILVA que é membro da EQUIPE LINHA 1
            'executor': 'JOAO SILVA',
            'lista_executores': ['JOAO SILVA'],
            'lista_equipes': <String>[],
            'lista_equipes_executores': <String>[],
          },
        },
      ],
    };

    List<NotaSAP> aplicarFiltros({
      required List<NotaSAP> lista,
      Set<String> filtroEquipes = const {},
      Set<String> filtroExecutores = const {},
    }) {
      if (filtroEquipes.isEmpty && filtroExecutores.isEmpty) {
        return lista;
      }

      final selectedEquipeNomes = filtroEquipes.map((e) => e.trim().toLowerCase()).toSet();
      final selectedEquipeExecutorNomes = <String>{};

      if (selectedEquipeNomes.isNotEmpty) {
        for (final eq in todasEquipes) {
          final eqNome = eq.nome.trim().toLowerCase();
          final eqId = eq.id.trim().toLowerCase();
          if (selectedEquipeNomes.any((sn) =>
              eqNome == sn || eqId == sn || eqNome.contains(sn) || sn.contains(eqNome))) {
            for (final ee in eq.executores) {
              final execNome = ee.executorNome.trim().toLowerCase();
              if (execNome.isNotEmpty) selectedEquipeExecutorNomes.add(execNome);
            }
          }
        }
      }

      final selectedExecs = filtroExecutores.map((e) => e.trim().toLowerCase()).toSet();

      return lista.where((nota) {
        final vinculos = notasProgramadasInfo[nota.id];
        if (vinculos == null || vinculos.isEmpty) return false;

        // Filtro de Equipes (com membros executores da equipe)
        if (filtroEquipes.isNotEmpty) {
          final matchEquipe = vinculos.any((v) {
            final tarefa = v['tarefa'] as Map<String, dynamic>?;
            if (tarefa == null) return false;

            final listaEquipes = (tarefa['lista_equipes'] as List?)
                    ?.map((e) => e.toString().toLowerCase())
                    .toList() ??
                [];
            if (listaEquipes.any((eq) => selectedEquipeNomes.any(
                (sn) => eq == sn || eq.contains(sn) || sn.contains(eq)))) {
              return true;
            }

            final eqTexto = (tarefa['equipe']?.toString() ?? '').toLowerCase();
            if (eqTexto.isNotEmpty &&
                selectedEquipeNomes.any((sn) => eqTexto.contains(sn) || sn.contains(eqTexto))) {
              return true;
            }

            if (selectedEquipeExecutorNomes.isNotEmpty) {
              final rawExec = (tarefa['executor']?.toString() ?? '').toLowerCase();
              if (selectedEquipeExecutorNomes.any((en) => rawExec.contains(en))) return true;

              final listaExecs = (tarefa['lista_executores'] as List?)
                      ?.map((e) => e.toString().toLowerCase())
                      .toList() ??
                  [];
              if (listaExecs.any((ex) => selectedEquipeExecutorNomes
                  .any((en) => ex.contains(en) || en.contains(ex)))) {
                return true;
              }

              final listaEqExecs = (tarefa['lista_equipes_executores'] as List?)
                      ?.map((e) => e.toString().toLowerCase())
                      .toList() ??
                  [];
              if (listaEqExecs.any((ee) => selectedEquipeExecutorNomes
                  .any((en) => ee.contains(en) || en.contains(ee)))) {
                return true;
              }
            }

            return false;
          });

          if (!matchEquipe) return false;
        }

        // Filtro de Executores da Tarefa
        if (filtroExecutores.isNotEmpty) {
          final matchExecutor = vinculos.any((v) {
            final tarefa = v['tarefa'] as Map<String, dynamic>?;
            if (tarefa == null) return false;

            final rawExec = (tarefa['executor']?.toString() ?? '').toLowerCase();
            if (selectedExecs.any((se) => rawExec.contains(se))) return true;

            final listaExecs = (tarefa['lista_executores'] as List?)
                    ?.map((e) => e.toString().toLowerCase())
                    .toList() ??
                [];
            if (listaExecs.any((ex) => selectedExecs.any((se) => ex.contains(se) || se.contains(ex)))) {
              return true;
            }

            final listaEqExecs = (tarefa['lista_equipes_executores'] as List?)
                    ?.map((e) => e.toString().toLowerCase())
                    .toList() ??
                [];
            if (listaEqExecs.any((ee) => selectedExecs.any((se) => ee.contains(se) || se.contains(ee)))) {
              return true;
            }

            return false;
          });

          if (!matchExecutor) return false;
        }

        return true;
      }).toList();
    }

    test('1. Filtro de equipe seleciona tarefas diretamente vinculadas à equipe e tarefas executadas por membros da equipe', () {
      final todas = [nota1, nota2, nota3, notaSemVinculo];
      final filtradas = aplicarFiltros(lista: todas, filtroEquipes: {'EQUIPE LINHA 1'});

      expect(filtradas.map((n) => n.id).toList(), containsAll(['nota-1', 'nota-3']));
      expect(filtradas.map((n) => n.id).toList(), isNot(contains('nota-2')));
      expect(filtradas.map((n) => n.id).toList(), isNot(contains('nota-4')));
    });

    test('2. Filtro de executor seleciona notas cujas tarefas vinculadas pertencem àquele executor', () {
      final todas = [nota1, nota2, nota3, notaSemVinculo];
      final filtradas = aplicarFiltros(lista: todas, filtroExecutores: {'MARCOS SOUZA'});

      expect(filtradas.length, equals(1));
      expect(filtradas.first.id, equals('nota-2'));
    });

    test('3. Combinação de filtros de equipe e executor funciona como interseção estrita', () {
      final todas = [nota1, nota2, nota3, notaSemVinculo];
      final filtradas = aplicarFiltros(
        lista: todas,
        filtroEquipes: {'EQUIPE LINHA 1'},
        filtroExecutores: {'CARLOS ALBERTO'},
      );

      expect(filtradas.length, equals(1));
      expect(filtradas.first.id, equals('nota-1'));
    });

    test('4. Sem filtros ativos, todas as notas são preservadas', () {
      final todas = [nota1, nota2, nota3, notaSemVinculo];
      final filtradas = aplicarFiltros(lista: todas);

      expect(filtradas.length, equals(4));
    });
  });
}
