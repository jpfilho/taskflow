import 'package:flutter/material.dart';
import '../../design_system/theme/taskflow_theme_extension.dart';
import '../../design_system/foundations/tf_radius.dart';
import '../../models/nota_sap.dart';
import '../../models/nota_sap_analise.dart';
import '../../models/nota_historico_visual.dart';
import '../../models/nota_sap_analise_evidencia.dart';
import '../../services/nota_historico_visual_service.dart';
import '../../services/nota_sap_analise_service.dart';
import '../../features/media_albums/presentation/pages/gallery_page.dart';
import 'nota_historico_visual_viewer_dialog.dart';

/// Seção visual de Histórico Visual dos Álbuns com capacidade de seleção explícita
/// para utilização como evidência na Análise Técnica da Nota SAP.
class NotaWorkspaceHistoricoVisualSection extends StatefulWidget {
  final NotaSAP nota;
  final List<NotaSapAnexo>? anexosAtuais;
  final NotaHistoricoVisualService? service;
  final NotaSapAnaliseService? analiseService;
  final VoidCallback? onEvidenciasAlteradas;
  final EdgeInsetsGeometry? customMargin;

  const NotaWorkspaceHistoricoVisualSection({
    super.key,
    required this.nota,
    this.anexosAtuais,
    this.service,
    this.analiseService,
    this.onEvidenciasAlteradas,
    this.customMargin,
  });

  @override
  State<NotaWorkspaceHistoricoVisualSection> createState() =>
      _NotaWorkspaceHistoricoVisualSectionState();
}

class _NotaWorkspaceHistoricoVisualSectionState
    extends State<NotaWorkspaceHistoricoVisualSection> {
  late final NotaHistoricoVisualService _service;
  late final NotaSapAnaliseService _analiseService;

  bool _carregando = true;
  String? _erro;
  HistoricoVisualResultado? _resultado;

  HistoricoVisualNivel? _filtroNivel; // null = Todos
  bool _mostrarNivelC = false;

  // Mapa de seções onde cada foto do álbum já está vinculada
  Map<String, List<NotaTipoVinculoEvidencia>> _secoesVinculadasPorFoto = {};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotaHistoricoVisualService();
    _analiseService = widget.analiseService ?? NotaSapAnaliseService();
    _carregarHistorico();
  }

  @override
  void didUpdateWidget(covariant NotaWorkspaceHistoricoVisualSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nota.id != widget.nota.id ||
        oldWidget.nota.localInstalacao != widget.nota.localInstalacao ||
        oldWidget.nota.sala != widget.nota.sala ||
        oldWidget.nota.equipamento != widget.nota.equipamento) {
      _carregarHistorico();
    }
  }

  Future<void> _carregarHistorico() async {
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final resFuture = _service.buscarHistoricoVisual(widget.nota);
      final usosFuture = _analiseService.buscarUsoDasFotosDoAlbum(widget.nota.id);

      final results = await Future.wait([resFuture, usosFuture]);
      final res = results[0] as HistoricoVisualResultado;
      final usos = results[1] as Map<String, List<NotaTipoVinculoEvidencia>>;

      if (!mounted) return;
      setState(() {
        _resultado = res;
        _secoesVinculadasPorFoto = usos;
        _carregando = false;
        // Se só houver fotos de Nível C, expande por padrão
        _mostrarNivelC = !res.temCorrespondenciaEspecifica;
      });
    } catch (e, stack) {
      debugPrint('⚠️ [NotaWorkspaceHistoricoVisualSection._carregarHistorico] Erro: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar o histórico visual.';
        _carregando = false;
      });
    }
  }

  /// Diálogo modal responsivo para o usuário selecionar explicitamente
  /// em quais seções técnicas da Análise esta fotografia histórica será vinculada
  Future<void> _abrirModalVincularFoto(HistoricoVisualItem item) async {
    final photoId = item.mediaImage.id;
    final secoesAtuais = _secoesVinculadasPorFoto[photoId] ?? [];
    final secoesSelecionadas = Set<NotaTipoVinculoEvidencia>.from(secoesAtuais);
    final obsController = TextEditingController();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TFRadius.r16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.add_link_rounded, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Usar Fotografia na Análise Técnica',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho da foto
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(TFRadius.r8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: item.imageUrl != null
                                  ? Image.network(
                                      item.imageUrl!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.image, size: 24),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.dataFormatada} • ${item.motivoCorrespondencia}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Onde esta foto será utilizada como evidência?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      // Checkboxes de seções técnicas
                      ...NotaTipoVinculoEvidencia.values.map((secao) {
                        final marcada = secoesSelecionadas.contains(secao);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            secao.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  marcada ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          value: marcada,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                secoesSelecionadas.add(secao);
                              } else {
                                secoesSelecionadas.remove(secao);
                              }
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 12),
                      const Text(
                        'Observação analítica (opcional):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: obsController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText:
                              'Ex: Foto de março/2025 comprova corrosão na base da torre...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Salvar Vínculos'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmou != true) return;

    try {
      // 1. Desvincular seções que foram desmarcadas
      final paraRemover =
          secoesAtuais.where((s) => !secoesSelecionadas.contains(s)).toList();
      for (final secao in paraRemover) {
        await _analiseService.desvincularEvidencia(
          notaSapId: widget.nota.id,
          tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
          mediaImageId: photoId,
          tipoVinculo: secao,
        );
      }

      // 2. Vincular seções marcadas
      final obs = obsController.text.trim().isEmpty
          ? null
          : obsController.text.trim();
      for (final secao in secoesSelecionadas) {
        await _analiseService.vincularEvidencia(
          notaSapId: widget.nota.id,
          tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
          mediaImageId: photoId,
          tipoVinculo: secao,
          observacao: obs,
        );
      }

      // 3. Recarregar os vínculos desta foto
      final novosUsos =
          await _analiseService.buscarUsoDasFotosDoAlbum(widget.nota.id);
      if (mounted) {
        setState(() {
          _secoesVinculadasPorFoto = novosUsos;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vínculos da fotografia na análise atualizados com sucesso.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      widget.onEvidenciasAlteradas?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar vínculos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirNoModuloDeAlbuns() {
    // Tenta obter o localId da primeira foto correspondente
    String? localId;
    String? roomId;

    if (_resultado != null && _resultado!.itens.isNotEmpty) {
      final primeiro = _resultado!.itens.first;
      localId = primeiro.mediaImage.localId;
      if (primeiro.nivel == HistoricoVisualNivel.sala) {
        roomId = primeiro.mediaImage.roomId;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MediaAlbumsGalleryPage(
          initialLocalId: localId,
          initialRoomId: roomId,
        ),
      ),
    );
  }

  void _abrirViewerFoto(HistoricoVisualItem item, [List<HistoricoVisualItem>? listaVisivel]) {
    final colecao = listaVisivel ?? _resultado?.itens ?? [item];
    final idx = colecao.indexOf(item);

    NotaHistoricoVisualViewerDialog.abrir(
      context: context,
      itens: colecao,
      indiceInicial: idx >= 0 ? idx : 0,
      secoesVinculadasPorFoto: _secoesVinculadasPorFoto,
      onVincularFoto: (fotoItem) => _abrirModalVincularFoto(fotoItem),
      notaAtual: widget.nota,
      anexosAtuais: widget.anexosAtuais,
      analiseService: _analiseService,
    );
  }

  Widget _buildBadgeNivel(HistoricoVisualNivel nivel) {
    Color bg;
    Color fg;
    IconData icon;

    switch (nivel) {
      case HistoricoVisualNivel.equipamento:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.precision_manufacturing_rounded;
        break;
      case HistoricoVisualNivel.sala:
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        icon = Icons.apartment_rounded;
        break;
      case HistoricoVisualNivel.local:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        icon = Icons.location_on_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: fg.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            nivel.badgeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
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

    return Container(
      margin: widget.customMargin ?? const EdgeInsets.only(top: 24, bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho da Seção de Histórico Visual
          _buildCabecalho(colors, typography),

          if (_carregando)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5),
                    SizedBox(height: 12),
                    Text(
                      'Consultando histórico visual nos Álbuns...',
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
            )
          else if (_erro != null)
            _buildEstadoErro(colors, typography)
          else if (_resultado == null || !_resultado!.temFotos)
            _buildEstadoVazio(colors, typography)
          else
            _buildConteudoResultado(colors, typography),
        ],
      ),
    );
  }

  Widget _buildCabecalho(dynamic colors, dynamic typography) {
    final res = _resultado;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(TFRadius.r12)),
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(TFRadius.r8),
                  ),
                  child: Icon(Icons.history_rounded, size: 20, color: colors.primary),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Histórico Visual do Local',
                            style: typography.sectionTitle.copyWith(
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withAlpha(20),
                              borderRadius: BorderRadius.circular(TFRadius.r4),
                            ),
                            child: const Text(
                              'SOMENTE LEITURA',
                              style: TextStyle(
                                fontSize: 10.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(TFRadius.r8),
                              border: Border.all(color: colors.primary.withAlpha(60)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_outlined, size: 12, color: colors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  res?.localNome ?? widget.nota.local ?? widget.nota.localInstalacao ?? 'Local',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (res?.salaNome != null || (widget.nota.sala != null && widget.nota.sala!.trim().isNotEmpty))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0).withAlpha(20),
                                borderRadius: BorderRadius.circular(TFRadius.r8),
                                border: Border.all(color: const Color(0xFF1565C0).withAlpha(60)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.meeting_room_outlined, size: 12, color: Color(0xFF1565C0)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Sala: ${res?.salaNome ?? widget.nota.sala}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1565C0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fotografias de inspeções catalogadas nos Álbuns para o mesmo local e sala desta Nota.',
                        style: typography.caption.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (res != null && res.temFotos)
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: const Text('Abrir no Módulo de Álbuns'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary.withAlpha(120)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TFRadius.r8)),
              ),
              onPressed: _abrirNoModuloDeAlbuns,
            ),
        ],
      ),
    );
  }

  Widget _buildEstadoVazio(dynamic colors, dynamic typography) {
    final res = _resultado;
    final nomeLocal = res?.localNome ?? widget.nota.local ?? widget.nota.localInstalacao ?? 'este local';
    final nomeSala = res?.salaNome ?? widget.nota.sala;
    final temSala = nomeSala != null && nomeSala.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.photo_library_outlined, size: 48, color: colors.textSecondary.withAlpha(80)),
            const SizedBox(height: 12),
            Text(
              temSala
                  ? 'Nenhuma fotografia encontrada para o local "$nomeLocal" e sala "$nomeSala".'
                  : 'Nenhuma fotografia encontrada para o local "$nomeLocal".',
              style: typography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              temSala
                  ? 'Fotografias de campo cadastradas no módulo de Álbuns para esta sala e local aparecerão aqui automaticamente.'
                  : 'Fotografias de campo cadastradas no módulo de Álbuns para este local aparecerão aqui automaticamente.',
              style: typography.caption.copyWith(color: colors.textSecondary.withAlpha(150)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoErro(dynamic colors, dynamic typography) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.warning_amber_rounded, size: 40, color: colors.warning),
            const SizedBox(height: 8),
            Text(
              _erro ?? 'Erro ao consultar histórico visual.',
              style: typography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TFRadius.r8)),
              ),
              onPressed: _carregarHistorico,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudoResultado(dynamic colors, dynamic typography) {
    final res = _resultado!;

    // Filtragem por Nível se selecionado
    List<HistoricoVisualItem> itensExibicao = res.itens;
    if (_filtroNivel != null) {
      itensExibicao = itensExibicao.where((i) => i.nivel == _filtroNivel).toList();
    } else {
      // Se não houver filtro ativo e Nível C estiver recolhido, oculta Nível C
      if (!_mostrarNivelC && res.temCorrespondenciaEspecifica) {
        itensExibicao = itensExibicao.where((i) => i.nivel != HistoricoVisualNivel.local).toList();
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de Contadores e Filtros
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              // Contadores por Nível
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildChipContador(
                    label: 'Todos',
                    count: res.totalGlobal,
                    selecionado: _filtroNivel == null,
                    onTap: () => setState(() => _filtroNivel = null),
                  ),
                  if (res.totalEquipamento > 0)
                    _buildChipContador(
                      label: 'Equipamento',
                      count: res.totalEquipamento,
                      cor: const Color(0xFF2E7D32),
                      selecionado: _filtroNivel == HistoricoVisualNivel.equipamento,
                      onTap: () => setState(() => _filtroNivel = HistoricoVisualNivel.equipamento),
                    ),
                  if (res.totalSala > 0)
                    _buildChipContador(
                      label: 'Sala / Estrutura',
                      count: res.totalSala,
                      cor: const Color(0xFF1565C0),
                      selecionado: _filtroNivel == HistoricoVisualNivel.sala,
                      onTap: () => setState(() => _filtroNivel = HistoricoVisualNivel.sala),
                    ),
                  if (res.totalLocal > 0)
                    _buildChipContador(
                      label: 'Mesmo Local',
                      count: res.totalLocal,
                      cor: const Color(0xFFE65100),
                      selecionado: _filtroNivel == HistoricoVisualNivel.local,
                      onTap: () => setState(() {
                        _filtroNivel = HistoricoVisualNivel.local;
                        _mostrarNivelC = true;
                      }),
                    ),
                ],
              ),
              // Botão para alternar fotos gerais do mesmo local (quando houver A ou B)
              if (res.temCorrespondenciaEspecifica && res.totalLocal > 0 && _filtroNivel == null)
                TextButton.icon(
                  icon: Icon(
                    _mostrarNivelC ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(
                    _mostrarNivelC
                        ? 'Ocultar fotos amplas do local'
                        : 'Ver +${res.totalLocal} fotos do mesmo local',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => setState(() => _mostrarNivelC = !_mostrarNivelC),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Grade de Cards das Fotografias
          if (itensExibicao.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nenhuma foto encontrada para o filtro selecionado.',
                  style: typography.caption.copyWith(color: colors.textSecondary),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (ctx, constraints) {
                final crossCount = constraints.maxWidth < 600
                    ? 1
                    : constraints.maxWidth < 900
                        ? 2
                        : constraints.maxWidth < 1200
                            ? 3
                            : 4;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: itensExibicao.length,
                  itemBuilder: (ctx, index) {
                    final item = itensExibicao[index];
                    return _buildCardFoto(item, colors, typography, itensExibicao);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildChipContador({
    required String label,
    required int count,
    Color? cor,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    final corBase = cor ?? const Color(0xFF455A64);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TFRadius.r8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selecionado ? corBase.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(TFRadius.r8),
          border: Border.all(
            color: selecionado ? corBase : Colors.grey.shade300,
            width: selecionado ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                color: selecionado ? corBase : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selecionado ? corBase : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: selecionado ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFoto(
    HistoricoVisualItem item,
    dynamic colors,
    dynamic typography, [
    List<HistoricoVisualItem>? listaVisivel,
  ]) {
    final secoesVinculadas = _secoesVinculadasPorFoto[item.mediaImage.id] ?? [];
    final estaVinculada = secoesVinculadas.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(TFRadius.r12),
        border: Border.all(
          color: estaVinculada ? Colors.blue.shade400 : colors.borderSubtle,
          width: estaVinculada ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail com Badge flutuante e Data (clicável para abrir viewer com galeria)
          Expanded(
            child: InkWell(
              onTap: () => _abrirViewerFoto(item, listaVisivel),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(TFRadius.r12)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(TFRadius.r12)),
                    child: item.imageUrl != null
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                  ),
                  // Badge Superior Esquerdo com Nível
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildBadgeNivel(item.nivel),
                  ),
                  // Data em Destaque Inferior com Gradiente
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 11, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                item.dataFormatada,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            item.idadeFormatada,
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Informações da fotografia e Ações no rodapé do Card
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _abrirViewerFoto(item, listaVisivel),
                  child: Text(
                    item.title,
                    style: typography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.motivoCorrespondencia,
                  style: typography.caption.copyWith(
                    fontSize: 10.0,
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Badges das Seções da Análise onde já está vinculada
                if (estaVinculada) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: secoesVinculadas.map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade200, width: 0.6),
                        ),
                        child: Text(
                          s.labelCurto,
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 6),
                // Botão de Vinculação / Gerenciamento na Análise
                OutlinedButton.icon(
                  icon: Icon(
                    estaVinculada
                        ? Icons.playlist_add_check_rounded
                        : Icons.add_link_rounded,
                    size: 13,
                    color: estaVinculada
                        ? Colors.blue.shade900
                        : Colors.grey.shade800,
                  ),
                  label: Text(
                    estaVinculada ? 'Gerenciar na Análise' : 'Usar na Análise',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: estaVinculada
                          ? Colors.blue.shade900
                          : Colors.grey.shade800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    minimumSize: const Size(0, 26),
                    side: BorderSide(
                      color: estaVinculada
                          ? Colors.blue.shade300
                          : Colors.grey.shade300,
                    ),
                    backgroundColor: estaVinculada
                        ? Colors.blue.shade50
                        : Colors.white,
                  ),
                  onPressed: () => _abrirModalVincularFoto(item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
