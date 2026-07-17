import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/demanda_model.dart';
import '../../data/models/demanda_anexo_model.dart';
import '../../data/services/demanda_service.dart';
import '../../../../services/local_service.dart';
import '../../../../services/executor_service.dart';
import '../../../../models/local.dart';
import '../../../../models/executor.dart';

class DemandaFormScreen extends StatefulWidget {
  final Demanda? demandaExistente;

  const DemandaFormScreen({super.key, this.demandaExistente});

  @override
  State<DemandaFormScreen> createState() => _DemandaFormScreenState();
}

class _DemandaFormScreenState extends State<DemandaFormScreen> {
  final DemandaService _demandaService = DemandaService();
  final LocalService _localService = LocalService();
  final ExecutorService _executorService = ExecutorService();

  final _formKey = GlobalKey<FormState>();

  // Controladores e variáveis de estado dos campos
  String? _origem;
  String? _local;
  final TextEditingController _salaController = TextEditingController();
  final TextEditingController _demandaController = TextEditingController();
  final TextEditingController _notaController = TextEditingController();
  final TextEditingController _ordemController = TextEditingController();
  final TextEditingController _siController = TextEditingController();
  final TextEditingController _atController = TextEditingController();
  String? _responsavel;
  DateTime? _prazo;
  String _status = 'Aberta';
  String _prioridade = 'Normal';
  final TextEditingController _observacoesController = TextEditingController();

  bool _isSaving = false;
  bool _isLoadingDropdowns = true;

  // Listas locais e executores cadastrados no sistema
  List<Local> _locaisDoSistema = [];
  List<Executor> _executoresDoSistema = [];

  // Listas de arquivos selecionados temporariamente para upload após salvar
  final List<PlatformFile> _novosAnexosAntes = [];
  final List<PlatformFile> _novosAnexosDepois = [];
  final List<PlatformFile> _novosAnexosGerais = [];

  // Anexos existentes (apenas em modo de edição)
  List<DemandaAnexo> _anexosExistentes = [];

  final List<String> _origens = [
    'Inspeção',
    'Reunião',
    'Operação',
    'Manutenção',
    'Segurança',
    'Auditoria',
    'Cliente interno',
    'Emergência',
    'Outro',
  ];

  final List<String> _statusOpcoes = [
    'Aberta',
    'Em análise',
    'Programada',
    'Em execução',
    'Aguardando terceiros',
    'Aguardando material',
    'Concluída',
    'Cancelada',
    'Suspensa'
  ];

  final List<String> _prioridadesOpcoes = [
    'Baixa',
    'Normal',
    'Alta',
    'Crítica',
  ];

  @override
  void initState() {
    super.initState();
    _carregarDropdownsEPrefills();
  }

  Future<void> _carregarDropdownsEPrefills() async {
    try {
      final locais = await _localService.getAllLocais();
      final executores = await _executorService.getAllExecutores();

      setState(() {
        _locaisDoSistema = locais;
        _executoresDoSistema = executores;
        _isLoadingDropdowns = false;
      });

      if (widget.demandaExistente != null) {
        final d = widget.demandaExistente!;
        _origem = d.origem;
        // Tenta achar o local nas opções carregadas, senão insere
        if (locais.any((l) => l.local == d.local)) {
          _local = d.local;
        } else {
          _local = d.local;
        }
        _salaController.text = d.sala ?? '';
        _demandaController.text = d.demanda;
        _notaController.text = d.nota ?? '';
        _ordemController.text = d.ordem ?? '';
        _siController.text = d.si ?? '';
        _atController.text = d.at ?? '';
        // Tenta achar o executor por nome
        if (executores.any((e) => e.nome == d.responsavel)) {
          _responsavel = d.responsavel;
        } else {
          _responsavel = d.responsavel;
        }
        _prazo = d.prazo;
        _status = d.status;
        _prioridade = d.prioridade;
        _observacoesController.text = d.observacoes ?? '';

        // Carregar anexos existentes
        final anexos = await _demandaService.listarAnexos(d.id);
        setState(() {
          _anexosExistentes = anexos;
        });
      }
    } catch (e) {
      print('Erro ao carregar dados dos dropdowns: $e');
      setState(() => _isLoadingDropdowns = false);
    }
  }

  Future<void> _selecionarArquivos(String tipo) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          if (tipo == 'antes') {
            _novosAnexosAntes.addAll(result.files);
          } else if (tipo == 'depois') {
            _novosAnexosDepois.addAll(result.files);
          } else {
            _novosAnexosGerais.addAll(result.files);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao selecionar arquivos: $e')),
      );
    }
  }

  void _removerNovoAnexo(PlatformFile file, String tipo) {
    setState(() {
      if (tipo == 'antes') {
        _novosAnexosAntes.remove(file);
      } else if (tipo == 'depois') {
        _novosAnexosDepois.remove(file);
      } else {
        _novosAnexosGerais.remove(file);
      }
    });
  }

  Future<void> _excluirAnexoExistente(DemandaAnexo anexo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir evidência/anexo'),
        content: Text('Deseja realmente excluir "${anexo.fileName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isSaving = true);
      try {
        await _demandaService.excluirAnexo(anexo);
        final anexos = await _demandaService.listarAnexos(widget.demandaExistente!.id);
        setState(() {
          _anexosExistentes = anexos;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anexo excluído com sucesso!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao excluir anexo: $e')),
        );
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_prazo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe a data limite (prazo).')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final d = Demanda(
        id: widget.demandaExistente?.id ?? '',
        origem: _origem!,
        local: _local!,
        sala: _salaController.text.trim().isEmpty ? null : _salaController.text.trim(),
        demanda: _demandaController.text.trim(),
        nota: _notaController.text.trim().isEmpty ? null : _notaController.text.trim(),
        ordem: _ordemController.text.trim().isEmpty ? null : _ordemController.text.trim(),
        si: _siController.text.trim().isEmpty ? null : _siController.text.trim(),
        at: _atController.text.trim().isEmpty ? null : _atController.text.trim(),
        responsavel: _responsavel!,
        prazo: _prazo!,
        status: _status,
        prioridade: _prioridade,
        observacoes: _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
      );

      Demanda demandaSalva;
      if (widget.demandaExistente == null) {
        demandaSalva = await _demandaService.criarDemanda(d);
      } else {
        demandaSalva = await _demandaService.atualizarDemanda(d, versaoAnterior: widget.demandaExistente);
      }

      // Upload dos novos anexos
      await _uploadNovosAnexos(demandaSalva.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demanda salva com sucesso!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar demanda: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadNovosAnexos(String demandaId) async {
    Future<void> uploadGrupo(List<PlatformFile> lista, String tipo) async {
      for (final file in lista) {
        if (file.bytes != null) {
          await _demandaService.uploadAnexo(
            demandaId: demandaId,
            tipo: tipo,
            fileName: file.name,
            bytes: file.bytes!,
            mimeType: file.extension,
          );
        }
      }
    }

    await uploadGrupo(_novosAnexosAntes, 'evidencia_antes');
    await uploadGrupo(_novosAnexosDepois, 'evidencia_depois');
    await uploadGrupo(_novosAnexosGerais, 'anexo_geral');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDropdowns) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.demandaExistente == null ? 'Nova Demanda' : 'Editar Demanda'),
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Salvando demanda e enviando evidências...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grid de Campos Básicos
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        // Origem (Dropdown)
                        SizedBox(
                          width: 250,
                          child: DropdownButtonFormField<String>(
                            value: _origem,
                            decoration: const InputDecoration(labelText: 'Origem *', border: OutlineInputBorder()),
                            items: _origens.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                            validator: (val) => val == null ? 'Campo obrigatório' : null,
                            onChanged: (val) => setState(() => _origem = val),
                          ),
                        ),
                        // Local (Dropdown com base nos locais existentes ou campo livre como fallback)
                        SizedBox(
                          width: 250,
                          child: DropdownButtonFormField<String>(
                            value: _local,
                            decoration: const InputDecoration(labelText: 'Local *', border: OutlineInputBorder()),
                            items: _locaisDoSistema.isEmpty
                                ? [DropdownMenuItem(value: _local ?? 'Principal', child: Text(_local ?? 'Principal'))]
                                : _locaisDoSistema.map((l) => DropdownMenuItem(value: l.local, child: Text(l.local))).toList(),
                            validator: (val) => val == null ? 'Campo obrigatório' : null,
                            onChanged: (val) => setState(() => _local = val),
                          ),
                        ),
                        // Sala
                        SizedBox(
                          width: 200,
                          child: TextFormField(
                            controller: _salaController,
                            decoration: const InputDecoration(labelText: 'Sala', border: OutlineInputBorder()),
                          ),
                        ),
                        // Responsável (Dropdown com base nos executores existentes)
                        SizedBox(
                          width: 250,
                          child: DropdownButtonFormField<String>(
                            value: _responsavel,
                            decoration: const InputDecoration(labelText: 'Responsável *', border: OutlineInputBorder()),
                            items: _executoresDoSistema.isEmpty
                                ? [DropdownMenuItem(value: _responsavel ?? 'Geral', child: Text(_responsavel ?? 'Geral'))]
                                : _executoresDoSistema.map((e) => DropdownMenuItem(value: e.nome, child: Text(e.nome))).toList(),
                            validator: (val) => val == null ? 'Campo obrigatório' : null,
                            onChanged: (val) => setState(() => _responsavel = val),
                          ),
                        ),
                        // Prazo (DatePicker)
                        SizedBox(
                          width: 200,
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _prazo ?? DateTime.now(),
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                              );
                              if (picked != null) {
                                setState(() => _prazo = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Prazo *', border: OutlineInputBorder()),
                              child: Text(
                                _prazo == null
                                    ? 'Selecionar data'
                                    : "${_prazo!.day.toString().padLeft(2, '0')}/${_prazo!.month.toString().padLeft(2, '0')}/${_prazo!.year}",
                              ),
                            ),
                          ),
                        ),
                        // Status
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            decoration: const InputDecoration(labelText: 'Status *', border: OutlineInputBorder()),
                            items: _statusOpcoes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (val) => setState(() => _status = val ?? 'Aberta'),
                          ),
                        ),
                        // Prioridade
                        SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<String>(
                            value: _prioridade,
                            decoration: const InputDecoration(labelText: 'Prioridade *', border: OutlineInputBorder()),
                            items: _prioridadesOpcoes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                            onChanged: (val) => setState(() => _prioridade = val ?? 'Normal'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Demanda (Descrição principal)
                    TextFormField(
                      controller: _demandaController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Demanda (Descrição da Atividade) *',
                        border: OutlineInputBorder(),
                        hintText: 'Descreva os detalhes e o que precisa ser feito...',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    // Dados SAP Associados
                    const Text('Associações SAP (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: _notaController,
                            decoration: const InputDecoration(labelText: 'Nota SAP', border: OutlineInputBorder()),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: _ordemController,
                            decoration: const InputDecoration(labelText: 'Ordem SAP', border: OutlineInputBorder()),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: _siController,
                            decoration: const InputDecoration(labelText: 'SI', border: OutlineInputBorder(), hintText: '00000000/00A'),
                            inputFormatters: [_SIMaskTextInputFormatter()],
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: _atController,
                            decoration: const InputDecoration(labelText: 'AT', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Observações
                    TextFormField(
                      controller: _observacoesController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Observações / Comentários adicionais', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    
                    // Upload e Gestão de Evidências (Antes, Depois, Geral)
                    const Text('Evidências & Anexos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Divider(),
                    _buildSecaoAnexos('antes', 'Evidências ANTES (Fotos da situação inicial)', _novosAnexosAntes),
                    const SizedBox(height: 16),
                    _buildSecaoAnexos('depois', 'Evidências DEPOIS (Fotos após a execução)', _novosAnexosDepois),
                    const SizedBox(height: 16),
                    _buildSecaoAnexos('geral', 'Documentos / Anexos Gerais', _novosAnexosGerais),
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _salvar,
                        child: const Text('SALVAR DEMANDA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSecaoAnexos(String tipo, String titulo, List<PlatformFile> novosAnexos) {
    final existentes = _anexosExistentes.where((a) => a.tipo == (tipo == 'antes' ? 'evidencia_antes' : tipo == 'depois' ? 'evidencia_depois' : 'anexo_geral')).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            TextButton.icon(
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Anexar'),
              onPressed: () => _selecionarArquivos(tipo),
            ),
          ],
        ),
        if (existentes.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('Existentes:', style: TextStyle(fontSize: 11, color: Colors.grey)),
          Wrap(
            spacing: 8,
            children: existentes.map((anexo) {
              final isImage = anexo.fileName.endsWith('.jpg') || anexo.fileName.endsWith('.png') || anexo.fileName.endsWith('.webp');
              return Chip(
                avatar: isImage && anexo.fileUrl != null
                    ? Image.network(anexo.fileUrl!, width: 24, height: 24, fit: BoxFit.cover)
                    : const Icon(Icons.insert_drive_file),
                label: Text(anexo.fileName, style: const TextStyle(fontSize: 11)),
                onDeleted: () => _excluirAnexoExistente(anexo),
              );
            }).toList(),
          ),
        ],
        if (novosAnexos.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('Novos selecionados (serão enviados ao salvar):', style: TextStyle(fontSize: 11, color: Colors.blue)),
          Wrap(
            spacing: 8,
            children: novosAnexos.map((file) {
              return Chip(
                avatar: file.bytes != null && (file.name.endsWith('.jpg') || file.name.endsWith('.png') || file.name.endsWith('.webp'))
                    ? Image.memory(file.bytes!, width: 24, height: 24, fit: BoxFit.cover)
                    : const Icon(Icons.insert_drive_file),
                label: Text(file.name, style: const TextStyle(fontSize: 11)),
                onDeleted: () => _removerNovoAnexo(file, tipo),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _SIMaskTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Permite apagar livremente
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    String text = newValue.text.toUpperCase();
    String newText = '';

    // Remove qualquer coisa que não seja número ou letra
    text = text.replaceAll(RegExp(r'[^0-9A-Z]'), '');

    int index = 0;
    for (int i = 0; i < text.length; i++) {
      if (index < 8) {
        // Primeiros 8 caracteres devem ser números
        if (RegExp(r'[0-9]').hasMatch(text[i])) {
          newText += text[i];
          index++;
        }
      } else if (index == 8) {
        newText += '/';
        // 9º caractere (após a barra) deve ser número
        if (RegExp(r'[0-9]').hasMatch(text[i])) {
          newText += text[i];
          index++;
        }
      } else if (index == 9) {
        // 10º caractere deve ser número
        if (RegExp(r'[0-9]').hasMatch(text[i])) {
          newText += text[i];
          index++;
        }
      } else if (index == 10) {
        // 11º caractere deve ser letra
        if (RegExp(r'[A-Z]').hasMatch(text[i])) {
          newText += text[i];
          index++;
        }
      }
    }

    if (newText.length > 12) {
      newText = newText.substring(0, 12);
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
