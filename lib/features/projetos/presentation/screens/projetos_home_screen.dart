import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/components/inputs/tf_text_field.dart';
import '../../../../design_system/components/layout/tf_page_header.dart';
import '../../../../design_system/foundations/tf_breakpoints.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/projeto.dart';
import '../../providers/projetos_provider.dart';
import '../widgets/projeto_card.dart';
import '../widgets/projeto_form_dialog.dart';
import 'projeto_detail_screen.dart';

class ProjetosHomeScreen extends StatefulWidget {
  const ProjetosHomeScreen({super.key});

  @override
  State<ProjetosHomeScreen> createState() => _ProjetosHomeScreenState();
}

class _ProjetosHomeScreenState extends State<ProjetosHomeScreen> {
  final ProjetosProvider _provider = ProjetosProvider();
  final TextEditingController _buscaController = TextEditingController();
  String _filtroTexto = '';

  @override
  void initState() {
    super.initState();
    _buscaController.addListener(() {
      setState(() {
        _filtroTexto = _buscaController.text.trim().toLowerCase();
      });
    });
    _provider.carregarProjetos();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _abrirFormulario({Projeto? projeto}) async {
    final novoProjeto = await showDialog<Projeto>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProjetoFormDialog(projeto: projeto),
    );

    if (novoProjeto != null) {
      if (projeto == null) {
        final service = _provider.service;
        await service.createProjeto(novoProjeto);
      } else {
        final service = _provider.service;
        await service.updateProjeto(novoProjeto);
      }
      _provider.carregarProjetos();
    }
  }

  List<Projeto> _filtrarProjetos(List<Projeto> todos) {
    if (_filtroTexto.isEmpty) return todos;
    return todos.where((p) {
      final nome = p.nome.toLowerCase();
      final codigo = p.codigo?.toLowerCase() ?? '';
      final descricao = p.descricao?.toLowerCase() ?? '';
      final status = p.status.toLowerCase();
      return nome.contains(_filtroTexto) ||
          codigo.contains(_filtroTexto) ||
          descricao.contains(_filtroTexto) ||
          status.contains(_filtroTexto);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final isDesktop = TFBreakpoints.isDesktop(context);
    final isTablet = TFBreakpoints.isTablet(context);

    return ListenableBuilder(
      listenable: _provider,
      builder: (context, child) {
        final projetosFiltrados = _filtrarProjetos(_provider.projetos);

        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Page Header oficial TFDS
                TFPageHeader(
                  title: 'Gestão de Projetos',
                  subtitle: 'Planeje, estruture macroetapas, etapas e acompanhe o progresso físico das obras.',
                  primaryAction: TFButton(
                    label: 'Novo Projeto',
                    leadingIcon: TFIcons.add,
                    onPressed: () => _abrirFormulario(),
                  ),
                  secondaryActions: [
                    TFIconButton(
                      icon: TFIcons.refresh,
                      tooltip: 'Atualizar Projetos',
                      onPressed: _provider.carregarProjetos,
                    ),
                  ],
                ),

                // 2. Barra de Busca
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
                  child: TFTextField(
                    controller: _buscaController,
                    hint: 'Pesquisar por nome, código, descrição ou status...',
                    prefixIcon: const Icon(TFIcons.search, size: 18),
                    suffixIcon: _filtroTexto.isNotEmpty
                        ? IconButton(
                            icon: const Icon(TFIcons.clear, size: 16),
                            onPressed: () => _buscaController.clear(),
                          )
                        : null,
                  ),
                ),

                // 3. Conteúdo Principal (Loading / Empty / Cards Grid)
                Expanded(
                  child: _provider.isLoading
                      ? const Center(child: TFLoading(message: 'Carregando projetos...'))
                      : _provider.projetos.isEmpty
                          ? Center(
                              child: TFEmptyState(
                                title: 'Nenhum projeto cadastrado',
                                description: 'Clique em "Novo Projeto" para registrar o primeiro empreendimento.',
                                icon: TFIcons.task,
                                action: TFButton(
                                  label: 'Novo Projeto',
                                  leadingIcon: TFIcons.add,
                                  onPressed: () => _abrirFormulario(),
                                ),
                              ),
                            )
                          : projetosFiltrados.isEmpty
                              ? Center(
                                  child: TFEmptyState(
                                    title: 'Nenhum projeto encontrado',
                                    description: 'Não foram encontrados projetos compatíveis com a busca.',
                                    icon: TFIcons.search,
                                    action: TFButton(
                                      label: 'Limpar Busca',
                                      leadingIcon: TFIcons.clear,
                                      onPressed: () => _buscaController.clear(),
                                    ),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: () async => _provider.carregarProjetos(),
                                  child: isDesktop
                                      ? GridView.builder(
                                          padding: EdgeInsets.all(spacing.md),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            childAspectRatio: 1.6,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 16,
                                          ),
                                          itemCount: projetosFiltrados.length,
                                          itemBuilder: (context, index) {
                                            final p = projetosFiltrados[index];
                                            return ProjetoCard(
                                              projeto: p,
                                              onTap: () {
                                                Navigator.of(context).push(MaterialPageRoute(
                                                  builder: (_) => ProjetoDetailScreen(projeto: p),
                                                ));
                                              },
                                              onEdit: () => _abrirFormulario(projeto: p),
                                            );
                                          },
                                        )
                                      : isTablet
                                          ? GridView.builder(
                                              padding: EdgeInsets.all(spacing.md),
                                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                childAspectRatio: 1.4,
                                                crossAxisSpacing: 12,
                                                mainAxisSpacing: 12,
                                              ),
                                              itemCount: projetosFiltrados.length,
                                              itemBuilder: (context, index) {
                                                final p = projetosFiltrados[index];
                                                return ProjetoCard(
                                                  projeto: p,
                                                  onTap: () {
                                                    Navigator.of(context).push(MaterialPageRoute(
                                                      builder: (_) => ProjetoDetailScreen(projeto: p),
                                                    ));
                                                  },
                                                  onEdit: () => _abrirFormulario(projeto: p),
                                                );
                                              },
                                            )
                                          : ListView.separated(
                                              padding: EdgeInsets.all(spacing.md),
                                              itemCount: projetosFiltrados.length,
                                              separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
                                              itemBuilder: (context, index) {
                                                final p = projetosFiltrados[index];
                                                return ProjetoCard(
                                                  projeto: p,
                                                  onTap: () {
                                                    Navigator.of(context).push(MaterialPageRoute(
                                                      builder: (_) => ProjetoDetailScreen(projeto: p),
                                                    ));
                                                  },
                                                  onEdit: () => _abrirFormulario(projeto: p),
                                                );
                                              },
                                            ),
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
