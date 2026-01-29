import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../config/supabase_config.dart';
import '../models/status_album.dart';
import '../../../../services/auth_service_simples.dart';

class StatusAlbumRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Converter Map do Supabase para StatusAlbum
  StatusAlbum _statusAlbumFromMap(Map<String, dynamic> map) {
    return StatusAlbum.fromMap(map);
  }

  // Converter StatusAlbum para Map (para Supabase)
  Map<String, dynamic> _statusAlbumToMap(StatusAlbum statusAlbum) {
    return {
      'nome': statusAlbum.nome,
      if (statusAlbum.descricao != null) 'descricao': statusAlbum.descricao,
      if (statusAlbum.corFundo != null) 'cor_fundo': statusAlbum.corFundo,
      if (statusAlbum.corTexto != null) 'cor_texto': statusAlbum.corTexto,
      'ativo': statusAlbum.ativo,
      'ordem': statusAlbum.ordem,
    };
  }

  /// Buscar todos os status de álbuns
  Future<List<StatusAlbum>> getAllStatusAlbums() async {
    try {
      final response = await _supabase
          .from('status_albums')
          .select()
          .order('ordem', ascending: true)
          .order('nome', ascending: true);

      if (response.isEmpty) return [];

      final statusList = response as List;
      return statusList
          .map((map) => _statusAlbumFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar status de álbuns: $e');
      return [];
    }
  }

  /// Buscar status de álbuns ativos
  Future<List<StatusAlbum>> getStatusAlbumsAtivos() async {
    try {
      final response = await _supabase
          .from('status_albums')
          .select()
          .eq('ativo', true)
          .order('ordem', ascending: true)
          .order('nome', ascending: true);

      if (response.isEmpty) return [];

      final statusList = response as List;
      return statusList
          .map((map) => _statusAlbumFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar status de álbuns ativos: $e');
      return [];
    }
  }

  /// Buscar status de álbum por ID
  Future<StatusAlbum?> getStatusAlbumById(String id) async {
    try {
      final response = await _supabase
          .from('status_albums')
          .select()
          .eq('id', id)
          .single();

      return _statusAlbumFromMap(response);
    } catch (e) {
      print('Erro ao buscar status de álbum por ID: $e');
      return null;
    }
  }

  /// Criar novo status de álbum
  Future<StatusAlbum?> createStatusAlbum(StatusAlbum statusAlbum) async {
    try {
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      
      final data = _statusAlbumToMap(statusAlbum);
      if (usuario != null) {
        data['created_by'] = usuario.id;
      }

      final response = await _supabase
          .from('status_albums')
          .insert(data)
          .select()
          .single();

      return _statusAlbumFromMap(response);
    } catch (e) {
      print('Erro ao criar status de álbum: $e');
      return null;
    }
  }

  /// Atualizar status de álbum
  Future<StatusAlbum?> updateStatusAlbum(String id, StatusAlbum statusAlbum) async {
    try {
      final data = _statusAlbumToMap(statusAlbum);
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('status_albums')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return _statusAlbumFromMap(response);
    } catch (e) {
      print('Erro ao atualizar status de álbum: $e');
      return null;
    }
  }

  /// Deletar status de álbum
  Future<bool> deleteStatusAlbum(String id) async {
    try {
      await _supabase
          .from('status_albums')
          .delete()
          .eq('id', id);

      return true;
    } catch (e) {
      print('Erro ao deletar status de álbum: $e');
      return false;
    }
  }

  /// Filtrar status de álbuns
  Future<List<StatusAlbum>> filterStatusAlbums({
    bool? ativo,
  }) async {
    try {
      var query = _supabase.from('status_albums').select();

      if (ativo != null) {
        query = query.eq('ativo', ativo);
      }

      final response = await query
          .order('ordem', ascending: true)
          .order('nome', ascending: true);

      if (response.isEmpty) return [];

      final statusList = response as List;
      return statusList
          .map((map) => _statusAlbumFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao filtrar status de álbuns: $e');
      return [];
    }
  }

  /// Buscar status de álbuns por texto
  Future<List<StatusAlbum>> searchStatusAlbums(String query) async {
    if (query.isEmpty) return await getAllStatusAlbums();

    try {
      final response = await _supabase
          .from('status_albums')
          .select()
          .or('nome.ilike.%$query%,descricao.ilike.%$query%')
          .order('ordem', ascending: true)
          .order('nome', ascending: true);

      if (response.isEmpty) return [];

      final statusList = response as List;
      return statusList
          .map((map) => _statusAlbumFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar status de álbuns: $e');
      return [];
    }
  }
}
