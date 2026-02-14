-- ============================================
-- EXECUTAR MIGRATIONS DO MÓDULO DOCUMENTS
-- ============================================
-- Ordem recomendada:
-- 1) Status
-- 2) Documents
-- 3) Versions
-- 4) RLS
-- 5) Storage policies
-- ============================================

-- Status dinâmicos
\i lib/features/documents/migrations/CREATE_STATUS_DOCUMENTS_TABLE.sql

-- Tabela principal
\i lib/features/documents/migrations/CREATE_DOCUMENTS_TABLE.sql

-- Versionamento
\i lib/features/documents/migrations/CREATE_DOCUMENT_VERSIONS_TABLE.sql

-- RLS
\i lib/features/documents/migrations/CREATE_DOCUMENTS_RLS_POLICIES.sql

-- Storage policies (bucket taskflow-documents)
\i lib/features/documents/migrations/CREATE_STORAGE_POLICIES_DOCUMENTS.sql

-- Verificações rápidas
SELECT 'documents' AS table, count(*) FROM public.documents;
SELECT 'status_documents' AS table, count(*) FROM public.status_documents;
SELECT 'document_versions' AS table, count(*) FROM public.document_versions;
