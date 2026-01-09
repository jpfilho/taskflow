import 'package:flutter/material.dart';
import '../models/divisao.dart';
import '../models/regional.dart';
import '../models/segmento.dart';
import '../services/regional_service.dart';
import '../services/segmento_service.dart';
import '../utils/responsive.dart';

class DivisaoFormDialog extends StatefulWidget {
  final Divisao? divisao;

  const DivisaoFormDialog({
    super.key,
    this.divisao,
  });

  @override
  State<DivisaoFormDialog> createState() => _DivisaoFormDialogState();
}

class _DivisaoFormDialogState extends State<DivisaoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _divisaoController;
  final RegionalService _regionalService = RegionalService();
  final SegmentoService _segmentoService = SegmentoService();
  List<Regional> _regionais = [];
  List<Segmento> _segmentos = [];
  Regional? _selectedRegional;
  List<String> _selectedSegmentoIds = []; // Lista de IDs de segmentos selecionados
  bool _isLoadingRegionais = true;
  bool _isLoadingSegmentos = true;

  @override
  void initState() {
    super.initState();
    _divisaoController = TextEditingController(
      text: widget.divisao?.divisao ?? '',
    );
    _loadRegionais();
    _loadSegmentos();
  }

  @override
  void dispose() {
    _divisaoController.dispose();
    super.dispose();
  }

  Future<void> _loadRegionais() async {
    setState(() {
      _isLoadingRegionais = true;
    });

    try {
      print('🔍 DEBUG: Carregando regionais...');
      final regionais = await _regionalService.getAllRegionais();
      print('✅ DEBUG: ${regionais.length} regionais carregadas');
      
      if (!mounted) return;
      
      setState(() {
        _regionais = regionais;
        _isLoadingRegionais = false;

        // Selecionar a regional se estiver editando
        if (widget.divisao != null && widget.divisao!.regionalId.isNotEmpty) {
          try {
            _selectedRegional = regionais.firstWhere(
              (r) => r.id == widget.divisao!.regionalId,
            );
          } catch (e) {
            print('⚠️ DEBUG: Regional não encontrada, usando primeira disponível');
            _selectedRegional = regionais.isNotEmpty ? regionais.first : null;
          }
        } else if (regionais.isNotEmpty) {
          _selectedRegional = regionais.first;
        }
      });
    } catch (e, stackTrace) {
      print('❌ Erro ao carregar regionais: $e');
      print('❌ Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoadingRegionais = false;
        _regionais = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar regionais: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadSegmentos() async {
    setState(() {
      _isLoadingSegmentos = true;
    });

    try {
      print('🔍 DEBUG: Carregando segmentos...');
      final segmentos = await _segmentoService.getAllSegmentos();
      print('✅ DEBUG: ${segmentos.length} segmentos carregados');
      
      if (!mounted) return;
      
      setState(() {
        _segmentos = segmentos;
        _isLoadingSegmentos = false;

        // Selecionar os segmentos se estiver editando
        if (widget.divisao != null) {
          print('📋 Editando divisão: ${widget.divisao!.divisao}');
          print('📋 Segmentos IDs da divisão: ${widget.divisao!.segmentoIds}');
          print('📋 Segmentos nomes da divisão: ${widget.divisao!.segmentos}');
          if (widget.divisao!.segmentoIds.isNotEmpty) {
            _selectedSegmentoIds = List<String>.from(widget.divisao!.segmentoIds);
            print('✅ Segmentos selecionados: $_selectedSegmentoIds');
          } else {
            print('⚠️ Divisão não tem segmentos associados');
          }
        }
      });
    } catch (e, stackTrace) {
      print('❌ Erro ao carregar segmentos: $e');
      print('❌ Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoadingSegmentos = false;
        _segmentos = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar segmentos: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (_selectedRegional == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione uma regional'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedSegmentoIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione pelo menos um segmento'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Obter nomes dos segmentos selecionados
      final segmentosNomes = _segmentos
          .where((s) => _selectedSegmentoIds.contains(s.id))
          .map((s) => s.segmento)
          .toList();

      final divisao = Divisao(
        id: widget.divisao?.id ?? '',
        divisao: _divisaoController.text.trim(),
        regionalId: _selectedRegional!.id,
        regional: _selectedRegional!.regional,
        segmentoIds: _selectedSegmentoIds,
        segmentos: segmentosNomes,
        createdAt: widget.divisao?.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(divisao);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.divisao != null;
    final isMobile = Responsive.isMobile(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return AlertDialog(
      title: Text(
        isEditing ? 'Editar Divisão' : 'Nova Divisão',
        style: TextStyle(fontSize: isMobile ? 18 : 20),
      ),
      contentPadding: EdgeInsets.all(isMobile ? 16 : 24),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenWidth * 0.95 : (screenWidth * 0.9).clamp(300.0, 500.0),
          maxHeight: isMobile ? screenHeight * 0.8 : screenHeight * 0.7,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _divisaoController,
                  decoration: InputDecoration(
                    labelText: 'Divisão *',
                    border: const OutlineInputBorder(),
                    hintText: 'Digite o nome da divisão',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 16 : 20,
                    ),
                  ),
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Campo obrigatório';
                    }
                    return null;
                  },
                ),
                SizedBox(height: isMobile ? 12 : 16),
                // Dropdown de Regional
                _isLoadingRegionais
                    ? const CircularProgressIndicator()
                    : _regionais.isEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Regional *',
                                style: TextStyle(
                                  fontSize: isMobile ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.all(isMobile ? 12 : 16),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  border: Border.all(color: Colors.red),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Nenhuma regional encontrada. Verifique a conexão com o banco de dados.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : DropdownButtonFormField<Regional>(
                            value: _selectedRegional,
                            decoration: InputDecoration(
                              labelText: 'Regional *',
                              border: const OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: isMobile ? 16 : 20,
                              ),
                            ),
                            style: TextStyle(fontSize: isMobile ? 14 : 16),
                            isExpanded: true,
                            items: _regionais.map((regional) {
                              return DropdownMenuItem<Regional>(
                                value: regional,
                                child: Text(
                                  isMobile
                                      ? regional.regional
                                      : '${regional.regional} - ${regional.divisao} - ${regional.empresa}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                                ),
                              );
                            }).toList(),
                            onChanged: (Regional? value) {
                              setState(() {
                                _selectedRegional = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Selecione uma regional';
                              }
                              return null;
                            },
                          ),
                SizedBox(height: isMobile ? 12 : 16),
                // Seleção múltipla de Segmentos
                _isLoadingSegmentos
                    ? const CircularProgressIndicator()
                    : _segmentos.isEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Segmentos *',
                                style: TextStyle(
                                  fontSize: isMobile ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.all(isMobile ? 12 : 16),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  border: Border.all(color: Colors.red),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Nenhum segmento encontrado. Verifique a conexão com o banco de dados.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Segmentos *',
                                style: TextStyle(
                                  fontSize: isMobile ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                constraints: BoxConstraints(
                                  maxHeight: isMobile ? screenHeight * 0.25 : 200,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _segmentos.length,
                                  itemBuilder: (context, index) {
                                    final segmento = _segmentos[index];
                                    final isSelected = _selectedSegmentoIds.contains(segmento.id);
                                    
                                    return CheckboxListTile(
                                      title: Text(
                                        segmento.segmento,
                                        style: TextStyle(fontSize: isMobile ? 14 : 16),
                                      ),
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          if (value == true) {
                                            if (!_selectedSegmentoIds.contains(segmento.id)) {
                                              _selectedSegmentoIds.add(segmento.id);
                                            }
                                          } else {
                                            _selectedSegmentoIds.remove(segmento.id);
                                          }
                                        });
                                      },
                                      dense: isMobile,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 8 : 12,
                                        vertical: isMobile ? 4 : 8,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (_selectedSegmentoIds.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Selecione pelo menos um segmento',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: isMobile ? 11 : 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: EdgeInsets.all(isMobile ? 8 : 16),
      actions: [
        if (isMobile)
          // Mobile: botões em coluna
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                  ),
                  child: Text(
                    isEditing ? 'Salvar' : 'Criar',
                    style: TextStyle(fontSize: isMobile ? 14 : 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                  ),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(fontSize: isMobile ? 14 : 16),
                  ),
                ),
              ),
            ],
          )
        else
          // Desktop/Tablet: botões em linha
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _save,
                child: Text(isEditing ? 'Salvar' : 'Criar'),
              ),
            ],
          ),
      ],
    );
  }
}

