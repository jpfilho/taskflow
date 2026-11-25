import 'package:flutter/material.dart';

import '../../../../design_system/taskflow_design_system.dart';
import '../../data/repositories/supabase_apoios_gateway_repository.dart';
import '../../domain/models/task_apoio_tipo.dart';

/// Tela de cadastro e manutenção de Tipos de Apoio Operacional (`tasks_apoios_tipos`).
class TipoApoioListView extends StatefulWidget {
  final SupabaseApoiosGatewayRepository? repository;

  const TipoApoioListView({super.key, this.repository});

  @override
  State<TipoApoioListView> createState() => _TipoApoioListViewState();
}

class _TipoApoioListViewState extends State<TipoApoioListView> {
  late final SupabaseApoiosGatewayRepository _repo =
      widget.repository ?? SupabaseApoiosGatewayRepository();
  final TextEditingController _buscaCtrl = TextEditingController();

  bool _carregando = true;
  bool _apenasAtivos = false;
  String? _erro;
  List<TaskApoioTipo> _tipos = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await _repo.listarTodosTipos();
      if (!mounted) return;
      setState(() => _tipos = lista);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<TaskApoioTipo> get _filtrados {
    final termo = _buscaCtrl.text.trim().toLowerCase();
    return _tipos.where((t) {
      if (_apenasAtivos && !t.ativo) return false;
      if (termo.isEmpty) return true;
      return t.nome.toLowerCase().contains(termo) ||
          t.codigo.toLowerCase().contains(termo) ||
          (t.descricao?.toLowerCase().contains(termo) ?? false);
    }).toList();
  }

  Future<void> _abrirFormulario([TaskApoioTipo? existente]) async {
    final formKey = GlobalKey<FormState>();
    final nomeCtrl = TextEditingController(text: existente?.nome ?? '');
    final codigoCtrl = TextEditingController(text: existente?.codigo ?? '');
    final descCtrl = TextEditingController(text: existente?.descricao ?? '');
    final ordemCtrl = TextEditingController(
      text: (existente?.ordem ?? (_tipos.length + 1) * 10).toString(),
    );
    bool ativo = existente?.ativo ?? true;
    bool codigoEditadoManual = existente != null;

    final salvo = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: Text(
            existente == null ? 'Novo Tipo de Apoio' : 'Editar Tipo de Apoio',
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome *',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        if (!codigoEditadoManual) {
                          codigoCtrl.text = v
                              .trim()
                              .toUpperCase()
                              .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
                              .replaceAll(RegExp(r'^_+|_+$'), '');
                        }
                      },
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o nome do tipo de apoio'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: codigoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Código *',
                        helperText: 'Ex.: APOIO_TECNICO, FROTA_VEICULOS',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => codigoEditadoManual = true,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o código identificador'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: ordemCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Ordem',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Ativo'),
                            value: ativo,
                            onChanged: (v) => setStateDlg(() => ativo = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                try {
                  final ordem = int.tryParse(ordemCtrl.text.trim()) ?? 0;
                  if (existente == null) {
                    await _repo.criarTipoApoio(
                      codigo: codigoCtrl.text.trim(),
                      nome: nomeCtrl.text.trim(),
                      descricao: descCtrl.text.trim(),
                      ordem: ordem,
                      ativo: ativo,
                    );
                  } else {
                    await _repo.atualizarTipoApoio(
                      existente.id,
                      codigo: codigoCtrl.text.trim(),
                      nome: nomeCtrl.text.trim(),
                      descricao: descCtrl.text.trim(),
                      ordem: ordem,
                      ativo: ativo,
                    );
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    nomeCtrl.dispose();
    codigoCtrl.dispose();
    descCtrl.dispose();
    ordemCtrl.dispose();

    if (salvo == true) {
      await _carregar();
    }
  }

  Future<void> _alternarAtivo(TaskApoioTipo tipo) async {
    try {
      await _repo.atualizarTipoApoio(tipo.id, ativo: !tipo.ativo);
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _excluir(TaskApoioTipo tipo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Tipo de Apoio'),
        content: Text(
          'Deseja excluir "${tipo.nome}"? Caso já esteja em uso por solicitações, recomenda-se apenas inativar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _repo.excluirTipoApoio(tipo.id);
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final itens = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipos de Apoio'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _carregar,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo Tipo'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 340,
                  child: TextField(
                    controller: _buscaCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome, código ou descrição...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _buscaCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _buscaCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                FilterChip(
                  label: const Text('Apenas ativos'),
                  selected: _apenasAtivos,
                  onSelected: (v) => setState(() => _apenasAtivos = v),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_erro!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _carregar,
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : itens.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum tipo de apoio encontrado.',
                              style: typo.bodyMedium.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: itens.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final t = itens[idx];
                              return TFCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.handshake_outlined,
                                      color: t.ativo
                                          ? colors.primary
                                          : colors.textSecondary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                t.nome,
                                                style: typo.bodyMedium.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              TFStatusBadge(
                                                label: t.codigo,
                                                severity:
                                                    TFStatusSeverity.neutral,
                                                compact: true,
                                              ),
                                              TFStatusBadge(
                                                label: t.ativo
                                                    ? 'Ativo'
                                                    : 'Inativo',
                                                severity: t.ativo
                                                    ? TFStatusSeverity.success
                                                    : TFStatusSeverity.warning,
                                                compact: true,
                                              ),
                                            ],
                                          ),
                                          if (t.descricao != null &&
                                              t.descricao!.trim().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              t.descricao!,
                                              style: typo.bodySmall.copyWith(
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: t.ativo ? 'Inativar' : 'Ativar',
                                      icon: Icon(
                                        t.ativo
                                            ? Icons.toggle_on
                                            : Icons.toggle_off_outlined,
                                        color: t.ativo
                                            ? colors.success
                                            : colors.textSecondary,
                                      ),
                                      onPressed: () => _alternarAtivo(t),
                                    ),
                                    IconButton(
                                      tooltip: 'Editar',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _abrirFormulario(t),
                                    ),
                                    IconButton(
                                      tooltip: 'Excluir',
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: colors.danger,
                                      ),
                                      onPressed: () => _excluir(t),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

