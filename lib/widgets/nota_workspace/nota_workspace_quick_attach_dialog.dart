import 'package:flutter/material.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/nota_sap_analise_evidencia.dart';
import '../../models/nota_historico_visual.dart';
import '../../services/nota_sap_analise_service.dart';
import '../../services/nota_historico_visual_service.dart';
import '../../features/media_albums/data/repositories/supabase_media_repository.dart';

/// Diálogo e BottomSheet de Quick Attach de Evidências (Fase 4C)
/// Permite vincular Anexos da Nota e Fotos do Álbum de Campo em um único fluxo ágil.
class NotaWorkspaceQuickAttachDialog extends StatefulWidget {
  final String notaSapId;
  final NotaSAP nota;
  final NotaTipoVinculoEvidencia secaoInicial;
  final NotaSapAnaliseService service;
  final NotaHistoricoVisualService? historicoService;
  final VoidCallback onVinculoConcluido;

  const NotaWorkspaceQuickAttachDialog({
    super.key,
    required this.notaSapId,
    required this.nota,
    required this.secaoInicial,
    required this.service,
    this.historicoService,
    required this.onVinculoConcluido,
  });

  /// Abre o Quick Attach de forma responsiva:
  /// - Mobile (< 800px): ModalBottomSheet
  /// - Desktop (>= 800px): Dialog amplo centralizado
  static Future<void> abrir(
    BuildContext context, {
    required String notaSapId,
    required NotaSAP nota,
    required NotaTipoVinculoEvidencia secaoInicial,
    required NotaSapAnaliseService service,
    NotaHistoricoVisualService? historicoService,
    required VoidCallback onVinculoConcluido,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
            child: NotaWorkspaceQuickAttachDialog(
              notaSapId: notaSapId,
              nota: nota,
              secaoInicial: secaoInicial,
              service: service,
              historicoService: historicoService,
              onVinculoConcluido: onVinculoConcluido,
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.88,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: NotaWorkspaceQuickAttachDialog(
              notaSapId: notaSapId,
              nota: nota,
              secaoInicial: secaoInicial,
              service: service,
              historicoService: historicoService,
              onVinculoConcluido: onVinculoConcluido,
            ),
          ),
        ),
      );
    }
  }

  @override
  State<NotaWorkspaceQuickAttachDialog> createState() =>
      _NotaWorkspaceQuickAttachDialogState();
}

class _NotaWorkspaceQuickAttachDialogState
    extends State<NotaWorkspaceQuickAttachDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late NotaTipoVinculoEvidencia _secaoDestino;
  final TextEditingController _observacaoController = TextEditingController();

  late final NotaHistoricoVisualService _historicoService;

  // Estado de dados
  bool _isLoading = true;
  String? _erro;

  List<NotaSapAnexo> _anexosOriginais = [];
  HistoricoVisualResultado? _historicoResultado;

  // Seleção atual
  NotaSapAnexo? _anexoSelecionado;
  HistoricoVisualItem? _fotoAlbumSelecionada;

  bool _isSalvandoVinculo = false;

  @override
  void initState() {
    super.initState();
    _secaoDestino = widget.secaoInicial;
    _historicoService = widget.historicoService ?? NotaHistoricoVisualService();
    _tabController = TabController(length: 2, vsync: this);
    _carregarFontes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  Future<void> _carregarFontes() async {
    setState(() {
      _isLoading = true;
      _erro = null;
    });

    try {
      final anexos = await widget.service.listarAnexos(widget.notaSapId);
      if (!mounted) return;

      setState(() {
        _anexosOriginais = anexos.where((a) => !a.isDerivado).toList();
        _isLoading = false;
      });

      _carregarHistoricoSilencioso();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Erro ao carregar anexos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _carregarHistoricoSilencioso() async {
    try {
      final histRes = await _historicoService.buscarHistoricoVisual(widget.nota);
      if (mounted) {
        setState(() => _historicoResultado = histRes);
      }
    } catch (_) {
      // Indisponibilidade temporária de fotos do álbum não impede anexos da nota
    }
  }

  String? _obterUrlFotoItem(HistoricoVisualItem item) {
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return item.imageUrl;
    }
    try {
      return SupabaseMediaRepository().getPublicUrl(item.mediaImage.filePath);
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmarVinculo() async {
    final isAnexo = _tabController.index == 0;
    if (isAnexo && _anexoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um anexo da lista')),
      );
      return;
    }
    if (!isAnexo && _fotoAlbumSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma fotografia do histórico')),
      );
      return;
    }

    setState(() => _isSalvandoVinculo = true);

    try {
      final obs = _observacaoController.text.trim().isNotEmpty
          ? _observacaoController.text.trim()
          : null;

      if (isAnexo) {
        final anx = _anexoSelecionado!;
        await widget.service.vincularEvidencia(
          notaSapId: widget.notaSapId,
          anexoId: anx.id!,
          tipoFonte: NotaEvidenciaTipoFonte.anexoNota,
          tipoVinculo: _secaoDestino,
          anotacaoVersao: anx.versaoAnotacao > 0 ? anx.versaoAnotacao : null,
          observacao: obs,
        );
      } else {
        final foto = _fotoAlbumSelecionada!;
        await widget.service.vincularEvidencia(
          notaSapId: widget.notaSapId,
          mediaImageId: foto.id,
          tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
          tipoVinculo: _secaoDestino,
          observacao: obs,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Evidência vinculada à seção ${_secaoDestino.labelCurto} com sucesso!',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      widget.onVinculoConcluido();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSalvandoVinculo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao vincular evidência: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vincular Evidência à Análise',
              style: typography.sectionTitle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            Text(
              'Adicione um anexo original ou foto de campo para sustentar seu parecer técnico',
              style: typography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Fechar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.borderSubtle)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: colors.primary,
              unselectedLabelColor: colors.textSecondary,
              indicatorColor: colors.primary,
              tabs: [
                Tab(
                  icon: const Icon(Icons.attachment, size: 16),
                  text: 'Anexos da Nota (${_anexosOriginais.length})',
                ),
                Tab(
                  icon: const Icon(Icons.photo_library, size: 16),
                  text: 'Álbum de Campo (${_historicoResultado?.totalGlobal ?? 0})',
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _erro!,
                      style: TextStyle(color: Colors.red.shade700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Configuração de Seção e Observação
                    _buildConfiguracaoSecaoEObservacao(colors, typography, spacing),
                    Divider(height: 1, color: colors.borderSubtle),
                    // Lista de Seleção por Aba
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildListaAnexos(colors, typography, spacing),
                          _buildListaHistoricoAlbum(colors, typography, spacing),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(spacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.borderSubtle)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _tabController.index == 0
                    ? (_anexoSelecionado != null
                        ? 'Selecionado: ${_anexoSelecionado!.nomeExibicao}'
                        : 'Nenhum anexo selecionado')
                    : (_fotoAlbumSelecionada != null
                        ? 'Selecionada: ${_fotoAlbumSelecionada!.title}'
                        : 'Nenhuma fotografia selecionada'),
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: _isSalvandoVinculo ? null : _confirmarVinculo,
              icon: _isSalvandoVinculo
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.link, size: 16),
              label: Text(
                _isSalvandoVinculo
                    ? 'Vinculando...'
                    : 'Vincular Evidência',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfiguracaoSecaoEObservacao(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      color: colors.surfaceSecondary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dropdown de Seção
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seção de Destino',
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<NotaTipoVinculoEvidencia>(
                    value: _secaoDestino,
                    isDense: true,
                    style: typography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: NotaTipoVinculoEvidencia.values.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(s.label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _secaoDestino = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Observação Contextual
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Observação Analítica (Opcional)',
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _observacaoController,
                    style: typography.bodyMedium.copyWith(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ex: Comprova avaria identificada na inspeção prévia...',
                      hintStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(TFRadius.r8),
                        borderSide: BorderSide(color: colors.borderSubtle),
                      ),
                      filled: true,
                      fillColor: colors.surface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaAnexos(dynamic colors, dynamic typography, dynamic spacing) {
    if (_anexosOriginais.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open, size: 48, color: colors.textSecondary.withAlpha(100)),
              const SizedBox(height: 8),
              Text(
                'Nenhum anexo original encontrado nesta Nota SAP',
                style: typography.bodyMedium.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(spacing.md),
      itemCount: _anexosOriginais.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final anx = _anexosOriginais[index];
        final isSelected = _anexoSelecionado?.id == anx.id;

        return InkWell(
          borderRadius: BorderRadius.circular(TFRadius.r8),
          onTap: () {
            setState(() {
              _anexoSelecionado = anx;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? colors.primary.withAlpha(20) : colors.surface,
              borderRadius: BorderRadius.circular(TFRadius.r8),
              border: Border.all(
                color: isSelected ? colors.primary : colors.borderSubtle,
                width: isSelected ? 1.6 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  anx.tipoArquivo == NotaAnexoTipo.imagem
                      ? Icons.image
                      : Icons.description,
                  color: isSelected ? colors.primary : colors.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anx.nomeExibicao,
                        style: typography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Origem: ${anx.origem} • ${anx.tamanhoFormatado}',
                        style: typography.caption.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (anx.possuiAnotacao) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.teal.shade300, width: 0.8),
                    ),
                    child: Text(
                      'v${anx.versaoAnotacao}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? colors.primary : colors.textSecondary.withAlpha(120),
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getNivelColor(HistoricoVisualNivel nivel) {
    switch (nivel) {
      case HistoricoVisualNivel.equipamento:
        return Colors.teal;
      case HistoricoVisualNivel.sala:
        return Colors.blue;
      case HistoricoVisualNivel.local:
        return Colors.orange;
    }
  }

  Widget _buildListaHistoricoAlbum(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    final fotos = _historicoResultado?.itens ?? [];

    if (fotos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 48, color: colors.textSecondary.withAlpha(100)),
              const SizedBox(height: 8),
              Text(
                'Nenhuma fotografia histórica encontrada nos Álbuns de Campo para este local',
                style: typography.bodyMedium.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(spacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: fotos.length,
      itemBuilder: (context, index) {
        final item = fotos[index];
        final isSelected = _fotoAlbumSelecionada?.id == item.id;
        final url = _obterUrlFotoItem(item) ?? '';
        final nivelColor = _getNivelColor(item.nivel);

        return InkWell(
          borderRadius: BorderRadius.circular(TFRadius.r8),
          onTap: () {
            setState(() {
              _fotoAlbumSelecionada = item;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? colors.primary.withAlpha(20) : colors.surface,
              borderRadius: BorderRadius.circular(TFRadius.r8),
              border: Border.all(
                color: isSelected ? colors.primary : colors.borderSubtle,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.broken_image,
                            size: 28, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: nivelColor.withAlpha(40),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: nivelColor.withAlpha(120),
                                  width: 0.6),
                            ),
                            child: Text(
                              item.nivel.badgeText,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: nivelColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item.dataFormatada,
                            style: TextStyle(fontSize: 10, color: colors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        style: typography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
