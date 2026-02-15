import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hora_sap.dart';
import '../models/executor.dart';
import '../models/horas_empregado_mes.dart';
import '../models/ordem_programada_empregado_mes.dart';
import '../models/horas_apontadas_ordem_mes.dart';
import 'auth_service_simples.dart';
import 'centro_trabalho_service.dart';
import 'executor_service.dart';

class HoraSAPService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthServiceSimples _authService = AuthServiceSimples();
  final CentroTrabalhoService _centroTrabalhoService = CentroTrabalhoService();
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  // Cache para empresas próprias (evitar consultas repetidas)
  final Map<String, bool> _empresasPropriasCache = {};
  
  // Verificar se uma empresa é própria
  Future<bool> _isEmpresaPropria(String? empresaId) async {
    if (empresaId == null || empresaId.isEmpty) {
      // Sem empresa = considerado próprio
      return true;
    }
    
    // Verificar cache
    if (_empresasPropriasCache.containsKey(empresaId)) {
      return _empresasPropriasCache[empresaId]!;
    }
    
    try {
      final response = await _supabase
          .from('empresas')
          .select('tipo')
          .eq('id', empresaId)
          .single();
      
      final tipo = response['tipo'] as String?;
      final isPropria = tipo == 'PROPRIA';
      
      // Armazenar no cache
      _empresasPropriasCache[empresaId] = isPropria;
      
      return isPropria;
    } catch (e) {
      print('⚠️ Erro ao verificar tipo da empresa $empresaId: $e');
      // Em caso de erro, assumir que não é própria para ser mais restritivo
      _empresasPropriasCache[empresaId] = false;
      return false;
    }
  }

  // Calcula dias úteis entre duas datas, desconsiderando apenas sábado e domingo
  int _calcularDiasUteisEntreDatas(DateTime inicio, DateTime fim) {
    int diasUteis = 0;
    DateTime data = DateTime(inicio.year, inicio.month, inicio.day);
    final fimNormalizado = DateTime(fim.year, fim.month, fim.day);

    while (data.isBefore(fimNormalizado) || data.isAtSameMomentAs(fimNormalizado)) {
      if (data.weekday != DateTime.saturday && data.weekday != DateTime.sunday) {
        diasUteis++;
      }
      data = data.add(const Duration(days: 1));
    }

    return diasUteis;
  }

  // Calcular dias úteis de um mês (desconsiderando apenas sábado e domingo)
  int _calcularDiasUteis(int ano, int mes) {
    final primeiroDia = DateTime(ano, mes, 1);
    final ultimoDia = DateTime(ano, mes + 1, 0);
    return _calcularDiasUteisEntreDatas(primeiroDia, ultimoDia);
  }

  // Obter centros de trabalho do usuário
  Future<List<Map<String, String>>> _obterCentrosTrabalhoComGPMUsuario() async {
    try {
      final usuario = _authService.currentUser;
      
      // Se não há usuário ou é root, retornar lista vazia (sem filtro)
      if (usuario == null || usuario.isRoot) {
        return [];
      }

      // Se não tem perfil configurado, retornar lista vazia (sem filtro)
      if (!usuario.temPerfilConfigurado()) {
        return [];
      }

      // Buscar todos os centros de trabalho
      final todosCentros = await _centroTrabalhoService.getAllCentrosTrabalho();
      
      // Filtrar centros de trabalho baseado no perfil do usuário
      final centrosPermitidos = todosCentros.where((centro) {
        // Verificar se o centro pertence a uma regional permitida
        final temRegionalPermitida = usuario.regionalIds.isEmpty || 
            usuario.regionalIds.contains(centro.regionalId);
        
        // Verificar se o centro pertence a uma divisão permitida
        final temDivisaoPermitida = usuario.divisaoIds.isEmpty || 
            usuario.divisaoIds.contains(centro.divisaoId);
        
        // Verificar se o centro pertence a um segmento permitido
        final temSegmentoPermitido = usuario.segmentoIds.isEmpty || 
            usuario.segmentoIds.contains(centro.segmentoId);
        
        return temRegionalPermitida && temDivisaoPermitida && temSegmentoPermitido;
      }).where((centro) => centro.gpm != null).toList(); // Apenas centros com GPM

      // Retornar lista de pares (centro, gpm)
      final centrosComGPM = centrosPermitidos.map((centro) {
        return {
          'centro': centro.centroTrabalho.trim(),
          'gpm': centro.gpm!.toString(),
        };
      }).toList();

      return centrosComGPM;
    } catch (e) {
      print('❌ Erro ao obter centros de trabalho do usuário: $e');
      return [];
    }
  }

  Future<List<String>> _obterCentrosTrabalhoUsuario() async {
    final centrosComGPM = await _obterCentrosTrabalhoComGPMUsuario();
    return centrosComGPM.map((ct) => ct['centro'] ?? '').where((c) => c.isNotEmpty).toList();
  }

  /// Matrículas dos executores que têm o mesmo perfil do usuário logado (REGIONAL & DIVISÃO & SEGMENTO).
  /// Retorna lista vazia para root ou quando não há perfil. Usado para filtrar horas_sap por numero_pessoa.
  Future<List<String>> _obterMatriculasPerfilUsuario() async {
    final usuario = _authService.currentUser;
    if (usuario == null || usuario.isRoot || !usuario.temPerfilConfigurado()) {
      return [];
    }
    final executorService = ExecutorService();
    Set<Executor> executoresUnicos = {};
    if (usuario.segmentoIds.isNotEmpty) {
      for (final segmentoId in usuario.segmentoIds) {
        final list = await executorService.getExecutoresPorSegmento(segmentoId);
        executoresUnicos.addAll(list);
      }
    } else if (usuario.divisaoIds.isNotEmpty) {
      for (final divisaoId in usuario.divisaoIds) {
        final list = await executorService.getExecutoresPorDivisao(divisaoId);
        executoresUnicos.addAll(list);
      }
    } else if (usuario.regionalIds.isNotEmpty) {
      final divisoesRows = await _supabase.from('divisoes').select('id').inFilter('regional_id', usuario.regionalIds);
      final divisaoIdsDaRegional = (divisoesRows as List).map((d) => d['id'] as String).toList();
      for (final divisaoId in divisaoIdsDaRegional) {
        final list = await executorService.getExecutoresPorDivisao(divisaoId);
        executoresUnicos.addAll(list);
      }
    } else {
      executoresUnicos.addAll(await executorService.getExecutoresAtivos());
    }
    var listaFiltrada = executoresUnicos.toList();
    if (usuario.regionalIds.isNotEmpty) {
      final divisoesDaRegional = await _supabase.from('divisoes').select('id').inFilter('regional_id', usuario.regionalIds);
      final idsDivisaoRegional = (divisoesDaRegional as List).map((d) => d['id'] as String).toSet();
      listaFiltrada = listaFiltrada.where((e) => e.divisaoId != null && idsDivisaoRegional.contains(e.divisaoId)).toList();
    }
    if (usuario.divisaoIds.isNotEmpty) {
      listaFiltrada = listaFiltrada.where((e) => e.divisaoId != null && usuario.divisaoIds.contains(e.divisaoId)).toList();
    }
    if (usuario.segmentoIds.isNotEmpty) {
      listaFiltrada = listaFiltrada.where((e) => e.segmentoIds.any((id) => usuario.segmentoIds.contains(id))).toList();
    }
    final matriculas = <String>[];
    for (var e in listaFiltrada) {
      if (e.ativo && e.matricula != null && e.matricula!.trim().isNotEmpty) {
        final isProprio = await _isEmpresaPropria(e.empresaId);
        if (isProprio) matriculas.add(e.matricula!.trim());
      }
    }
    return matriculas;
  }

  // Buscar todas as horas (com limites e janela padrão para evitar timeouts)
  Future<List<HoraSAP>> getAllHoras({
    String? filtroTipoOrdem,
    List<String>? filtroOrdens,
    List<String>? filtroOperacoes,
    List<String>? filtroTipoAtividade,
    List<String>? filtroNumeroPessoa,
    List<String>? filtroNomeEmpregado,
    List<String>? filtroStatusSistema,
    List<String>? filtroCentroTrabalho,
    DateTime? dataLancamentoInicio,
    DateTime? dataLancamentoFim,
    int? limit,
    int? offset,
    String? searchQuery, // Novo parâmetro para busca no backend
  }) async {
    try {
      // Janela padrão: últimos 3 meses (apenas se não houver busca)
      final agora = DateTime.now();
      final padraoInicio = DateTime(agora.year, agora.month - 3, 1);
      final padraoFim = agora;

      // Se houver busca, ignorar janela de tempo padrão (buscar em todo histórico ou definir janela maior se necessário)
      // Por segurança/performance, ainda vamos manter uma janela, mas talvez maior, ou avisar o usuário.
      // Neste MVP, manteremos a janela padrão mas permitiremos que o caller passe null para dataInicio se quiser buscar em tudo
      // Mas a UI atual passa datas. Se a UI passar datas, respeitamos.

      final dataIni = dataLancamentoInicio ?? padraoInicio;
      final dataFim = dataLancamentoFim ?? padraoFim;

      // Limites padrão para evitar consultas grandes
      final lim = limit ?? 50;
      final off = offset ?? 0;

      dynamic query = _supabase.from('horas_sap').select();

      // Aplicar filtros por perfil: só horas dos empregados/executores com mesmo REGIONAL & DIVISÃO & SEGMENTO do usuário
      final usuario = _authService.currentUser;
      if (usuario != null && usuario.isRoot) {
        // Root: sem filtro de perfil
      } else if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        final matriculasPerfil = await _obterMatriculasPerfilUsuario();
        if (matriculasPerfil.isEmpty) {
          return [];
        }
        query = query.inFilter('numero_pessoa', matriculasPerfil);
      } else {
        // Sem perfil: manter filtro por centro de trabalho (comportamento legado)
        final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
        if (centrosTrabalhoUsuario.isEmpty) {
          return [];
        }
        final centrosCompletos = centrosTrabalhoUsuario.map((c) => c.trim()).toList();
        if (centrosCompletos.length == 1) {
          query = query.ilike('centro_trabalho_real', '%${centrosCompletos[0]}%');
        } else {
          final orConditions = centrosCompletos.map((centro) => 'centro_trabalho_real.ilike.%$centro%').join(',');
          query = query.or(orConditions);
        }
      }

      // Filtros multi-seleção
      if (filtroTipoOrdem != null && filtroTipoOrdem.isNotEmpty) {
        query = query.eq('tipo_ordem', filtroTipoOrdem);
      }

      if (filtroOrdens != null && filtroOrdens.isNotEmpty) {
        if (filtroOrdens.length == 1) {
          query = query.eq('ordem', filtroOrdens[0]);
        } else {
          final orConditions = filtroOrdens.map((v) => 'ordem.eq.$v').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroOperacoes != null && filtroOperacoes.isNotEmpty) {
        if (filtroOperacoes.length == 1) {
          query = query.eq('operacao', filtroOperacoes[0]);
        } else {
          final orConditions = filtroOperacoes.map((v) => 'operacao.eq.$v').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroTipoAtividade != null && filtroTipoAtividade.isNotEmpty) {
        if (filtroTipoAtividade.length == 1) {
          query = query.eq('tipo_atividade_real', filtroTipoAtividade[0]);
        } else {
          final orConditions = filtroTipoAtividade.map((v) => 'tipo_atividade_real.eq.$v').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroNumeroPessoa != null && filtroNumeroPessoa.isNotEmpty) {
        if (filtroNumeroPessoa.length == 1) {
          query = query.eq('numero_pessoa', filtroNumeroPessoa[0]);
        } else {
          final orConditions = filtroNumeroPessoa.map((v) => 'numero_pessoa.eq.$v').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroNomeEmpregado != null && filtroNomeEmpregado.isNotEmpty) {
        if (filtroNomeEmpregado.length == 1) {
          query = query.ilike('nome_empregado', '%${filtroNomeEmpregado[0]}%');
        } else {
          final orConditions = filtroNomeEmpregado.map((nome) => 'nome_empregado.ilike.%$nome%').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroStatusSistema != null && filtroStatusSistema.isNotEmpty) {
        if (filtroStatusSistema.length == 1) {
          query = query.ilike('status_sistema', '%${filtroStatusSistema[0]}%');
        } else {
          final orConditions = filtroStatusSistema.map((status) => 'status_sistema.ilike.%$status%').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroCentroTrabalho != null && filtroCentroTrabalho.isNotEmpty) {
        if (filtroCentroTrabalho.length == 1) {
          query = query.ilike('centro_trabalho_real', '%${filtroCentroTrabalho[0]}%');
        } else {
          final orConditions = filtroCentroTrabalho.map((centro) => 'centro_trabalho_real.ilike.%$centro%').join(',');
          query = query.or(orConditions);
        }
      }

      // Filtro de Busca Textual (Search Query)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        // Busca em múltiplos campos usando OR
        final termo = '%$searchQuery%';
        query = query.or('ordem.ilike.$termo,nome_empregado.ilike.$termo,numero_pessoa.ilike.$termo,centro_trabalho_real.ilike.$termo,tipo_atividade_real.ilike.$termo,status_sistema.ilike.$termo');
      }

      // Filtro por data de lançamento (sempre aplicado)
      query = query
          .gte('data_lancamento', dataIni.toIso8601String().split('T')[0])
          .lte('data_lancamento', dataFim.toIso8601String().split('T')[0]);

      // Ordenação por data de lançamento (mais recente primeiro)
      query = query.order('data_lancamento', ascending: false);

      // Paginação
      query = query.limit(lim);
      query = query.range(off, off + lim - 1);

      final response = await query;
      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) => HoraSAP.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ Erro ao buscar horas: $e');
      return [];
    }
  }

  // Contar horas (mesmos filtros e janela padrão do getAllHoras)
  Future<int> contarHoras({
    String? filtroTipoOrdem,
    List<String>? filtroOrdens,
    List<String>? filtroOperacoes,
    List<String>? filtroTipoAtividade,
    List<String>? filtroNumeroPessoa,
    List<String>? filtroNomeEmpregado,
    List<String>? filtroStatusSistema,
    List<String>? filtroCentroTrabalho,
    DateTime? dataLancamentoInicio,
    DateTime? dataLancamentoFim,
    String? searchQuery, // Novo parâmetro
  }) async {
    try {
      // Janela padrão: últimos 3 meses
      final agora = DateTime.now();
      final padraoInicio = DateTime(agora.year, agora.month - 3, 1);
      final padraoFim = agora;

      final dataIni = dataLancamentoInicio ?? padraoInicio;
      final dataFim = dataLancamentoFim ?? padraoFim;

      // Com os índices criados, buscar apenas IDs é rápido (PostgreSQL usa índices)
      dynamic query = _supabase.from('horas_sap').select('id');

      // Mesmo critério de perfil do getAllHoras: só empregados com REGIONAL & DIVISÃO & SEGMENTO do usuário
      final usuario = _authService.currentUser;
      if (usuario != null && usuario.isRoot) {
        // Root: sem filtro
      } else if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        final matriculasPerfil = await _obterMatriculasPerfilUsuario();
        if (matriculasPerfil.isEmpty) return 0;
        query = query.inFilter('numero_pessoa', matriculasPerfil);
      } else {
        final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
        if (centrosTrabalhoUsuario.isEmpty) return 0;
        final centrosCompletos = centrosTrabalhoUsuario.map((c) => c.trim()).toList();
        if (centrosCompletos.length == 1) {
          query = query.ilike('centro_trabalho_real', '%${centrosCompletos[0]}%');
        } else {
          final orConditions = centrosCompletos.map((centro) => 'centro_trabalho_real.ilike.%$centro%').join(',');
          query = query.or(orConditions);
        }
      }

      // Aplicar os mesmos filtros do getAllHoras
      if (filtroTipoOrdem != null && filtroTipoOrdem.isNotEmpty) {
        query = query.eq('tipo_ordem', filtroTipoOrdem);
      }

      if (filtroOrdens != null && filtroOrdens.isNotEmpty) {
        if (filtroOrdens.length == 1) {
          query = query.eq('ordem', filtroOrdens[0]);
        } else {
          final orConditions = filtroOrdens.map((v) => 'ordem.eq.$v').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroOperacoes != null && filtroOperacoes.isNotEmpty) {
        if (filtroOperacoes.length == 1) {
          query = query.eq('operacao', filtroOperacoes[0]);
        } else {
          final orConditions = filtroOperacoes.map((v) => 'operacao.eq.$v').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroTipoAtividade != null && filtroTipoAtividade.isNotEmpty) {
        if (filtroTipoAtividade.length == 1) {
          query = query.eq('tipo_atividade_real', filtroTipoAtividade[0]);
        } else {
          final orConditions = filtroTipoAtividade.map((v) => 'tipo_atividade_real.eq.$v').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroNumeroPessoa != null && filtroNumeroPessoa.isNotEmpty) {
        if (filtroNumeroPessoa.length == 1) {
          query = query.eq('numero_pessoa', filtroNumeroPessoa[0]);
        } else {
          final orConditions = filtroNumeroPessoa.map((v) => 'numero_pessoa.eq.$v').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroNomeEmpregado != null && filtroNomeEmpregado.isNotEmpty) {
        if (filtroNomeEmpregado.length == 1) {
          query = query.ilike('nome_empregado', '%${filtroNomeEmpregado[0]}%');
        } else {
          final orConditions = filtroNomeEmpregado.map((nome) => 'nome_empregado.ilike.%$nome%').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroStatusSistema != null && filtroStatusSistema.isNotEmpty) {
        if (filtroStatusSistema.length == 1) {
          query = query.ilike('status_sistema', '%${filtroStatusSistema[0]}%');
        } else {
          final orConditions = filtroStatusSistema.map((status) => 'status_sistema.ilike.%$status%').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroCentroTrabalho != null && filtroCentroTrabalho.isNotEmpty) {
        if (filtroCentroTrabalho.length == 1) {
          query = query.ilike('centro_trabalho_real', '%${filtroCentroTrabalho[0]}%');
        } else {
          final orConditions = filtroCentroTrabalho.map((centro) => 'centro_trabalho_real.ilike.%$centro%').join(',');
          query = query.or(orConditions);
        }
      }

      // Filtro de Busca Textual (Search Query)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final termo = '%$searchQuery%';
        query = query.or('ordem.ilike.$termo,nome_empregado.ilike.$termo,numero_pessoa.ilike.$termo,centro_trabalho_real.ilike.$termo,tipo_atividade_real.ilike.$termo,status_sistema.ilike.$termo');
      }

      // Filtro por data de lançamento (sempre aplicado)
      query = query
          .gte('data_lancamento', dataIni.toIso8601String().split('T')[0])
          .lte('data_lancamento', dataFim.toIso8601String().split('T')[0]);

      // Executar query - Com índices, buscar IDs é RÁPIDO (PostgreSQL usa índices)
      final response = await query;
      return (response as List).length;
    } catch (e) {
      print('❌ Erro ao contar horas: $e');
      return 0;
    }
  }

  // Buscar valores únicos para filtros
  Future<Map<String, List<String>>> getValoresFiltros({
    String? filtroTipoOrdem,
    List<String>? filtroOrdens,
    List<String>? filtroOperacoes,
    List<String>? filtroTipoAtividade,
    List<String>? filtroNumeroPessoa,
    List<String>? filtroNomeEmpregado,
    List<String>? filtroStatusSistema,
    List<String>? filtroCentroTrabalho,
    DateTime? dataLancamentoInicio,
    DateTime? dataLancamentoFim,
  }) async {
    try {
      final usuario = _authService.currentUser;
      
      // Função auxiliar para aplicar filtros exceto um campo específico
      dynamic aplicarFiltrosExceto(dynamic query, String campoExcluido) {
        if (campoExcluido != 'tipo_ordem' && filtroTipoOrdem != null && filtroTipoOrdem.isNotEmpty) {
          query = query.eq('tipo_ordem', filtroTipoOrdem);
        }
        if (campoExcluido != 'ordem' && filtroOrdens != null && filtroOrdens.isNotEmpty) {
          if (filtroOrdens.length == 1) {
            query = query.eq('ordem', filtroOrdens[0]);
          } else {
            final orConditions = filtroOrdens.map((v) => 'ordem.eq.$v').join(',');
          query = query.or(orConditions);
          }
        }
        if (campoExcluido != 'operacao' && filtroOperacoes != null && filtroOperacoes.isNotEmpty) {
          if (filtroOperacoes.length == 1) {
            query = query.eq('operacao', filtroOperacoes[0]);
          } else {
            final orConditions = filtroOperacoes.map((v) => 'operacao.eq.$v').join(',');
          query = query.or(orConditions);
          }
        }
        if (campoExcluido != 'tipo_atividade_real' && filtroTipoAtividade != null && filtroTipoAtividade.isNotEmpty) {
          if (filtroTipoAtividade.length == 1) {
            query = query.eq('tipo_atividade_real', filtroTipoAtividade[0]);
          } else {
            final orConditions = filtroTipoAtividade.map((v) => 'tipo_atividade_real.eq.$v').join(',');
          query = query.or(orConditions);
          }
        }
        if (campoExcluido != 'numero_pessoa' && filtroNumeroPessoa != null && filtroNumeroPessoa.isNotEmpty) {
          if (filtroNumeroPessoa.length == 1) {
            query = query.eq('numero_pessoa', filtroNumeroPessoa[0]);
          } else {
            final orConditions = filtroNumeroPessoa.map((v) => 'numero_pessoa.eq.$v').join(',');
          query = query.or(orConditions);
          }
        }
        if (campoExcluido != 'nome_empregado' && filtroNomeEmpregado != null && filtroNomeEmpregado.isNotEmpty) {
          if (filtroNomeEmpregado.length == 1) {
            query = query.ilike('nome_empregado', '%${filtroNomeEmpregado[0]}%');
          } else {
            final orConditions = filtroNomeEmpregado.map((nome) => 'nome_empregado.ilike.%$nome%').join(',');
            query = query.or(orConditions);
          }
        }
        if (campoExcluido != 'status_sistema' && filtroStatusSistema != null && filtroStatusSistema.isNotEmpty) {
          if (filtroStatusSistema.length == 1) {
            query = query.ilike('status_sistema', '%${filtroStatusSistema[0]}%');
          } else {
            final orConditions = filtroStatusSistema.map((status) => 'status_sistema.ilike.%$status%').join(',');
            query = query.or(orConditions);
          }
        }
        if (campoExcluido != 'centro_trabalho_real' && filtroCentroTrabalho != null && filtroCentroTrabalho.isNotEmpty) {
          if (filtroCentroTrabalho.length == 1) {
            query = query.ilike('centro_trabalho_real', '%${filtroCentroTrabalho[0]}%');
          } else {
            final orConditions = filtroCentroTrabalho.map((centro) => 'centro_trabalho_real.ilike.%$centro%').join(',');
            query = query.or(orConditions);
          }
        }
        if (dataLancamentoInicio != null) {
          query = query.gte('data_lancamento', dataLancamentoInicio.toIso8601String().split('T')[0]);
        }
        if (dataLancamentoFim != null) {
          query = query.lte('data_lancamento', dataLancamentoFim.toIso8601String().split('T')[0]);
        }
        return query;
      }

      // Processar resposta para extrair valores únicos
      final tipoOrdemSet = <String>{};
      final ordemSet = <String>{};
      final operacaoSet = <String>{};
      final tipoAtividadeSet = <String>{};
      final numeroPessoaSet = <String>{};
      final nomeEmpregadoSet = <String>{};
      final statusSistemaSet = <String>{};
      final centroTrabalhoSet = <String>{};

      void processarResposta(List<dynamic> response, String campoNome) {
        for (final item in response) {
          final map = item as Map<String, dynamic>;
          String? valor;
          
          switch (campoNome) {
            case 'tipo_ordem':
              valor = map['tipo_ordem']?.toString().trim();
              if (valor != null && valor.isNotEmpty) tipoOrdemSet.add(valor);
              break;
            case 'ordem':
              valor = map['ordem']?.toString().trim();
              if (valor != null && valor.isNotEmpty) ordemSet.add(valor);
              break;
            case 'operacao':
              valor = map['operacao']?.toString().trim();
              if (valor != null && valor.isNotEmpty) operacaoSet.add(valor);
              break;
            case 'tipo_atividade_real':
              valor = map['tipo_atividade_real']?.toString().trim();
              if (valor != null && valor.isNotEmpty) tipoAtividadeSet.add(valor);
              break;
            case 'numero_pessoa':
              valor = map['numero_pessoa']?.toString().trim();
              if (valor != null && valor.isNotEmpty) numeroPessoaSet.add(valor);
              break;
            case 'nome_empregado':
              valor = map['nome_empregado']?.toString().trim();
              if (valor != null && valor.isNotEmpty) nomeEmpregadoSet.add(valor);
              break;
            case 'status_sistema':
              valor = map['status_sistema']?.toString().trim();
              if (valor != null && valor.isNotEmpty) statusSistemaSet.add(valor);
              break;
            case 'centro_trabalho_real':
              valor = map['centro_trabalho_real']?.toString().trim();
              if (valor != null && valor.isNotEmpty) centroTrabalhoSet.add(valor);
              break;
          }
        }
      }

      // Buscar valores para cada campo separadamente
      final campos = [
        {'nome': 'tipo_ordem', 'campo': 'tipo_ordem'},
        {'nome': 'ordem', 'campo': 'ordem'},
        {'nome': 'operacao', 'campo': 'operacao'},
        {'nome': 'tipo_atividade_real', 'campo': 'tipo_atividade_real'},
        {'nome': 'numero_pessoa', 'campo': 'numero_pessoa'},
        {'nome': 'nome_empregado', 'campo': 'nome_empregado'},
        {'nome': 'status_sistema', 'campo': 'status_sistema'},
        {'nome': 'centro_trabalho_real', 'campo': 'centro_trabalho_real'},
      ];
      
      for (final campoInfo in campos) {
        final campoNome = campoInfo['nome'] as String;
        
        dynamic campoQuery = _supabase.from('horas_sap').select('tipo_ordem, ordem, operacao, tipo_atividade_real, numero_pessoa, nome_empregado, status_sistema, centro_trabalho_real');
        
        // Mesmo critério de perfil: só empregados REGIONAL & DIVISÃO & SEGMENTO do usuário
        if (usuario != null && usuario.isRoot) {
          // Sem filtro para root
        } else if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
          final matriculasPerfil = await _obterMatriculasPerfilUsuario();
          if (matriculasPerfil.isEmpty) continue;
          campoQuery = campoQuery.inFilter('numero_pessoa', matriculasPerfil);
        } else {
          final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
          if (centrosTrabalhoUsuario.isEmpty) continue;
          final centrosCompletos = centrosTrabalhoUsuario.map((c) => c.trim()).toList();
          if (centrosCompletos.length == 1) {
            campoQuery = campoQuery.ilike('centro_trabalho_real', '%${centrosCompletos[0]}%');
          } else {
            final orConditions = centrosCompletos.map((centro) => 'centro_trabalho_real.ilike.%$centro%').join(',');
            campoQuery = campoQuery.or(orConditions);
          }
        }
        
        // Aplicar todos os filtros EXCETO o do próprio campo
        campoQuery = aplicarFiltrosExceto(campoQuery, campoNome);
        
        try {
          final campoResponse = await campoQuery;
          processarResposta(campoResponse as List, campoNome);
        } catch (e) {
          print('⚠️ Erro ao buscar valores para campo $campoNome: $e');
        }
      }

      return {
        'tipo_ordem': tipoOrdemSet.toList()..sort(),
        'ordem': ordemSet.toList()..sort(),
        'operacao': operacaoSet.toList()..sort(),
        'tipo_atividade_real': tipoAtividadeSet.toList()..sort(),
        'numero_pessoa': numeroPessoaSet.toList()..sort(),
        'nome_empregado': nomeEmpregadoSet.toList()..sort(),
        'status_sistema': statusSistemaSet.toList()..sort(),
        'centro_trabalho_real': centroTrabalhoSet.toList()..sort(),
      };
    } catch (e) {
      print('❌ Erro ao buscar valores de filtros: $e');
      return {
        'tipo_ordem': [],
        'ordem': [],
        'operacao': [],
        'tipo_atividade_real': [],
        'numero_pessoa': [],
        'nome_empregado': [],
        'status_sistema': [],
        'centro_trabalho_real': [],
      };
    }
  }


  // Buscar horas agrupadas por empregado e mês para cálculo de metas
  Future<List<HorasEmpregadoMes>> getHorasPorEmpregadoMes({
    int? ano,
    int? mes,
  }) async {
    try {
      final executorService = ExecutorService();
      final usuario = _authService.currentUser;
      
      // Buscar executores do perfil do usuário
      List<Executor> executores = [];
      
      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        // Buscar executores da REGIONAL & DIVISÃO & SEGMENTO do usuário logado (AND entre os três quando configurados)
        Set<Executor> executoresUnicos = {};
        if (usuario.segmentoIds.isNotEmpty) {
          for (final segmentoId in usuario.segmentoIds) {
            final executoresSegmento = await executorService.getExecutoresPorSegmento(segmentoId);
            executoresUnicos.addAll(executoresSegmento);
          }
        } else if (usuario.divisaoIds.isNotEmpty) {
          for (final divisaoId in usuario.divisaoIds) {
            final executoresDivisao = await executorService.getExecutoresPorDivisao(divisaoId);
            executoresUnicos.addAll(executoresDivisao);
          }
        } else if (usuario.regionalIds.isNotEmpty) {
          final divisoesRows = await _supabase
              .from('divisoes')
              .select('id')
              .inFilter('regional_id', usuario.regionalIds);
          final divisaoIdsDaRegional = (divisoesRows as List).map((d) => d['id'] as String).toList();
          for (final divisaoId in divisaoIdsDaRegional) {
            final executoresDivisao = await executorService.getExecutoresPorDivisao(divisaoId);
            executoresUnicos.addAll(executoresDivisao);
          }
        } else {
          executoresUnicos.addAll(await executorService.getExecutoresAtivos());
        }
        // Aplicar filtro AND: manter só quem está na regional E na divisão E no segmento (quando cada um estiver configurado)
        var listaFiltrada = executoresUnicos.toList();
        if (usuario.regionalIds.isNotEmpty) {
          final divisoesDaRegional = await _supabase
              .from('divisoes')
              .select('id')
              .inFilter('regional_id', usuario.regionalIds);
          final idsDivisaoRegional = (divisoesDaRegional as List).map((d) => d['id'] as String).toSet();
          listaFiltrada = listaFiltrada.where((e) => e.divisaoId != null && idsDivisaoRegional.contains(e.divisaoId)).toList();
        }
        if (usuario.divisaoIds.isNotEmpty) {
          listaFiltrada = listaFiltrada.where((e) => e.divisaoId != null && usuario.divisaoIds.contains(e.divisaoId)).toList();
        }
        if (usuario.segmentoIds.isNotEmpty) {
          listaFiltrada = listaFiltrada.where((e) => e.segmentoIds.any((id) => usuario.segmentoIds.contains(id))).toList();
        }
        // Filtrar executores: ativos, com matrícula e próprios
        final executoresFiltrados = <Executor>[];
        for (var e in listaFiltrada) {
          if (e.ativo && e.matricula != null && e.matricula!.isNotEmpty) {
            final isProprio = await _isEmpresaPropria(e.empresaId);
            if (isProprio) {
              executoresFiltrados.add(e);
            }
          }
        }
        executores = executoresFiltrados;
      } else {
        // Usuário root: buscar todos os executores ativos com matrícula
        final todosExecutores = await executorService.getExecutoresAtivos();
        // Filtrar executores: com matrícula e próprios
        final executoresFiltrados = <Executor>[];
        for (var e in todosExecutores) {
          if (e.matricula != null && e.matricula!.isNotEmpty) {
            final isProprio = await _isEmpresaPropria(e.empresaId);
            if (isProprio) {
              executoresFiltrados.add(e);
            }
          }
        }
        executores = executoresFiltrados;
      }

      if (executores.isEmpty) {
        return [];
      }

      // Criar mapa de matrícula -> executor
      final mapaExecutores = <String, Executor>{};
      for (var executor in executores) {
        if (executor.matricula != null && executor.matricula!.isNotEmpty) {
          final matriculaTrim = executor.matricula!.trim();
          mapaExecutores[matriculaTrim] = executor;
        }
      }

      // Buscar todas as horas do perfil do usuário
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
      // Selecionar campos necessários; tipo_ordem para separar investimento (PROJ) e custeio (demais)
      dynamic query = _supabase.from('horas_sap').select('id, numero_pessoa, nome_empregado, trabalho_real, data_lancamento, tipo_atividade_real, tipo_ordem');

      // Aplicar filtros de perfil
      if (usuario != null && !usuario.isRoot && centrosTrabalhoUsuario.isNotEmpty) {
        final centrosCompletos = centrosTrabalhoUsuario.map((c) => c.trim()).toList();
        if (centrosCompletos.length == 1) {
          query = query.ilike('centro_trabalho_real', '%${centrosCompletos[0]}%');
        } else {
          final orConditions = centrosCompletos.map((centro) => 'centro_trabalho_real.ilike.%$centro%').join(',');
          query = query.or(orConditions);
        }
      }

      // Restringir às matrículas do perfil para não varrer toda a tabela
      final matriculasFiltro = mapaExecutores.keys.toList();
      if (matriculasFiltro.isEmpty) {
        // Sem matrículas válidas => não há dados
        return [];
      }
      
      // Usar filtro IN com sintaxe correta
      if (matriculasFiltro.length == 1) {
        query = query.eq('numero_pessoa', matriculasFiltro[0]);
      } else {
        // Para múltiplas matrículas, usar OR
        final orConditions = matriculasFiltro.map((m) => 'numero_pessoa.eq.$m').join(',');
        query = query.or(orConditions);
      }

      // Filtrar por ano e mês se especificado; caso contrário, limitar a janela de 12 meses para evitar timeout
      if (ano != null) {
        query = query.gte('data_lancamento', '$ano-01-01');
        query = query.lt('data_lancamento', '${ano + 1}-01-01');
        if (mes != null) {
        final mesStr = mes.toString().padLeft(2, '0');
        query = query.gte('data_lancamento', '$ano-$mesStr-01');
        if (mes == 12) {
          query = query.lt('data_lancamento', '${ano + 1}-01-01');
        } else {
          final proxMesStr = (mes + 1).toString().padLeft(2, '0');
          query = query.lt('data_lancamento', '$ano-$proxMesStr-01');
        }
        }
      } else {
        // Janela padrão: últimos 12 meses (do primeiro dia do mês corrente para trás)
        final now = DateTime.now();
        final inicioProxMes = DateTime(now.year, now.month + 1, 1);
        final fimJanela = DateTime(inicioProxMes.year, inicioProxMes.month, 1);
        final inicioJanela = DateTime(fimJanela.year - 1, fimJanela.month, 1);
        query = query.gte('data_lancamento', _formatDate(inicioJanela));
        query = query.lt('data_lancamento', _formatDate(fimJanela));
      }

      final response = await query;
      print('📊 Resposta do Supabase: ${(response as List).length} registros');
      
      final horas = response.map<HoraSAP?>((item) {
        try {
          return HoraSAP.fromMap(item as Map<String, dynamic>);
        } catch (e) {
          print('❌ Erro ao converter hora: $e - Item: $item');
          return null;
        }
      }).whereType<HoraSAP>().toList();
      
      print('📊 Horas convertidas com sucesso: ${horas.length}');

      // Agrupar horas por empregado e mês
      final Map<String, Map<String, double>> horasPorEmpregadoMes = {};
      final Map<String, Map<String, double>> horasExtrasPorEmpregadoMes = {}; // tipo_atividade_real começa com HH
      final Map<String, Map<String, double>> horasExtrasInvestimentoPorEmpregadoMes = {}; // Novo
      final Map<String, Map<String, double>> horasExtrasCusteioPorEmpregadoMes = {}; // Novo
      final Map<String, Map<String, double>> horasInvestimentoPorEmpregadoMes = {}; // tipo_ordem = PROJ
      final Map<String, Map<String, double>> horasCusteioPorEmpregadoMes = {}; // todos os demais tipos de ordem (PREV, INSP, ANOM, PRED, etc.)
      final Map<String, Map<String, Set<String>>> tiposAtividadePorEmpregadoMes = {}; // Tipos de atividade
      final Map<String, String> nomesEmpregados = {};

      for (var hora in horas) {
        if (hora.numeroPessoa == null || hora.numeroPessoa!.isEmpty) {
          print('⚠️ Hora sem número de pessoa - pulando');
          continue;
        }
        if (hora.dataLancamento == null) {
          print('⚠️ Hora sem data de lançamento - pulando');
          continue;
        }
        if (hora.trabalhoReal == null) {
          print('⚠️ Hora sem trabalho real - pulando');
          continue;
        }
        // Incluir na soma tanto valores positivos quanto negativos (horas alocadas com sinal negativo)

        // Garantir que numeroPessoa seja tratado como string para comparação com matrícula
        final numeroPessoa = hora.numeroPessoa?.trim() ?? '';
        if (numeroPessoa.isEmpty) {
          print('⚠️ Hora sem número de pessoa válido - pulando');
          continue;
        }
        
        final dataLancamento = hora.dataLancamento!;
        final anoMes = '${dataLancamento.year}-${dataLancamento.month.toString().padLeft(2, '0')}';
        
        // Total de horas
        horasPorEmpregadoMes.putIfAbsent(numeroPessoa, () => {});
        horasPorEmpregadoMes[numeroPessoa]!.putIfAbsent(anoMes, () => 0.0);
        horasPorEmpregadoMes[numeroPessoa]![anoMes] = horasPorEmpregadoMes[numeroPessoa]![anoMes]! + hora.trabalhoReal!;
        
        // Custeio = todos os tipos de ordem (PREV, INSP, ANOM, PRED, etc.). Investimento = apenas tipo_ordem PROJ.
        final tipoOrd = (hora.tipoOrdem ?? '').trim().toUpperCase();
        
        // DEBUG: Log para verificar classificação
        if (numeroPessoa == '264259' && dataLancamento.month == 1 && dataLancamento.year == 2026) {
           // print('DEBUG HORA: $numeroPessoa - Data: $dataLancamento - TipoOrdem: $tipoOrd - TipoAtiv: ${hora.tipoAtividadeReal} - Trab: ${hora.trabalhoReal}');
        }

        if (tipoOrd == 'PROJ') {
          horasInvestimentoPorEmpregadoMes.putIfAbsent(numeroPessoa, () => {});
          horasInvestimentoPorEmpregadoMes[numeroPessoa]!.putIfAbsent(anoMes, () => 0.0);
          horasInvestimentoPorEmpregadoMes[numeroPessoa]![anoMes] = horasInvestimentoPorEmpregadoMes[numeroPessoa]![anoMes]! + hora.trabalhoReal!;
        } else {
          horasCusteioPorEmpregadoMes.putIfAbsent(numeroPessoa, () => {});
          horasCusteioPorEmpregadoMes[numeroPessoa]!.putIfAbsent(anoMes, () => 0.0);
          horasCusteioPorEmpregadoMes[numeroPessoa]![anoMes] = horasCusteioPorEmpregadoMes[numeroPessoa]![anoMes]! + hora.trabalhoReal!;
        }
        
        // Horas extras: tipo_atividade_real que inicia com HH
        final tipoAtividade = (hora.tipoAtividadeReal ?? '').trim().toUpperCase();
        if (tipoAtividade.startsWith('HH')) {
          horasExtrasPorEmpregadoMes.putIfAbsent(numeroPessoa, () => {});
          horasExtrasPorEmpregadoMes[numeroPessoa]!.putIfAbsent(anoMes, () => 0.0);
          horasExtrasPorEmpregadoMes[numeroPessoa]![anoMes] = horasExtrasPorEmpregadoMes[numeroPessoa]![anoMes]! + hora.trabalhoReal!;
          
          // Separar HHE em Investimento vs Custeio
          if (tipoOrd == 'PROJ') {
             horasExtrasInvestimentoPorEmpregadoMes.putIfAbsent(numeroPessoa, () => {});
             horasExtrasInvestimentoPorEmpregadoMes[numeroPessoa]!.putIfAbsent(anoMes, () => 0.0);
             horasExtrasInvestimentoPorEmpregadoMes[numeroPessoa]![anoMes] = horasExtrasInvestimentoPorEmpregadoMes[numeroPessoa]![anoMes]! + hora.trabalhoReal!;
          } else {
             horasExtrasCusteioPorEmpregadoMes.putIfAbsent(numeroPessoa, () => {});
             horasExtrasCusteioPorEmpregadoMes[numeroPessoa]!.putIfAbsent(anoMes, () => 0.0);
             horasExtrasCusteioPorEmpregadoMes[numeroPessoa]![anoMes] = horasExtrasCusteioPorEmpregadoMes[numeroPessoa]![anoMes]! + hora.trabalhoReal!;
          }
        }
        
        // Tipos de atividade diferentes
        if (tipoAtividade.isNotEmpty) {
           // Parse anoMes (string YYYY-MM) back to int YYYYMM for consistency with other maps if needed, 
           // BUT wait, existing maps use string key 'YYYY-MM' (anoMes variable).
           // The error said 'anoMesInt' is undefined. In my previous edit I defined 'anoMesInt' but maybe I botched the variable name usage.
           // Let's stick to using 'anoMes' (String) if that's what other maps use, OR fix 'anoMesInt'.
           // Looking at lines 853-857, maps are Map<String, Map<String, ...>>. So keys are Strings.
           // Wait, line 893 uses 'anoMes' (String). 
           // Line 932 used 'anoMesInt'. This was the error. 'anoMes' is the String key.
           // However, 'tiposAtividadePorEmpregadoMes' is Map<String, Map<String, Set<String>>>? 
           // Let's check definition at line 857: Map<String, Map<String, Set<String>>>.
           // So key should be String 'anoMes'.
           
           tiposAtividadePorEmpregadoMes.putIfAbsent(numeroPessoa, () => {});
           tiposAtividadePorEmpregadoMes[numeroPessoa]!.putIfAbsent(anoMes, () => <String>{});
           tiposAtividadePorEmpregadoMes[numeroPessoa]![anoMes]!.add(tipoAtividade);
        }
        
        if (hora.nomeEmpregado != null && hora.nomeEmpregado!.isNotEmpty) {
          nomesEmpregados[numeroPessoa] = hora.nomeEmpregado!;
        }
      }
      
      print('📊 Números de pessoa únicos nas horas: ${horasCusteioPorEmpregadoMes.keys.toList()}');

      // Buscar horas programadas das atividades
      final Map<String, Map<String, double>> horasProgramadasPorEmpregadoMes =
          await _buscarHorasProgramadas(ano, mes, matriculasFiltro);

      // Consolidar resultados
      final List<HorasEmpregadoMes> resultados = [];
      
      // Coletar todos os meses únicos que têm data de lançamento ou horas programadas
      final Set<String> mesesComLancamento = {};
      for (var hora in horas) {
        if (hora.dataLancamento != null) {
          final dataLancamento = hora.dataLancamento!;
          final anoMes = '${dataLancamento.year}-${dataLancamento.month.toString().padLeft(2, '0')}';
          mesesComLancamento.add(anoMes);
        }
      }
      for (var matricula in horasProgramadasPorEmpregadoMes.keys) {
        for (var anoMesStr in horasProgramadasPorEmpregadoMes[matricula]!.keys) {
             mesesComLancamento.add(anoMesStr);
        }
      }
      
      // Se filtro de mês/ano, garantir que processe mesmo sem apontamento
      if (ano != null && mes != null) {
          mesesComLancamento.add('$ano-${mes.toString().padLeft(2, '0')}');
      }

      print('📊 Total de executores do perfil: ${executores.length}');
      print('📊 Total de horas encontradas: ${horas.length}');
      print('📊 Total de meses com lançamento: ${mesesComLancamento.length}');
      print('📊 Horas agrupadas por empregado: ${horasPorEmpregadoMes.length}');
      print('📊 Meses com lançamento: ${mesesComLancamento.toList()}');
      print('📊 Números de pessoa nas horas: ${horasPorEmpregadoMes.keys.take(10).toList()}');

      // Para cada executor do perfil
      for (var executor in executores) {
        if (executor.matricula == null || executor.matricula!.isEmpty) {
          print('⚠️ Executor ${executor.nome} não tem matrícula - pulando');
          continue;
        }
        
        final matricula = executor.matricula!.trim();
        final nomeExecutor = executor.nomeCompleto ?? executor.nome;

        // Verificar se há horas para este executor (por número de pessoa = matrícula)
        final horasDoExecutor = horasPorEmpregadoMes[matricula] ?? {};

        if (horasDoExecutor.isEmpty) {
          // Sem apontamento - criar entrada apenas para meses que têm data de lançamento
          // (mas não para este empregado específico)
          for (var anoMesStr in mesesComLancamento) {
            try {
              final partes = anoMesStr.split('-');
              if (partes.length != 2) {
                print('⚠️ Formato de data inválido: $anoMesStr');
                continue;
              }
              final anoMes = int.tryParse(partes[0]);
              final mesMes = int.tryParse(partes[1]);
              
              if (anoMes == null || mesMes == null) {
                print('⚠️ Erro ao parsear data: $anoMesStr');
                continue;
              }
              
              // Aplicar filtros de ano e mês se especificados
              if (ano != null && anoMes != ano) continue;
              if (mes != null && mesMes != mes) continue;
              
              // Calcular meta mensal baseada em dias úteis
              final diasUteis = _calcularDiasUteis(anoMes, mesMes);
              final metaMensal = diasUteis * 8.0;
              
              resultados.add(HorasEmpregadoMes(
                numeroPessoa: matricula,
                nomeEmpregado: nomeExecutor,
                matricula: matricula,
                ano: anoMes,
                mes: mesMes,
                horasApontadas: 0.0,
                horasFaltantes: metaMensal,
                semApontamento: true,
                metaMensal: metaMensal,
                horasProgramadas: horasProgramadasPorEmpregadoMes[matricula]?[anoMesStr] ?? 0.0,
                horasInvestimento: 0.0,
                horasCusteio: 0.0,
                horasExtrasInvestimento: 0.0, // Novo
                horasExtrasCusteio: 0.0, // Novo
              ));
            } catch (e) {
              print('❌ Erro ao processar mês $anoMesStr: $e');
            }
          }
        } else {
          // Há apontamentos - processar cada mês baseado na data de lançamento
          for (var entry in horasDoExecutor.entries) {
            try {
              final partes = entry.key.split('-');
              if (partes.length != 2) {
                print('⚠️ Formato de data inválido: ${entry.key}');
                continue;
              }
              final anoMes = int.tryParse(partes[0]);
              final mesMes = int.tryParse(partes[1]);
              
              if (anoMes == null || mesMes == null) {
                print('⚠️ Erro ao parsear data: ${entry.key}');
                continue;
              }
              
              // Aplicar filtros de ano e mês se especificados
              if (ano != null && anoMes != ano) continue;
              if (mes != null && mesMes != mes) continue;
              
              // Calcular meta mensal baseada em dias úteis
              final diasUteis = _calcularDiasUteis(anoMes, mesMes);
              final metaMensal = diasUteis * 8.0;
              
              final horasApontadas = entry.value;
              final horasFaltantes = (metaMensal - horasApontadas).clamp(0.0, metaMensal);
              
              // Buscar horas extras (HHE) para este empregado e mês
              final horasExtras = horasExtrasPorEmpregadoMes[matricula]?[entry.key] ?? 0.0;
              
              // Buscar tipos de atividade para este empregado e mês
              final tiposAtividade = tiposAtividadePorEmpregadoMes[matricula]?[entry.key] ?? <String>{};
              
              final nomeEmpregadoHora = nomesEmpregados[matricula];
              final nomeEmpregadoFinal = (nomeEmpregadoHora != null && nomeEmpregadoHora.isNotEmpty) 
                  ? nomeEmpregadoHora 
                  : nomeExecutor;
              
              if (nomeEmpregadoFinal.isEmpty) {
                print('⚠️ Nome do empregado vazio para matrícula $matricula - usando "Sem nome"');
              }
              
              resultados.add(HorasEmpregadoMes(
                numeroPessoa: matricula,
                nomeEmpregado: nomeEmpregadoFinal.isNotEmpty ? nomeEmpregadoFinal : 'Sem nome',
                matricula: matricula,
                ano: anoMes,
                mes: mesMes,
                horasApontadas: horasApontadas,
                horasFaltantes: horasFaltantes,
                semApontamento: false,
                horasExtras: horasExtras,
                tiposAtividade: tiposAtividade,
                metaMensal: metaMensal,
                horasProgramadas: horasProgramadasPorEmpregadoMes[matricula]?[entry.key] ?? 0.0,
                horasInvestimento: horasInvestimentoPorEmpregadoMes[matricula]?[entry.key] ?? 0.0,
                horasCusteio: horasCusteioPorEmpregadoMes[matricula]?[entry.key] ?? 0.0,
                horasExtrasInvestimento: horasExtrasInvestimentoPorEmpregadoMes[matricula]?[entry.key] ?? 0.0,
                horasExtrasCusteio: horasExtrasCusteioPorEmpregadoMes[matricula]?[entry.key] ?? 0.0,
              ));
            } catch (e) {
              print('❌ Erro ao processar entrada ${entry.key}: $e');
            }
          }
        }
      }

      // Ordenar por nome do empregado, depois por ano e mês
      resultados.sort((a, b) {
        final nomeCompare = a.nomeEmpregado.compareTo(b.nomeEmpregado);
        if (nomeCompare != 0) return nomeCompare;
        final anoCompare = a.ano.compareTo(b.ano);
        if (anoCompare != 0) return anoCompare;
        return a.mes.compareTo(b.mes);
      });

      return resultados;
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar horas por empregado e mês: $e');
      print('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  // Buscar horas programadas das atividades usando VIEW do Supabase
  Future<Map<String, Map<String, double>>> _buscarHorasProgramadas(
    int? ano,
    int? mes,
    List<String> matriculasFiltro,
  ) async {
    try {
      final Map<String, Map<String, double>> horasProgramadas = {};
      
      print('📋 ============================================');
      print('📋 DEBUG: Buscando horas programadas via VIEW');
      
      // VIEW horas_programadas_por_empregado_mes (sobre MV): matricula, mes_ref, total_trabalho_planejado
      dynamic query = _supabase
          .from('horas_programadas_por_empregado_mes')
          .select('matricula, mes_ref, total_trabalho_planejado');
      
      // mes_ref é date: usar comparações de data (like não funciona em date)
      if (ano != null && mes != null) {
        final primeiroDia = '${ano.toString()}-${mes.toString().padLeft(2, '0')}-01';
        query = query.eq('mes_ref', primeiroDia);
      } else if (ano != null) {
        query = query
            .gte('mes_ref', '$ano-01-01')
            .lte('mes_ref', '$ano-12-31');
      } else {
        final now = DateTime.now();
        final anoAtual = now.year;
        final anoAnterior = anoAtual - 1;
        query = query
            .gte('mes_ref', '$anoAnterior-01-01')
            .lte('mes_ref', '$anoAtual-12-31');
      }

      // Filtrar pelas matrículas do perfil (mesmo conjunto já usado nas horas apontadas)
      if (matriculasFiltro.isNotEmpty) {
        final orConditions = matriculasFiltro.map((v) => 'matricula.eq.$v').join(',');
        query = query.or(orConditions);
      } else {
        return {};
      }
      
      print('📋 DEBUG: Executando query na VIEW...');
      final response = await query;
      final resultados = response as List;
      
      print('📋 DEBUG: Total de registros encontrados na VIEW: ${resultados.length}');
      
      // Processar: mes_ref (YYYY-MM ou date) -> total_trabalho_planejado
      for (var row in resultados) {
        final matricula = row['matricula'] as String?;
        final mesRef = row['mes_ref'];
        final horas = (row['total_trabalho_planejado'] as num?)?.toDouble() ?? 0.0;
        if (matricula == null || matricula.isEmpty) continue;
        String anoMesStr;
        if (mesRef is String) {
          anoMesStr = mesRef.length >= 7 ? mesRef.substring(0, 7) : mesRef;
        } else if (mesRef is DateTime) {
          anoMesStr = '${mesRef.year}-${mesRef.month.toString().padLeft(2, '0')}';
        } else {
          continue;
        }
        horasProgramadas.putIfAbsent(matricula, () => {});
        horasProgramadas[matricula]![anoMesStr] = horas;
      }
      
      print('📋 DEBUG: ============================================');
      print('📋 DEBUG: Resumo final das horas programadas:');
      for (var entry in horasProgramadas.entries) {
        print('   Matrícula ${entry.key}:');
        for (var mesEntry in entry.value.entries) {
          print('      ${mesEntry.key}: ${mesEntry.value.toStringAsFixed(2)} horas');
        }
      }
      
      print('✅ Horas programadas calculadas para ${horasProgramadas.length} empregados');
      return horasProgramadas;
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar horas programadas: $e');
      print('   Stack trace: $stackTrace');
      return {};
    }
  }

  /// Horas alocadas por dia no mês (agrupadas por data_lancamento), para uso no gráfico acumulado.
  /// [matriculas] lista de matrículas a considerar (ex.: da view Metas). Se vazia, retorna {}.
  Future<Map<String, double>> getHorasAlocadasPorDiaNoMes(int ano, int mes, List<String> matriculas) async {
    if (matriculas.isEmpty) return {};
    try {
      final mesStr = mes.toString().padLeft(2, '0');
      final firstDay = '$ano-$mesStr-01';
      dynamic query = _supabase
          .from('horas_sap')
          .select('data_lancamento, trabalho_real, numero_pessoa')
          .gte('data_lancamento', firstDay)
          .lt('data_lancamento', mes == 12 ? '${ano + 1}-01-01' : '$ano-${(mes + 1).toString().padLeft(2, '0')}-01');
      final usuario = _authService.currentUser;
      if (usuario != null && !usuario.isRoot) {
        final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
        if (centrosTrabalhoUsuario.isNotEmpty) {
          final centrosCompletos = centrosTrabalhoUsuario.map((c) => c.trim()).toList();
          if (centrosCompletos.length == 1) {
            query = query.ilike('centro_trabalho_real', '%${centrosCompletos[0]}%');
          } else {
            final orConditions = centrosCompletos.map((c) => 'centro_trabalho_real.ilike.%$c%').join(',');
            query = query.or(orConditions);
          }
        }
      }
      if (matriculas.length == 1) {
        query = query.eq('numero_pessoa', matriculas.first.trim());
      } else {
        final orConditions = matriculas.map((m) => 'numero_pessoa.eq.${m.trim()}').join(',');
        query = query.or(orConditions);
      }
      final response = await query as List<dynamic>;
      final Map<String, double> porDia = {};
      for (var row in response) {
        final r = row as Map<String, dynamic>;
        final dataLanc = r['data_lancamento'];
        final trabalho = (r['trabalho_real'] as num?)?.toDouble();
        if (dataLanc == null || trabalho == null) continue;
        DateTime? dt;
        if (dataLanc is String) {
          dt = DateTime.tryParse(dataLanc);
        } else if (dataLanc is DateTime) {
          dt = dataLanc;
        }
        if (dt == null) continue;
        final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        porDia[key] = (porDia[key] ?? 0) + trabalho;
      }
      return porDia;
    } catch (e) {
      print('❌ Erro ao buscar horas por dia: $e');
      return {};
    }
  }

  /// Ordens em que cada empregado está programado (tarefas) por ano/mês.
  /// Opcionalmente restringe a uma lista de matrículas.
  Future<List<OrdemProgramadaEmpregadoMes>> getOrdensProgramadasPorEmpregadoMes({
    required int ano,
    int? mes,
    List<String>? matriculas,
  }) async {
    try {
      dynamic query = _supabase
          .from('ordens_programadas_por_empregado_mes')
          .select('matricula, ano, mes, ano_mes, ordem, tipo, sala, texto_breve, task_id, task_tarefa, task_status, local_detalhe, regional_id, divisao_id, segmento_id')
          .eq('ano', ano);
      if (mes != null) {
        query = query.eq('mes', mes);
      }
      if (matriculas != null && matriculas.isNotEmpty) {
        if (matriculas.length == 1) {
          query = query.eq('matricula', matriculas.first.trim());
        } else {
          final orConditions = matriculas.map((m) => 'matricula.eq.${m.trim()}').join(',');
          query = query.or(orConditions);
        }
      }

      final response = await query as List<dynamic>;
      final usuario = _authService.currentUser;
      List<dynamic> rows = response;
      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        rows = rows.where((row) {
          final r = row as Map<String, dynamic>;
          final regionalId = r['regional_id'] as String?;
          final divisaoId = r['divisao_id'] as String?;
          final segmentoId = r['segmento_id'] as String?;
          bool okRegional = usuario.regionalIds.isEmpty || (regionalId != null && usuario.regionalIds.contains(regionalId));
          bool okDivisao = usuario.divisaoIds.isEmpty || (divisaoId != null && usuario.divisaoIds.contains(divisaoId));
          bool okSegmento = usuario.segmentoIds.isEmpty || (segmentoId != null && usuario.segmentoIds.contains(segmentoId));
          return okRegional && okDivisao && okSegmento;
        }).toList();
      }
      return rows.map((e) => OrdemProgramadaEmpregadoMes.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ Erro ao buscar ordens programadas: $e');
      return [];
    }
  }

  /// Horas apontadas por empregado, ordem e mês (VIEW horas_apontadas_por_empregado_ordem_mes).
  /// [matriculas] opcional: restringe às matrículas informadas.
  Future<List<HorasApontadasOrdemMes>> getHorasApontadasPorEmpregadoOrdemMes({
    required int ano,
    int? mes,
    List<String>? matriculas,
  }) async {
    try {
      dynamic query = _supabase
          .from('horas_apontadas_por_empregado_ordem_mes')
          .select('matricula, ordem, ano, mes, ano_mes, horas_apontadas')
          .eq('ano', ano);
      if (mes != null) {
        query = query.eq('mes', mes);
      }
      if (matriculas != null && matriculas.isNotEmpty) {
        if (matriculas.length == 1) {
          query = query.eq('matricula', matriculas.first.trim());
        } else {
          final orConditions = matriculas.map((m) => 'matricula.eq.${m.trim()}').join(',');
          query = query.or(orConditions);
        }
      }
      final response = await query;
      return (response as List).map((e) => HorasApontadasOrdemMes.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ Erro ao buscar horas apontadas por ordem: $e');
      return [];
    }
  }

  /// Detalhes (tipo, sala, texto_breve, local) de ordens a partir dos números. Retorna mapa ordem -> {tipo, sala, texto_breve, local}.
  Future<Map<String, Map<String, String?>>> getDetalhesOrdensByNumeros(List<String> numerosOrdem) async {
    if (numerosOrdem.isEmpty) return {};
    try {
      final list = numerosOrdem.map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
      if (list.isEmpty) return {};
      dynamic query = _supabase.from('ordens').select('ordem, tipo, sala, texto_breve, denominacao_local_instalacao, local_instalacao');
      if (list.length == 1) {
        query = query.eq('ordem', list.first);
      } else {
        query = query.inFilter('ordem', list);
      }
      final response = await query as List<dynamic>;
      final map = <String, Map<String, String?>>{};
      for (var row in response) {
        final r = row as Map<String, dynamic>;
        final ordem = (r['ordem'] as String?)?.trim() ?? '';
        if (ordem.isEmpty) continue;
        final denom = (r['denominacao_local_instalacao'] as String?)?.trim();
        final localInst = (r['local_instalacao'] as String?)?.trim();
        final local = (denom != null && denom.isNotEmpty) ? denom : localInst;
        map[ordem] = {
          'tipo': (r['tipo'] as String?)?.trim(),
          'sala': (r['sala'] as String?)?.trim(),
          'texto_breve': (r['texto_breve'] as String?)?.trim(),
          'local': local,
        };
      }
      return map;
    } catch (e) {
      print('❌ Erro ao buscar detalhes das ordens: $e');
      return {};
    }
  }
}
