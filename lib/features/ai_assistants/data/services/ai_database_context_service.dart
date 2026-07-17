import 'dart:developer' as developer;
import '../../../../services/task_service.dart';
import '../../../../services/nota_sap_service.dart';
import '../../../../services/ordem_service.dart';
import '../../../../services/at_service.dart';

class AiDatabaseContextResult {
  final String markdownContext;
  final int activeTasksCount;

  AiDatabaseContextResult({
    required this.markdownContext,
    required this.activeTasksCount,
  });
}

class AiDatabaseContextService {
  final _taskService = TaskService();
  final _notaSapService = NotaSAPService();
  final _ordemService = OrdemService();
  final _atService = ATService(); // Em at_service.dart, a classe é ATService

  /// Carrega as tarefas operacionais, notas SAP, ordens e ATs do usuário e formata como contexto Markdown para a IA
  Future<AiDatabaseContextResult> getDatabaseContext() async {
    final buffer = StringBuffer();
    int activeCount = 0;

    // 1. Carregar e formatar TAREFAS ATIVAS (com perfil aplicado)
    try {
      final allTasks = await _taskService.getAllTasks(aplicarPerfil: true, ignoreCache: false);
      final activeTasks = allTasks.where((t) {
        final st = t.status.toUpperCase();
        return st != 'CONC' && st != 'CANC';
      }).toList();

      activeCount = activeTasks.length;
      activeTasks.sort((a, b) => a.dataInicio.compareTo(b.dataInicio));
      final limitedTasks = activeTasks.take(15).toList();

      buffer.writeln('## TAREFAS ATIVAS NO BANCO DE DADOS (FILTRADO POR PERFIL)');
      buffer.writeln('O usuário possui $activeCount tarefas pendentes em seu perfil. Abaixo estão listadas as 15 mais próximas:');
      buffer.writeln();
      buffer.writeln('| ID | Tarefa | Status | Início | Fim | Prioridade | Responsáveis/Equipe | Locais | Observações |');
      buffer.writeln('|----|--------|--------|--------|-----|------------|---------------------|--------|-------------|');

      if (limitedTasks.isEmpty) {
        buffer.writeln('| - | Nenhuma tarefa ativa encontrada | - | - | - | - | - | - | - |');
      } else {
        for (final t in limitedTasks) {
          final id = t.id;
          final tarefa = t.tarefa.replaceAll('|', '/');
          final status = t.statusNome.isNotEmpty ? t.statusNome : t.status;
          final inicio = _formatDate(t.dataInicio);
          final fim = _formatDate(t.dataFim);
          final prioridade = t.prioridade ?? 'Média';

          final executores = t.executores.isNotEmpty ? t.executores.join(', ') : 'Não atribuído';
          final equipes = t.equipes.isNotEmpty ? t.equipes.join(', ') : '';
          final responsavel = equipes.isNotEmpty ? '$executores ($equipes)' : executores;

          final locais = t.locais.isNotEmpty ? t.locais.join(', ') : 'Não informado';
          final obs = t.observacoes != null ? t.observacoes!.replaceAll('\n', ' ').replaceAll('|', '/') : '';
          final obsShort = obs.length > 50 ? '${obs.substring(0, 47)}...' : obs;

          buffer.writeln('| $id | $tarefa | $status | $inicio | $fim | $prioridade | $responsavel | $locais | $obsShort |');
        }
      }
      buffer.writeln();
    } catch (e) {
      developer.log('Erro ao carregar contexto de tarefas para IA: $e');
      buffer.writeln('## TAREFAS ATIVAS\nErro ao carregar tarefas do perfil.\n');
    }

    // 2. Carregar e formatar NOTAS SAP ABERTAS (com perfil aplicado)
    try {
      final allNotas = await _notaSapService.getAllNotas(limit: 500, filtroTipoNota: 'abertas');
      final activeNotas = allNotas.where((n) {
        final su = (n.statusUsuario ?? '').toUpperCase();
        final ss = (n.statusSistema ?? '').toUpperCase();
        return !su.contains('CONC') && !su.contains('CANC') && !ss.contains('MREL');
      }).toList();

      final totalNotas = activeNotas.length;
      final limitedNotas = activeNotas.take(15).toList();

      buffer.writeln('## NOTAS SAP ABERTAS (DEMANDAS SEM PLANEJAMENTO OU PENDENTES)');
      buffer.writeln('O usuário possui $totalNotas notas SAP pendentes de ação no total para seu perfil. Abaixo estão listadas até 15 notas SAP:');
      buffer.writeln();
      buffer.writeln('| Número | Tipo | Descrição | Local Instalação | Prioridade | Status Usuário | Status Sistema | Vencimento |');
      buffer.writeln('|--------|------|-----------|------------------|------------|----------------|----------------|------------|');

      if (limitedNotas.isEmpty) {
        buffer.writeln('| - | Nenhuma nota SAP ativa encontrada | - | - | - | - | - | - |');
      } else {
        for (final n in limitedNotas) {
          final numNota = n.nota;
          final tipo = n.tipo ?? 'N/A';
          final desc = (n.descricao ?? '').replaceAll('|', '/');
          final descShort = desc.length > 40 ? '${desc.substring(0, 37)}...' : desc;
          final localInst = n.localInstalacao ?? 'Não informado';
          final prioridade = n.textPrioridade ?? 'Média';
          final stUsu = n.statusUsuario ?? '';
          final stSis = n.statusSistema ?? '';
          final venc = n.dataVencimento != null ? _formatDate(n.dataVencimento!) : 'N/A';

          buffer.writeln('| $numNota | $tipo | $descShort | $localInst | $prioridade | $stUsu | $stSis | $venc |');
        }
      }
      buffer.writeln();
    } catch (e) {
      developer.log('Erro ao carregar contexto de Notas SAP para IA: $e');
      buffer.writeln('## NOTAS SAP\nErro ao carregar notas SAP do perfil.\n');
    }

    // 3. Carregar e formatar ORDENS DE MANUTENÇÃO ABERTAS (com perfil aplicado)
    try {
      final allOrdens = await _ordemService.getAllOrdens(limit: 500, apenasAbertas: true);
      final activeOrdens = allOrdens.where((o) {
        final su = (o.statusUsuario ?? '').toUpperCase();
        final ss = (o.statusSistema ?? '').toUpperCase();
        return !su.contains('CONC') && !su.contains('CANC') && !ss.contains('ENCE');
      }).toList();

      final totalOrdens = activeOrdens.length;
      final limitedOrdens = activeOrdens.take(15).toList();

      buffer.writeln('## ORDENS DE MANUTENÇÃO ABERTAS');
      buffer.writeln('O usuário possui $totalOrdens ordens de manutenção em aberto no total para seu perfil. Abaixo estão listadas até 15 ordens:');
      buffer.writeln();
      buffer.writeln('| Número | Tipo | Texto Breve | Objeto | Local Instalação | Status Usuário | Início Base | Fim Base |');
      buffer.writeln('|--------|------|-------------|--------|------------------|----------------|-------------|----------|');

      if (limitedOrdens.isEmpty) {
        buffer.writeln('| - | Nenhuma ordem ativa encontrada | - | - | - | - | - | - |');
      } else {
        for (final o in limitedOrdens) {
          final numOrdem = o.ordem;
          final tipo = o.tipo ?? 'N/A';
          final txt = (o.textoBreve ?? '').replaceAll('|', '/');
          final txtShort = txt.length > 40 ? '${txt.substring(0, 37)}...' : txt;
          final obj = o.denominacaoObjeto ?? 'N/A';
          final localInst = o.localInstalacao ?? 'Não informado';
          final stUsu = o.statusUsuario ?? '';
          final inicio = o.inicioBase != null ? _formatDate(o.inicioBase!) : 'N/A';
          final fim = o.fimBase != null ? _formatDate(o.fimBase!) : 'N/A';

          buffer.writeln('| $numOrdem | $tipo | $txtShort | $obj | $localInst | $stUsu | $inicio | $fim |');
        }
      }
      buffer.writeln();
    } catch (e) {
      developer.log('Erro ao carregar contexto de Ordens para IA: $e');
      buffer.writeln('## ORDENS DE MANUTENÇÃO\nErro ao carregar ordens de manutenção do perfil.\n');
    }

    // 4. Carregar e formatar AUTORIZAÇÕES DE TRABALHO (ATs) ABERTAS (com perfil aplicado)
    try {
      final allATs = await _atService.getAllATs(limit: 500);
      final activeATs = allATs.where((at) {
        final su = (at.statusUsuario ?? '').toUpperCase();
        final ss = (at.statusSistema ?? '').toUpperCase();
        return !su.contains('CONC') && !su.contains('CANC') && !ss.contains('ENCE');
      }).toList();

      final totalATs = activeATs.length;
      final limitedATs = activeATs.take(15).toList();

      buffer.writeln('## AUTORIZAÇÕES DE TRABALHO (ATs) ABERTAS');
      buffer.writeln('O usuário possui $totalATs ATs em aberto no total para seu perfil. Abaixo estão listadas até 15 ATs:');
      buffer.writeln();
      buffer.writeln('| Número | Texto Breve | Local Instalação | Centro Trab | Status Usuário | Início | Fim | Válido |');
      buffer.writeln('|--------|-------------|------------------|-------------|----------------|--------|-----|--------|');

      if (limitedATs.isEmpty) {
        buffer.writeln('| - | Nenhuma AT ativa encontrada | - | - | - | - | - | - |');
      } else {
        for (final at in limitedATs) {
          final numAt = at.autorzTrab;
          final txt = (at.textoBreve ?? '').replaceAll('|', '/');
          final txtShort = txt.length > 40 ? '${txt.substring(0, 37)}...' : txt;
          final localInst = at.localInstalacao ?? 'Não informado';
          final ct = at.cntrTrab ?? 'N/A';
          final stUsu = at.statusUsuario ?? '';
          final inicio = at.dataInicio != null ? _formatDate(at.dataInicio!) : 'N/A';
          final fim = at.dataFim != null ? _formatDate(at.dataFim!) : 'N/A';
          final valido = at.valido ?? 'N/A';

          buffer.writeln('| $numAt | $txtShort | $localInst | $ct | $stUsu | $inicio | $fim | $valido |');
        }
      }
      buffer.writeln();
    } catch (e) {
      developer.log('Erro ao carregar contexto de ATs para IA: $e');
      buffer.writeln('## AUTORIZAÇÕES DE TRABALHO (ATs)\nErro ao carregar ATs do perfil.\n');
    }

    buffer.writeln('Instrução para a IA: Utilize este painel consolidado de demandas e tarefas operacionais reais do banco de dados (que reflete exatamente o perfil e centros de trabalho do usuário logado) para fornecer análises de prioridade, apontamento de gargalos, relatórios e planos de ação precisos.');

    return AiDatabaseContextResult(
      markdownContext: buffer.toString(),
      activeTasksCount: activeCount,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
