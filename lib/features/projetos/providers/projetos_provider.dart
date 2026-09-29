import 'package:flutter/foundation.dart';
import '../models/projeto.dart';
import '../services/projeto_service.dart';

class ProjetosProvider extends ChangeNotifier {
  final ProjetoService _service = ProjetoService();
  
  List<Projeto> _projetos = [];
  bool _isLoading = true;

  List<Projeto> get projetos => _projetos;
  bool get isLoading => _isLoading;
  ProjetoService get service => _service;

  Future<void> carregarProjetos() async {
    _isLoading = true;
    notifyListeners();
    try {
      _projetos = await _service.getProjetos();
    } catch (e) {
      debugPrint('Erro ao carregar projetos: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
