import 'dart:async';
import '../models/empresa.dart';
import '../config/supabase_config.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmpresaService {
  static final EmpresaService _instance = EmpresaService._internal();
  factory EmpresaService() => _instance;
  EmpresaService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();

  // Converter Map do Supabase para Empresa
  Empresa _empresaFromMap(Map<String, dynamic> map) {
    return Empresa.fromMap(map);
  }

  // Converter Empresa para Map (para Supabase)
  Map<String, dynamic> _empresaToMap(Empresa empresa) {
    return {
      'empresa': empresa.empresa,
      'regional_id': empresa.regionalId,
      'divisao_id': empresa.divisaoId,
      'tipo': empresa.tipo,
    };
  }

  // Buscar todas as empresas
  Future<List<Empresa>> getAllEmpresas() async {
    try {
      final response = await _supabase
          .from('empresas')
          .select('''
            *,
            regionais!inner(id, regional),
            divisoes!inner(id, divisao)
          ''')
          .order('empresa', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final empresasList = response as List;
      return empresasList
          .map((map) => _empresaFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar empresas: $e');
      // Tentar buscar sem join se falhar
      try {
        final response = await _supabase
            .from('empresas')
            .select()
            .order('empresa', ascending: true)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => <Map<String, dynamic>>[],
            );

        if (response.isEmpty) return [];

        final empresasList = response as List;
        final empresas = empresasList
            .map((map) => _empresaFromMap(map as Map<String, dynamic>))
            .toList();

        // Carregar nomes das regionais e divisões
        final empresasCompleta = <Empresa>[];
        for (var empresa in empresas) {
          var empresaAtualizada = empresa;
          
          // Carregar regional
          final regional = await _regionalService.getRegionalById(empresa.regionalId);
          if (regional != null) {
            empresaAtualizada = empresaAtualizada.copyWith(regional: regional.regional);
          }
          
          // Carregar divisão
          final divisao = await _divisaoService.getDivisaoById(empresa.divisaoId);
          if (divisao != null) {
            empresaAtualizada = empresaAtualizada.copyWith(divisao: divisao.divisao);
          }
          
          empresasCompleta.add(empresaAtualizada);
        }
        
        return empresasCompleta;
      } catch (e2) {
        print('Erro ao buscar empresas (fallback): $e2');
        return [];
      }
    }
  }

  // Buscar empresa por ID
  Future<Empresa?> getEmpresaById(String id) async {
    try {
      final response = await _supabase
          .from('empresas')
          .select('''
            *,
            regionais!inner(id, regional),
            divisoes!inner(id, divisao)
          ''')
          .eq('id', id)
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao buscar empresa'),
          );

      return _empresaFromMap(response);
    } catch (e) {
      print('Erro ao buscar empresa por ID: $e');
      return null;
    }
  }

  // Criar nova empresa
  Future<Empresa?> createEmpresa(Empresa empresa) async {
    try {
      final data = _empresaToMap(empresa);
      final response = await _supabase
          .from('empresas')
          .insert(data)
          .select('''
            *,
            regionais!inner(id, regional),
            divisoes!inner(id, divisao)
          ''')
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao criar empresa'),
          );

      return _empresaFromMap(response);
    } catch (e) {
      print('Erro ao criar empresa: $e');
      return null;
    }
  }

  // Atualizar empresa
  Future<Empresa?> updateEmpresa(String id, Empresa empresa) async {
    try {
      final data = _empresaToMap(empresa);
      final response = await _supabase
          .from('empresas')
          .update(data)
          .eq('id', id)
          .select('''
            *,
            regionais!inner(id, regional),
            divisoes!inner(id, divisao)
          ''')
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao atualizar empresa'),
          );

      return _empresaFromMap(response);
    } catch (e) {
      print('Erro ao atualizar empresa: $e');
      return null;
    }
  }

  // Deletar empresa
  Future<bool> deleteEmpresa(String id) async {
    try {
      await _supabase
          .from('empresas')
          .delete()
          .eq('id', id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao deletar empresa'),
          );

      return true;
    } catch (e) {
      print('Erro ao deletar empresa: $e');
      return false;
    }
  }

  // Filtrar empresas
  Future<List<Empresa>> filterEmpresas({
    String? regionalId,
    String? divisaoId,
    String? tipo,
  }) async {
    try {
      dynamic query = _supabase
          .from('empresas')
          .select('''
            *,
            regionais!inner(id, regional),
            divisoes!inner(id, divisao)
          ''');

      if (regionalId != null) {
        query = query.eq('regional_id', regionalId);
      }
      if (divisaoId != null) {
        query = query.eq('divisao_id', divisaoId);
      }
      if (tipo != null) {
        query = query.eq('tipo', tipo);
      }

      final response = await query
          .order('empresa', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final empresasList = response as List;
      return empresasList
          .map((map) => _empresaFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao filtrar empresas: $e');
      return [];
    }
  }

  // Buscar empresas por texto
  Future<List<Empresa>> searchEmpresas(String query) async {
    if (query.isEmpty) return await getAllEmpresas();

    try {
      final response = await _supabase
          .from('empresas')
          .select('''
            *,
            regionais!inner(id, regional),
            divisoes!inner(id, divisao)
          ''')
          .or('empresa.ilike.%$query%,tipo.ilike.%$query%')
          .order('empresa', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final empresasList = response as List;
      return empresasList
          .map((map) => _empresaFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar empresas: $e');
      return [];
    }
  }
}

