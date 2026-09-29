import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDFService.generateTasksPDF Tests', () {
    late PDFService pdfService;

    setUp(() {
      pdfService = PDFService();
    });

    test('generateTasksPDF handles Unicode characters without throwing', () async {
      final sampleTasks = [
        Task(
          id: '1',
          tarefa: 'Manutenção • Transformador TR-01 — SE Barreiro – Linha 1',
          dataInicio: DateTime(2026, 9, 17, 8, 0),
          dataFim: DateTime(2026, 9, 17, 17, 0),
          status: 'PROGRAMADA',
          regional: 'METROPOLITANA',
          divisao: 'DVE-01',
          locais: ['SE Barreiro • Subestação'],
          tipo: 'SUBESTAÇÃO',
          ordem: 'ORD-12345',
          executor: 'João Silva — Líder',
          executores: ['João Silva — Líder', 'Maria Santos'],
          coordenador: 'Carlos Coordenador',
        ),
      ];

      final pdfBytes = await pdfService.generateTasksPDF(
        sampleTasks,
        title: 'PROGRAMAÇÃO • DIÁRIA — TESTE',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
    });

    test('generateTasksPDF handles 100+ tasks across many pages without TooManyPagesException', () async {
      final tasks = List.generate(
        120,
        (i) => Task(
          id: 'task-$i',
          tarefa: 'Atividade de teste número $i com descrição estendida para verificar a quebra correta de linha e páginas na tabela do PDF',
          dataInicio: DateTime(2026, 9, 1, 8, 0).add(Duration(days: i % 30)),
          dataFim: DateTime(2026, 9, 1, 17, 0).add(Duration(days: i % 30)),
          status: i % 2 == 0 ? 'PROGRAMADA' : 'CONCLUÍDA',
          regional: 'REGIONAL ${i % 5}',
          divisao: 'DIV-${i % 10}',
          locais: ['Local A', 'Local B'],
          tipo: 'LINHA DE TRANSMISSÃO',
          ordem: 'ORD-${1000 + i}',
          executor: 'Executor $i',
          executores: ['Executor $i', 'Ajudante $i'],
          coordenador: 'Coordenador Geral',
        ),
      );

      final pdfBytes = await pdfService.generateTasksPDF(
        tasks,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
