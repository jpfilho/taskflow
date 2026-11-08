import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system/theme/taskflow_theme_extension.dart';
import '../design_system/foundations/tf_radius.dart';
import '../models/nota_sap.dart';
import '../models/nota_sap_analise.dart';
import '../services/auth_service_simples.dart';
import '../services/nota_sap_analise_service.dart';
import 'nota_workspace/nota_workspace_analysis_tab.dart';
import 'nota_workspace/nota_workspace_attachments_tab.dart';
import 'nota_workspace/nota_workspace_discussion_tab.dart';
import 'nota_workspace/nota_workspace_materials_tab.dart';
import 'nota_workspace/nota_workspace_overview_tab.dart';
import 'nota_workspace/nota_similaridade_panel.dart';
import 'nota_workspace/nota_workspace_grupos_tab.dart';
import '../models/nota_sap_tag.dart';
import '../services/nota_sap_tag_service.dart';
import 'nota_workspace/nota_tag_selector_dialog.dart';

class NotaAnaliseWorkspace extends StatefulWidget {
  final NotaSAP nota;
  final List<NotaSAP>? listaNotas;
  final int? indiceInicial;
  final Set<String>? notasSelecionadasIniciais;
  final ValueChanged<Set<String>>? onNotasSelecionadasMudou;
  final ValueChanged<NotaSAP>? onNotaMudou;
  final VoidCallback? onProgramarTarefa;
  final void Function(NotaSAP nota)? onProgramarTarefaComNota;
  final void Function(List<NotaSAP> notas)? onProgramarMultiplasNotas;
  final VoidCallback? onVincularTarefaExistente;
  final void Function(NotaSAP nota)? onVincularTarefaExistenteComNota;
  final void Function(List<NotaSAP> notas)? onVincularMultiplasNotas;
  final NotaSapAnaliseService? service;
  final int initialTab;
  final bool readOnly;

  const NotaAnaliseWorkspace({
    super.key,
    required this.nota,
    this.listaNotas,
    this.indiceInicial,
    this.notasSelecionadasIniciais,
    this.onNotasSelecionadasMudou,
    this.onNotaMudou,
    this.onProgramarTarefa,
    this.onProgramarTarefaComNota,
    this.onProgramarMultiplasNotas,
    this.onVincularTarefaExistente,
    this.onVincularTarefaExistenteComNota,
    this.onVincularMultiplasNotas,
    this.service,
    this.initialTab = 0,
    this.readOnly = false,
  });

  /// Abre o Workspace de forma responsiva:
  /// - Desktop / Web: Dialog / Painel amplo centralizado (85% a 90% da largura).
  /// - Mobile: Tela inteira via MaterialPageRoute.
  static Future<void> abrir(
    BuildContext context, {
    required NotaSAP nota,
    List<NotaSAP>? listaNotas,
    int? indiceInicial,
    Set<String>? notasSelecionadasIniciais,
    ValueChanged<Set<String>>? onNotasSelecionadasMudou,
    ValueChanged<NotaSAP>? onNotaMudou,
    VoidCallback? onProgramarTarefa,
    void Function(NotaSAP nota)? onProgramarTarefaComNota,
    void Function(List<NotaSAP> notas)? onProgramarMultiplasNotas,
    VoidCallback? onVincularTarefaExistente,
    void Function(NotaSAP nota)? onVincularTarefaExistenteComNota,
    void Function(List<NotaSAP> notas)? onVincularMultiplasNotas,
    NotaSapAnaliseService? service,
    int initialTab = 0,
    bool readOnly = false,
  }) async {
    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: () {
              final maxW = math.min(1440.0, MediaQuery.of(context).size.width * 0.96);
              return BoxConstraints(
                maxWidth: maxW,
                maxHeight: MediaQuery.of(context).size.height * 0.94,
                minWidth: math.min(780.0, maxW),
              );
            }(),
            child: NotaAnaliseWorkspace(
              nota: nota,
              listaNotas: listaNotas,
              indiceInicial: indiceInicial,
              notasSelecionadasIniciais: notasSelecionadasIniciais,
              onNotasSelecionadasMudou: onNotasSelecionadasMudou,
              onNotaMudou: onNotaMudou,
              onProgramarTarefa: onProgramarTarefa,
              onProgramarTarefaComNota: onProgramarTarefaComNota,
              onProgramarMultiplasNotas: onProgramarMultiplasNotas,
              onVincularTarefaExistente: onVincularTarefaExistente,
              onVincularTarefaExistenteComNota: onVincularTarefaExistenteComNota,
              onVincularMultiplasNotas: onVincularMultiplasNotas,
              service: service,
              initialTab: initialTab,
              readOnly: readOnly,
            ),
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) => NotaAnaliseWorkspace(
            nota: nota,
            listaNotas: listaNotas,
            indiceInicial: indiceInicial,
            notasSelecionadasIniciais: notasSelecionadasIniciais,
            onNotasSelecionadasMudou: onNotasSelecionadasMudou,
            onNotaMudou: onNotaMudou,
            onProgramarTarefa: onProgramarTarefa,
            onProgramarTarefaComNota: onProgramarTarefaComNota,
            onProgramarMultiplasNotas: onProgramarMultiplasNotas,
            onVincularTarefaExistente: onVincularTarefaExistente,
            onVincularTarefaExistenteComNota: onVincularTarefaExistenteComNota,
            onVincularMultiplasNotas: onVincularMultiplasNotas,
            service: service,
            initialTab: initialTab,
            readOnly: readOnly,
          ),
        ),
      );
    }
  }

  @override
  State<NotaAnaliseWorkspace> createState() => _NotaAnaliseWorkspaceState();
}

class _NotaAnaliseWorkspaceState extends State<NotaAnaliseWorkspace>
    with SingleTickerProviderStateMixin {
  late final NotaSapAnaliseService _service;
  late final TabController _tabController;

  late NotaSAP _notaAtual;
  late List<NotaSAP> _listaNotas;
  late int _indiceAtual;
  late Set<String> _notasSelecionadas;

  GlobalKey<NotaWorkspaceAnalysisTabState> _analysisTabKey =
      GlobalKey<NotaWorkspaceAnalysisTabState>();

  NotaSapAnalise? _analise;
  bool _isLoadingAnalise = true;
  bool _isSavingAnalise = false;
  bool _hasUnsavedChanges = false;

  late final NotaSapTagService _tagService;
  List<NotaSapTag> _tagsDaNota = [];
  bool _carregandoTags = false;

  bool get _temNavegacao => _listaNotas.length > 1;
  bool get _temAnterior => _indiceAtual > 0;
  bool get _temProxima => _indiceAtual < _listaNotas.length - 1;
  bool get _notaAtualEstaSelecionada => _notasSelecionadas.contains(_notaAtual.id);

  NotaAnaliseStatus get _currentStatus =>
      _analise?.statusAnalise ?? NotaAnaliseStatus.naoIniciada;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotaSapAnaliseService();
    _notaAtual = widget.nota;
    _notasSelecionadas = Set<String>.from(widget.notasSelecionadasIniciais ?? {});

    if (widget.listaNotas != null && widget.listaNotas!.isNotEmpty) {
      _listaNotas = List<NotaSAP>.from(widget.listaNotas!);
      final idx = widget.indiceInicial ??
          _listaNotas.indexWhere((n) => n.id == _notaAtual.id);
      if (idx != -1) {
        _indiceAtual = idx;
      } else {
        _listaNotas.insert(0, _notaAtual);
        _indiceAtual = 0;
      }
    } else {
      _listaNotas = [_notaAtual];
      _indiceAtual = 0;
    }

    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 6),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _tagService = NotaSapTagService();
    _carregarAnalise();
    _carregarTags();
  }

  Future<void> _carregarAnalise() async {
    setState(() => _isLoadingAnalise = true);
    try {
      final analise = await _service.buscarAnalise(_notaAtual.id);
      if (mounted) {
        setState(() {
          _analise = analise;
          _isLoadingAnalise = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAnalise = false);
      }
    }
  }

  Future<void> _salvarAnalise({bool fecharAposSalvar = false}) async {
    final tabState = _analysisTabKey.currentState;
    if (tabState == null) return;

    String userName = 'Analista';
    try {
      final auth = AuthServiceSimples();
      final user = auth.currentUser;
      userName = auth.getUserName() ?? user?.email ?? 'Analista';
    } catch (_) {
      // Fallback em ambientes de teste ou sem auth inicializado
    }

    final payload = tabState.buildAnalisePayload(
      notaSapId: _notaAtual.id,
      numeroNota: _notaAtual.nota,
      analistaId: null,
      analistaNome: userName,
    );

    setState(() => _isSavingAnalise = true);

    try {
      final salva = await _service.salvarAnalise(payload);
      tabState.markClean();

      if (mounted) {
        setState(() {
          _analise = salva;
          _hasUnsavedChanges = false;
          _isSavingAnalise = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Análise técnica salva com sucesso!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );

        if (fecharAposSalvar) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingAnalise = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar análise: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Navega de forma segura para o índice desejado na lista de notas
  Future<void> _navegarParaIndice(int novoIndice) async {
    if (novoIndice < 0 ||
        novoIndice >= _listaNotas.length ||
        novoIndice == _indiceAtual) {
      return;
    }

    // Se houver alterações não salvas na análise técnica
    if (_hasUnsavedChanges && !widget.readOnly) {
      final colors = context.tfColors;
      final typography = context.tfTypography;

      final decisao = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            'Alterações não salvas',
            style: typography.sectionTitle.copyWith(color: colors.textPrimary),
          ),
          content: Text(
            'A análise técnica da Nota SAP ${_notaAtual.nota} possui alterações não salvas. O que deseja fazer antes de mudar de nota?',
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancelar'),
              child: Text(
                'Permanecer nesta nota',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('descartar'),
              child: Text(
                'Descartar e Avançar',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.primaryForeground,
              ),
              onPressed: () => Navigator.of(ctx).pop('salvar'),
              child: const Text('Salvar e Avançar'),
            ),
          ],
        ),
      );

      if (decisao == null || decisao == 'cancelar') {
        return;
      }

      if (decisao == 'salvar') {
        await _salvarAnalise(fecharAposSalvar: false);
      }
    }

    final novaNota = _listaNotas[novoIndice];
    setState(() {
      _indiceAtual = novoIndice;
      _notaAtual = novaNota;
      _hasUnsavedChanges = false;
      _analise = null;
      _analysisTabKey = GlobalKey<NotaWorkspaceAnalysisTabState>();
    });

    widget.onNotaMudou?.call(novaNota);
    await _carregarAnalise();
    await _carregarTags();
  }

  Future<bool> _tentarFechar() async {
    if (widget.readOnly || !_hasUnsavedChanges) {
      return true;
    }

    final colors = context.tfColors;
    final typography = context.tfTypography;

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Alterações não salvas',
          style: typography.sectionTitle.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Existem alterações na análise técnica que não foram salvas. Deseja salvar antes de fechar?',
          style: typography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('descartar'),
            child: Text('Descartar',
                style: TextStyle(color: Colors.red.shade700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('continuar'),
            child: Text('Continuar editando',
                style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryForeground,
            ),
            onPressed: () => Navigator.of(ctx).pop('salvar'),
            child: const Text('Salvar e Fechar'),
          ),
        ],
      ),
    );

    if (resultado == 'descartar') {
      return true;
    } else if (resultado == 'salvar') {
      await _salvarAnalise(fecharAposSalvar: false);
      return true;
    }

    return false;
  }

  void _alternarSelecaoNotaAtual() {
    setState(() {
      if (_notasSelecionadas.contains(_notaAtual.id)) {
        _notasSelecionadas.remove(_notaAtual.id);
      } else {
        _notasSelecionadas.add(_notaAtual.id);
      }
    });
    widget.onNotasSelecionadasMudou?.call(_notasSelecionadas);
  }

  void _limparSelecaoNotas() {
    setState(() {
      _notasSelecionadas.clear();
    });
    widget.onNotasSelecionadasMudou?.call(_notasSelecionadas);
  }

  List<NotaSAP> _obterNotasSelecionadasObjetos() {
    if (_notasSelecionadas.isEmpty) {
      return [_notaAtual];
    }
    final lista =
        _listaNotas.where((n) => _notasSelecionadas.contains(n.id)).toList();
    if (lista.isEmpty && _notasSelecionadas.contains(_notaAtual.id)) {
      lista.add(_notaAtual);
    }
    return lista.isNotEmpty ? lista : [_notaAtual];
  }

  void _aoClicarProgramar() {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final semAnalise = _analise == null;
    final qtdSelecionadas = _notasSelecionadas.length;
    final temMultiplas = qtdSelecionadas > 1;
    final notasParaProgramar = _obterNotasSelecionadasObjetos();
    final notaPrincipal = notasParaProgramar.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.event_available, color: colors.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                temMultiplas
                    ? 'Programação de $qtdSelecionadas Notas SAP'
                    : 'Programação da Nota SAP',
                style:
                    typography.sectionTitle.copyWith(color: colors.textPrimary),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (semAnalise && !temMultiplas) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withAlpha(90)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Esta Nota SAP ainda não possui análise técnica prévia. A análise é opcional e você pode prosseguir normalmente.',
                          style: typography.bodyMedium.copyWith(
                              fontSize: 12, color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                temMultiplas
                    ? 'Você selecionou $qtdSelecionadas notas para programar em conjunto. Como deseja prosseguir?'
                    : 'Como você deseja programar esta Nota SAP?',
                style: typography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Opção 1: Criar Nova Tarefa
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                  if (temMultiplas &&
                      widget.onProgramarMultiplasNotas != null) {
                    widget.onProgramarMultiplasNotas!(notasParaProgramar);
                  } else if (widget.onProgramarTarefaComNota != null) {
                    widget.onProgramarTarefaComNota!(notaPrincipal);
                  } else {
                    widget.onProgramarTarefa?.call();
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.borderDefault),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.add_task,
                            color: colors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              temMultiplas
                                  ? 'Criar Nova Tarefa ($qtdSelecionadas notas)'
                                  : 'Criar Nova Tarefa',
                              style: typography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              temMultiplas
                                  ? 'Abre o formulário para criar uma tarefa vinculando as $qtdSelecionadas notas selecionadas.'
                                  : 'Abre o formulário para criar uma tarefa vinculando as notas do grupo.',
                              style: typography.caption
                                  .copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: colors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Opção 2: Vincular a Tarefa Existente
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                  if (temMultiplas &&
                      widget.onVincularMultiplasNotas != null) {
                    widget.onVincularMultiplasNotas!(notasParaProgramar);
                  } else if (widget.onVincularTarefaExistenteComNota != null) {
                    widget.onVincularTarefaExistenteComNota!(notaPrincipal);
                  } else if (widget.onVincularTarefaExistente != null) {
                    widget.onVincularTarefaExistente!.call();
                  } else if (widget.onProgramarTarefaComNota != null) {
                    widget.onProgramarTarefaComNota!(notaPrincipal);
                  } else {
                    widget.onProgramarTarefa?.call();
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.borderDefault),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.link,
                            color: Colors.blue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              temMultiplas
                                  ? 'Vincular a Tarefa Existente ($qtdSelecionadas notas)'
                                  : 'Vincular a Tarefa Existente',
                              style: typography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              temMultiplas
                                  ? 'Adiciona as $qtdSelecionadas notas selecionadas a uma tarefa já cadastrada no sistema.'
                                  : 'Adiciona esta nota a uma tarefa já cadastrada no sistema.',
                              style: typography.caption
                                  .copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: colors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(NotaAnaliseStatus s) {
    switch (s) {
      case NotaAnaliseStatus.naoIniciada:
        return Colors.grey.shade600;
      case NotaAnaliseStatus.emAnalise:
        return Colors.blue.shade600;
      case NotaAnaliseStatus.concluida:
        return Colors.green.shade600;
      case NotaAnaliseStatus.aguardandoInformacao:
        return Colors.orange.shade700;
      case NotaAnaliseStatus.cancelada:
        return Colors.red.shade600;
    }
  }

  String _buildInfoDataCabecalho() {
    if (_notaAtual.estaConcluida && _notaAtual.dataConclusao != null) {
      final dt = _notaAtual.dataConclusao!;
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      return ' • Concluída em: $dia/$mes/${dt.year}';
    } else if (_notaAtual.criadoEm != null) {
      final dt = _notaAtual.criadoEm!;
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      return ' • Criada em: $dia/$mes/${dt.year}';
    }
    return '';
  }

  /// Monta o texto de Local e Sala que antecede a descrição da Nota SAP no cabeçalho
  String _buildPrefixoLocalESala() {
    final partes = <String>[];
    final local = (_notaAtual.local ?? _notaAtual.localInstalacao ?? '').trim();
    final sala = (_notaAtual.sala ?? '').trim();

    if (local.isNotEmpty) partes.add(local);
    if (sala.isNotEmpty) partes.add('Sala: $sala');

    return partes.join(' • ');
  }

  /// Retorna o texto completo (Local, Sala e Descrição) para tooltip
  String _buildTextoCompletoNota() {
    final prefixo = _buildPrefixoLocalESala();
    final desc = (_notaAtual.descricao ?? '').trim();
    if (prefixo.isNotEmpty && desc.isNotEmpty) {
      return '$prefixo — $desc';
    } else if (prefixo.isNotEmpty) {
      return prefixo;
    }
    return desc;
  }

  /// Constrói os botões de navegação para a Nota Anterior e Nota Seguinte
  Widget _buildNavegacaoNotas(dynamic colors, dynamic typography) {
    if (!_temNavegacao) return const SizedBox.shrink();

    final isNarrow = MediaQuery.of(context).size.width < 640;

    return Container(
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: _temAnterior
                ? 'Nota Anterior (Alt+←)'
                : 'Primeira nota da lista',
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(TFRadius.r8),
              ),
              onTap: _temAnterior
                  ? () => _navegarParaIndice(_indiceAtual - 1)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_left,
                      size: 20,
                      color: _temAnterior
                          ? colors.primary
                          : colors.textSecondary.withAlpha(90),
                    ),
                    if (!isNarrow) ...[
                      const SizedBox(width: 2),
                      Text(
                        'Anterior',
                        style: typography.caption.copyWith(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: _temAnterior
                              ? colors.textPrimary
                              : colors.textSecondary.withAlpha(90),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 18,
            width: 1,
            color: colors.borderSubtle,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_indiceAtual + 1}',
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                Text(
                  ' / ${_listaNotas.length}',
                  style: typography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 18,
            width: 1,
            color: colors.borderSubtle,
          ),
          Tooltip(
            message: _temProxima
                ? 'Próxima Nota (Alt+→)'
                : 'Última nota da lista',
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(TFRadius.r8),
              ),
              onTap: _temProxima
                  ? () => _navegarParaIndice(_indiceAtual + 1)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isNarrow) ...[
                      Text(
                        'Próxima',
                        style: typography.caption.copyWith(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: _temProxima
                              ? colors.textPrimary
                              : colors.textSecondary.withAlpha(90),
                        ),
                      ),
                      const SizedBox(width: 2),
                    ],
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: _temProxima
                          ? colors.primary
                          : colors.textSecondary.withAlpha(90),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final statusColor = _getStatusColor(_currentStatus);

    final prefixoLocalSala = _buildPrefixoLocalESala();
    final temDescricao = prefixoLocalSala.isNotEmpty ||
        (_notaAtual.descricao != null &&
            _notaAtual.descricao!.trim().isNotEmpty);

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final podeFechar = await _tentarFechar();
        if (podeFechar && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
            if (_temAnterior) _navegarParaIndice(_indiceAtual - 1);
          },
          const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () {
            if (_temProxima) _navegarParaIndice(_indiceAtual + 1);
          },
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            if (_hasUnsavedChanges && !_isSavingAnalise) {
              _salvarAnalise();
            }
          },
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
            if (_hasUnsavedChanges && !_isSavingAnalise) {
              _salvarAnalise();
            }
          },
          const SingleActivator(LogicalKeyboardKey.escape): () async {
            if (_hasUnsavedChanges) {
              final podeFechar = await _tentarFechar();
              if (podeFechar && context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: colors.surface,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(bottom: BorderSide(color: colors.borderSubtle)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.md,
                        vertical: spacing.sm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(TFRadius.r8),
                            ),
                            child: Icon(Icons.assignment,
                                color: colors.primary, size: 22),
                          ),
                          SizedBox(width: spacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: spacing.xs,
                                  runSpacing: 2,
                                  children: [
                                    if (_notaAtual.tipo != null &&
                                        _notaAtual.tipo!.trim().isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E3A5F),
                                          borderRadius:
                                              BorderRadius.circular(TFRadius.r4),
                                        ),
                                        child: Text(
                                          _notaAtual.tipo!.trim(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: spacing.xs / 2),
                                    ],
                                    Text(
                                      'Nota SAP: ${_notaAtual.nota}',
                                      style: typography.sectionTitle.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.copy,
                                          size: 15, color: colors.textSecondary),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Copiar número da nota',
                                      onPressed: () {
                                        Clipboard.setData(
                                            ClipboardData(text: _notaAtual.nota));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Nota copiada!'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                    ),
                                    SizedBox(width: spacing.sm),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor.withAlpha(30),
                                        borderRadius:
                                            BorderRadius.circular(TFRadius.r8),
                                        border: Border.all(
                                            color: statusColor.withAlpha(100)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: spacing.xs),
                                          Text(
                                            _currentStatus.label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: statusColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_notaAtual.statusSistema != null &&
                                        _notaAtual.statusSistema!.trim().isNotEmpty) ...[
                                      SizedBox(width: spacing.xs),
                                      Builder(builder: (context) {
                                        final sis = _notaAtual.statusSistema!.toUpperCase();
                                        final isConcluida = sis.contains('ENCE') ||
                                            sis.contains('ENTE') ||
                                            sis.contains('MSEN');
                                        final bg = isConcluida
                                            ? const Color(0xFFF0FDF4)
                                            : const Color(0xFFFFF7ED);
                                        final border = isConcluida
                                            ? const Color(0xFF86EFAC)
                                            : const Color(0xFFFDBA74);
                                        final textCol = isConcluida
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFFC2410C);
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: bg,
                                            borderRadius:
                                                BorderRadius.circular(TFRadius.r8),
                                            border: Border.all(color: border),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.settings_suggest_outlined,
                                                size: 12,
                                                color: textCol,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Sis: ${_notaAtual.statusSistema!.trim()}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: textCol,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                    if (_notaAtual.statusUsuario != null &&
                                        _notaAtual.statusUsuario!.trim().isNotEmpty) ...[
                                      SizedBox(width: spacing.xs),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F3FF),
                                          borderRadius:
                                              BorderRadius.circular(TFRadius.r8),
                                          border: Border.all(
                                              color: const Color(0xFFDDD6FE)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.person_outline_rounded,
                                              size: 12,
                                              color: Color(0xFF6D28D9),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Usu: ${_notaAtual.statusUsuario!.trim()}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF6D28D9),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (widget.readOnly) ...[
                                      SizedBox(width: spacing.xs),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey.withAlpha(30),
                                          borderRadius:
                                              BorderRadius.circular(TFRadius.r8),
                                          border: Border.all(
                                              color: Colors.blueGrey.withAlpha(100)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.visibility_outlined,
                                                size: 12, color: Colors.blueGrey),
                                            SizedBox(width: spacing.xs),
                                            const Text(
                                              'Modo Consulta',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.blueGrey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                if (temDescricao) ...[
                                  Tooltip(
                                    message: _buildTextoCompletoNota(),
                                    waitDuration: const Duration(milliseconds: 500),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          if (prefixoLocalSala.isNotEmpty) ...[
                                            TextSpan(
                                              text: prefixoLocalSala,
                                              style: typography.bodyMedium.copyWith(
                                                color: colors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (_notaAtual.descricao != null &&
                                                _notaAtual.descricao!.trim().isNotEmpty)
                                              TextSpan(
                                                text: ' — ',
                                                style: typography.bodyMedium.copyWith(
                                                  color: colors.textSecondary,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                          ],
                                          if (_notaAtual.descricao != null &&
                                              _notaAtual.descricao!.trim().isNotEmpty)
                                            TextSpan(
                                              text: _notaAtual.descricao!.trim(),
                                              style: typography.bodyMedium.copyWith(
                                                color: colors.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Text(
                                  '${_notaAtual.localInstalacao ?? _notaAtual.local ?? 'Local não inf.'}${_notaAtual.sala != null && _notaAtual.sala!.trim().isNotEmpty ? ' • Sala: ${_notaAtual.sala!.trim()}' : ''} • ${_notaAtual.equipamento ?? 'Sem equip.'} • Prioridade: ${_notaAtual.textPrioridade ?? 'Normal'}${_notaAtual.statusSistema != null && _notaAtual.statusSistema!.trim().isNotEmpty ? ' • Sis: ${_notaAtual.statusSistema!.trim()}' : ''}${_notaAtual.statusUsuario != null && _notaAtual.statusUsuario!.trim().isNotEmpty ? ' • Usu: ${_notaAtual.statusUsuario!.trim()}' : ''}${_buildInfoDataCabecalho()}',
                                  style: typography.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (_temNavegacao) ...[
                            _buildNavegacaoNotas(colors, typography),
                            const SizedBox(width: 4),
                          ],
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Fechar',
                            color: colors.textSecondary,
                            onPressed: () async {
                              final podeFechar = await _tentarFechar();
                              if (podeFechar && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: colors.primary,
                      unselectedLabelColor: colors.textSecondary,
                      indicatorColor: colors.primary,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.description_outlined, size: 18),
                          text: 'Visão Geral',
                        ),
                        Tab(
                          icon: Icon(Icons.psychology_outlined, size: 18),
                          text: 'Análise Técnica',
                        ),
                        Tab(
                          icon: Icon(Icons.inventory_2_outlined, size: 18),
                          text: 'Materiais',
                        ),
                        Tab(
                          icon: Icon(Icons.attach_file_outlined, size: 18),
                          text: 'Anexos',
                        ),
                        Tab(
                          icon: Icon(Icons.forum_outlined, size: 18),
                          text: 'Discussão Técnica',
                        ),
                        Tab(
                          icon: Icon(Icons.history_edu_outlined, size: 18),
                          text: 'Similaridade & Histórico',
                        ),
                        Tab(
                          icon: Icon(Icons.hub_outlined, size: 18),
                          text: 'Vínculo & Previsão',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildPainelObservacoesPersistente(colors, typography, spacing),
              _buildBarraDeTagsPersistente(colors, typography),
              Expanded(
                child: TabBarView(
                    controller: _tabController,
                    children: [
                      NotaWorkspaceOverviewTab(
                        key: ValueKey('tab_overview_${_notaAtual.id}'),
                        nota: _notaAtual,
                        onTagsChanged: () {
                          _carregarTags();
                          widget.onNotaMudou?.call(_notaAtual);
                        },
                      ),
                NotaWorkspaceAnalysisTab(
                  key: _analysisTabKey,
                  analiseInicial: _analise,
                  notaSapId: _notaAtual.id,
                  nota: _notaAtual,
                  isReadOnly: widget.readOnly,
                  service: _service,
                  isLoading: _isLoadingAnalise,
                  isSaving: _isSavingAnalise,
                  onAbrirNotaHistorica: widget.readOnly
                      ? null
                      : (notaHistorica) {
                          NotaAnaliseWorkspace.abrir(
                            context,
                            nota: notaHistorica,
                            readOnly: true,
                          );
                        },
                  onDirtyChanged: (dirty) {
                    if (mounted) setState(() => _hasUnsavedChanges = dirty);
                  },
                  onSalvar: (a) => _salvarAnalise(),
                ),
                NotaWorkspaceMaterialsTab(
                  key: ValueKey('tab_materials_${_notaAtual.id}'),
                  notaSapId: _notaAtual.id,
                  analiseId: _analise?.id,
                  service: _service,
                ),
                NotaWorkspaceAttachmentsTab(
                  key: ValueKey('tab_attachments_${_notaAtual.id}'),
                  notaSapId: _notaAtual.id,
                  service: _service,
                  nota: _notaAtual,
                  onAbrirNotaHistorica: widget.readOnly
                      ? null
                      : (notaHistorica) {
                          NotaAnaliseWorkspace.abrir(
                            context,
                            nota: notaHistorica,
                            readOnly: true,
                          );
                        },
                ),
                NotaWorkspaceDiscussionTab(
                  key: ValueKey('tab_discussion_${_notaAtual.id}'),
                  notaSapId: _notaAtual.id,
                  service: _service,
                ),
                NotaSapSimilaridadePanel(
                  key: ValueKey('tab_similarity_${_notaAtual.id}'),
                  nota: _notaAtual,
                  onAbrirNotaHistorica: widget.readOnly
                      ? null
                      : (notaHistorica) {
                          NotaAnaliseWorkspace.abrir(
                            context,
                            nota: notaHistorica,
                            readOnly: true,
                          );
                        },
                ),
                NotaWorkspaceGruposTab(
                  key: ValueKey('tab_grupos_${_notaAtual.id}'),
                  nota: _notaAtual,
                ),
              ],
            ),
          ),
        ],
      ),
            bottomNavigationBar: Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: spacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.borderSubtle)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 850;
                  final showStatusText = constraints.maxWidth >= 800;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (showStatusText)
                        Expanded(
                          child: _hasUnsavedChanges
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        size: 16, color: Colors.amber.shade800),
                                    SizedBox(width: spacing.xs),
                                    Flexible(
                                      child: Text(
                                        'Alterações não salvas na análise',
                                        overflow: TextOverflow.ellipsis,
                                        style: typography.caption.copyWith(
                                          color: Colors.amber.shade900,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  widget.readOnly
                                      ? 'Consulta Técnica • Apenas visualização de dados'
                                      : 'TaskFlow • Análise Prévia SAP',
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.caption.copyWith(
                                    color: colors.textSecondary.withAlpha(180),
                                  ),
                                ),
                        ),
                      if (!widget.readOnly) ...[
                        Flexible(
                          fit: FlexFit.loose,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_notasSelecionadas.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withAlpha(20),
                                      borderRadius:
                                          BorderRadius.circular(TFRadius.r8),
                                      border: Border.all(
                                          color: colors.primary.withAlpha(80)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle,
                                            size: 16, color: colors.primary),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${_notasSelecionadas.length} selecionada${_notasSelecionadas.length > 1 ? 's' : ''}',
                                          style: typography.caption.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                              TFRadius.rFull),
                                          onTap: _limparSelecaoNotas,
                                          child: Padding(
                                            padding: const EdgeInsets.all(2),
                                            child: Icon(Icons.close,
                                                size: 14,
                                                color: colors.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: spacing.xs),
                                ],
                                if (_tabController.index == 1 ||
                                    _hasUnsavedChanges) ...[
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: colors.primary,
                                      side: BorderSide(
                                        color: _hasUnsavedChanges
                                            ? colors.primary
                                            : colors.borderSubtle,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal:
                                            isCompact ? spacing.sm : spacing.md,
                                        vertical: spacing.sm,
                                      ),
                                    ),
                                    icon: _isSavingAnalise
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.save_outlined,
                                            size: 16),
                                    label: const Text('Salvar Análise'),
                                    onPressed: _isSavingAnalise
                                        ? null
                                        : () => _salvarAnalise(),
                                  ),
                                  SizedBox(width: spacing.sm),
                                ],
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _notaAtualEstaSelecionada
                                        ? colors.primary
                                        : colors.textPrimary,
                                    backgroundColor: _notaAtualEstaSelecionada
                                        ? colors.primary.withAlpha(25)
                                        : Colors.transparent,
                                    side: BorderSide(
                                      color: _notaAtualEstaSelecionada
                                          ? colors.primary
                                          : colors.borderSubtle,
                                      width: _notaAtualEstaSelecionada
                                          ? 1.5
                                          : 1.0,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          isCompact ? spacing.sm : spacing.md,
                                      vertical: spacing.sm,
                                    ),
                                  ),
                                  icon: Icon(
                                    _notaAtualEstaSelecionada
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    size: 18,
                                    color: _notaAtualEstaSelecionada
                                        ? colors.primary
                                        : colors.textSecondary,
                                  ),
                                  label: Text(
                                    _notaAtualEstaSelecionada
                                        ? 'Selecionada'
                                        : 'Selecionar',
                                    style: TextStyle(
                                      fontWeight: _notaAtualEstaSelecionada
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  onPressed: _alternarSelecaoNotaAtual,
                                ),
                                SizedBox(width: spacing.xs),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.primary,
                                    foregroundColor: colors.primaryForeground,
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          isCompact ? spacing.md : spacing.lg,
                                      vertical: spacing.sm,
                                    ),
                                  ),
                                  icon: const Icon(Icons.event_available,
                                      size: 18),
                                  label: Text(
                                    _notasSelecionadas.length > 1
                                        ? 'Programar Tarefas (${_notasSelecionadas.length})'
                                        : 'Programar Tarefa',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _aoClicarProgramar,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.primaryForeground,
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing.md,
                              vertical: spacing.sm,
                            ),
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Fechar'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GESTÃO PERSISTENTE DE TAGS EM TODAS AS ABAS DO WORKSPACE
  // ---------------------------------------------------------------------------

  Future<void> _carregarTags() async {
    if (!mounted) return;
    setState(() => _carregandoTags = true);
    try {
      final tags = await _tagService.listarTagsDaNota(_notaAtual.id);
      if (mounted) {
        setState(() {
          _tagsDaNota = tags;
          _carregandoTags = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _carregandoTags = false);
    }
  }

  Future<void> _adicionarTag() async {
    final tagEscolhida = await NotaSapTagSelectorDialog.show(
      context,
      notaSapId: _notaAtual.id,
      tagsAtuaisDaNota: _tagsDaNota,
      tagService: _tagService,
    );

    if (!mounted || tagEscolhida == null || tagEscolhida.id == null) return;

    final user = AuthServiceSimples().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum usuário logado para vincular a tag.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _tagService.vincularTag(
        notaSapId: _notaAtual.id,
        tagId: tagEscolhida.id!,
        usuario: user,
      );

      await _carregarTags();
      widget.onNotaMudou?.call(_notaAtual);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag "${tagEscolhida.nome}" vinculada à nota.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao vincular tag: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removerTag(NotaSapTag tag) async {
    if (tag.id == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Tag'),
        content: Text('Deseja desvincular a tag "${tag.nome}" desta nota?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _tagService.desvincularTag(
        notaSapId: _notaAtual.id,
        tagId: tag.id!,
      );

      await _carregarTags();
      widget.onNotaMudou?.call(_notaAtual);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag "${tag.nome}" removida da nota.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover tag: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _corDaTag(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blueGrey;
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('0xFF$cleaned'));
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  Widget _buildPainelObservacoesPersistente(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    final detalhes = _notaAtual.detalhes?.trim();
    final temDetalhes = detalhes != null && detalhes.isNotEmpty;
    final textoExibicao = temDetalhes
        ? detalhes
        : 'Nenhuma observação detalhada cadastrada para esta nota no SAP.';
    final possuiTexto = temDetalhes;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        border: Border(
          bottom: BorderSide(color: colors.borderSubtle, width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'Descrição Detalhada / Observações SAP',
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                  fontSize: 12.0,
                ),
              ),
              const Spacer(),
              if (possuiTexto)
                IconButton(
                  icon: Icon(Icons.copy, size: 14, color: colors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Copiar texto das observações',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: textoExibicao));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Descrição/observação SAP copiada!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 110,
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                textoExibicao,
                style: typography.bodySmall.copyWith(
                  color: possuiTexto
                      ? colors.textPrimary
                      : colors.textMuted,
                  fontStyle: possuiTexto ? FontStyle.normal : FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraDeTagsPersistente(dynamic colors, dynamic typography) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.label_outlined, size: 16, color: colors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Tags:',
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_carregandoTags) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!_carregandoTags && _tagsDaNota.isEmpty) ...[
                    Text(
                      'Nenhuma tag vinculada a esta nota',
                      style: typography.caption.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colors.textSecondary.withAlpha(180),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ..._tagsDaNota.map((tag) {
                    final cor = _corDaTag(tag.cor);
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cor.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cor.withAlpha(90)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tag.nome,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cor.computeLuminance() > 0.6
                                  ? Colors.black87
                                  : cor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag.escopoTipo.descricao,
                              style: TextStyle(
                                fontSize: 9,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          if (!widget.readOnly) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _removerTag(tag),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close,
                                  size: 13,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  if (!widget.readOnly)
                    InkWell(
                      onTap: _adicionarTag,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.primary.withAlpha(80),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: colors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Adicionar Tag',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
