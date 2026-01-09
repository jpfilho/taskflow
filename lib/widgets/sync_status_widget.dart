import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_database_service.dart';

class SyncStatusWidget extends StatefulWidget {
  const SyncStatusWidget({super.key});

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  final SyncService _syncService = SyncService();
  final ConnectivityService _connectivity = ConnectivityService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  
  bool _isConnected = true;
  bool _isSyncing = false;
  int _pendingCount = -1; // -1 indica que ainda não foi verificado ou banco não disponível
  
  @override
  void initState() {
    super.initState();
    _isConnected = _connectivity.isConnected;
    _loadPendingCount();
    
    // Escutar mudanças de conectividade
    _connectivity.connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
        _loadPendingCount();
      }
    });
    
    // Escutar mudanças de sincronização (se houver stream)
    // Por enquanto, vamos verificar periodicamente
    _startPeriodicCheck();
  }
  
  void _startPeriodicCheck() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _loadPendingCount();
        _startPeriodicCheck();
      }
    });
  }
  
  Future<void> _loadPendingCount() async {
    try {
      // Verificar se o banco local está disponível
      try {
        final db = await _localDb.database;
        final pendingQueue = await db.query(
          'sync_queue',
          where: 'synced = ?',
          whereArgs: [0],
        );
        
        final pendingTasks = await db.query(
          'tasks_local',
          where: 'sync_status = ?',
          whereArgs: ['pending'],
        );
        
        final pendingSegments = await db.query(
          'gantt_segments_local',
          where: 'sync_status = ?',
          whereArgs: ['pending'],
        );
        
        if (mounted) {
          setState(() {
            _pendingCount = pendingQueue.length + pendingTasks.length + pendingSegments.length;
            _isSyncing = _syncService.isSyncing;
          });
        }
      } catch (dbError) {
        // Se o banco não estiver disponível (plugin não registrado), apenas verificar conectividade
        if (mounted) {
          setState(() {
            _pendingCount = -1; // -1 indica que o banco não está disponível
            _isSyncing = false;
          });
        }
      }
    } catch (e) {
      // Ignorar erros silenciosamente para não poluir o console
      if (mounted) {
        setState(() {
          _pendingCount = -1; // -1 indica que o banco não está disponível
          _isSyncing = false;
        });
      }
    }
  }
  
  Future<void> _syncNow() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sem conexão com a internet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isSyncing = true);
    
    try {
      await _syncService.syncAll();
      await _loadPendingCount();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronização concluída'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na sincronização: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Só mostrar se houver conexão ou pendências ou estiver sincronizando
    // E se o banco local estiver disponível (verificado pela ausência de erros)
    if ((!_isConnected || _pendingCount > 0 || _isSyncing) && _pendingCount >= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isSyncing 
              ? Colors.blue[100]
              : _pendingCount > 0
                  ? Colors.orange[100]
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSyncing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            else if (!_isConnected)
              Icon(
                Icons.cloud_off,
                size: 16,
                color: Colors.orange[800],
              )
            else if (_pendingCount > 0)
              Icon(
                Icons.sync_problem,
                size: 16,
                color: Colors.orange[800],
              ),
            if (_isSyncing || _pendingCount > 0 || !_isConnected) ...[
              const SizedBox(width: 8),
              Text(
                _isSyncing
                    ? 'Sincronizando...'
                    : !_isConnected
                        ? 'Offline'
                        : '$_pendingCount pendente${_pendingCount > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: _isSyncing
                      ? Colors.blue[800]
                      : _pendingCount > 0
                          ? Colors.orange[800]
                          : Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              if (!_isSyncing && _isConnected && _pendingCount > 0)
                InkWell(
                  onTap: _syncNow,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Sincronizar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}

