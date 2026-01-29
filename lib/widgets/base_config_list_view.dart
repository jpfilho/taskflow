import 'package:flutter/material.dart';

/// Componente base reutilizável para listas de configuração
/// Fornece layout moderno consistente para todas as páginas de cadastro
class BaseConfigListView extends StatelessWidget {
  final String title;
  final String searchHint;
  final String createButtonLabel;
  final VoidCallback onCreate;
  final bool isLoading;
  final List<Widget> tableHeaders;
  final List<Widget> tableRows;
  final int totalItems;
  final int currentPage;
  final int itemsPerPage;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final String emptyMessage;
  final String emptySubMessage;
  final VoidCallback? onEmptyAction;
  final String? emptyActionLabel;
  final IconData? emptyIcon;
  final Widget? floatingActionButton;

  const BaseConfigListView({
    super.key,
    required this.title,
    required this.searchHint,
    required this.createButtonLabel,
    required this.onCreate,
    required this.isLoading,
    required this.tableHeaders,
    required this.tableRows,
    required this.totalItems,
    required this.currentPage,
    required this.itemsPerPage,
    this.onPreviousPage,
    this.onNextPage,
    required this.emptyMessage,
    this.emptySubMessage = '',
    this.onEmptyAction,
    this.emptyActionLabel,
    this.emptyIcon,
    this.floatingActionButton,
  });

  int get totalPages => (totalItems / itemsPerPage).ceil();
  int get currentPageItems => (currentPage - 1) * itemsPerPage;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final hasItems = tableRows.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf1f5f9),
      body: SafeArea(
        child: Column(
          children: [
            // Header moderno
            _buildHeader(context, isDark),
            
            // Barra de busca
            _buildSearchBar(context, isDark),
            
            // Conteúdo (tabela ou estado vazio)
            Expanded(
              child: isLoading
                  ? _buildLoading(isDark)
                  : !hasItems
                      ? _buildEmptyState(context, isDark)
                      : _buildTable(context, isDark),
            ),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 20),
            label: Text(createButtonLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3b82f6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            width: 1,
          ),
        ),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: searchHint,
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFF3b82f6),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: TextStyle(
          color: isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b),
        ),
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    return Center(
      child: CircularProgressIndicator(
        color: const Color(0xFF3b82f6),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            emptyIcon ?? Icons.inbox_outlined,
            size: 64,
            color: isDark ? const Color(0xFF475569) : const Color(0xFF94a3b8),
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessage,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
            ),
          ),
          if (emptySubMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              emptySubMessage,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF64748b) : const Color(0xFF94a3b8),
              ),
            ),
          ],
          if (onEmptyAction != null && emptyActionLabel != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onEmptyAction,
              icon: const Icon(Icons.add),
              label: Text(emptyActionLabel!),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3b82f6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Cabeçalho da tabela
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: tableHeaders,
            ),
          ),
          
          // Corpo da tabela
          Expanded(
            child: ListView.separated(
              itemCount: tableRows.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
              ),
              itemBuilder: (context, index) => tableRows[index],
            ),
          ),
          
          // Rodapé com paginação
          _buildPagination(context, isDark),
        ],
      ),
    );
  }

  Widget _buildPagination(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando ${tableRows.length} de $totalItems ${title.toLowerCase()}',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: onPreviousPage,
                style: TextButton.styleFrom(
                  foregroundColor: onPreviousPage != null
                      ? (isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b))
                      : (isDark ? const Color(0xFF475569) : const Color(0xFF94a3b8)),
                ),
                child: const Text('Anterior'),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3b82f6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$currentPage',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onNextPage,
                style: TextButton.styleFrom(
                  foregroundColor: onNextPage != null
                      ? (isDark ? const Color(0xFFf1f5f9) : const Color(0xFF1e293b))
                      : (isDark ? const Color(0xFF475569) : const Color(0xFF94a3b8)),
                ),
                child: const Text('Próximo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
