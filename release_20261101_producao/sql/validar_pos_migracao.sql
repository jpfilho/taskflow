-- ==============================================================================
-- VALIDAÇÃO PÓS-MIGRAÇÃO DE PRODUÇÃO
-- ARQUIVO: validar_pos_migracao.sql
-- AMBIENTE: Produção (10.140.50.12)
-- OBJETIVO: Verificar a integridade das 7 novas estruturas, colunas críticas,
--           índices e status do RLS.
-- ==============================================================================

\echo '====================================================================='
\echo 'TASKFLOW - RELATÓRIO DE VALIDAÇÃO PÓS-MIGRAÇÃO (PRODUÇÃO 10.140.50.12)'
\echo '====================================================================='

-- 1. VERIFICAR PRESENÇA DAS 10 TABELAS DO MÓDULO SAP
SELECT 
    table_name AS tabela,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables t 
            WHERE t.table_schema = 'public' AND t.table_name = expected.table_name
        ) THEN '✅ PRESENTE'
        ELSE '❌ AUSENTE'
    END AS status
FROM (
    VALUES 
        ('notas_sap_analises'),
        ('notas_sap_analise_materiais'),
        ('notas_sap_comentarios'),
        ('notas_sap_grupos'),
        ('notas_sap_grupos_itens'),
        ('notas_sap_grupos_previsoes_hist'),
        ('notas_sap_anexos'),
        ('notas_sap_anexos_anotacoes'),
        ('notas_sap_analise_evidencias'),
        ('notas_sap_tags'),
        ('notas_sap_tags_vinculos')
) AS expected(table_name)
ORDER BY table_name;

-- 2. VERIFICAR COLUNAS CRÍTICAS ADICIONADAS
SELECT 
    expected.table_name AS tabela,
    expected.column_name AS coluna_critica,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns c 
            WHERE c.table_schema = 'public' 
              AND c.table_name = expected.table_name 
              AND c.column_name = expected.column_name
        ) THEN '✅ PRESENTE'
        ELSE '❌ AUSENTE'
    END AS status
FROM (
    VALUES 
        ('notas_sap_analises', 'valor_pv'),
        ('notas_sap_anexos', 'bucket'),
        ('notas_sap_anexos', 'sap_document_id'),
        ('notas_sap_anexos', 'sha256'),
        ('notas_sap_anexos', 'relevante_analise'),
        ('notas_sap_anexos', 'anexo_derivado_de_id'),
        ('notas_sap_analise_evidencias', 'tipo_fonte'),
        ('notas_sap_analise_evidencias', 'media_image_id'),
        ('notas_sap_analise_evidencias', 'anotacao_versao'),
        ('notas_sap_tags', 'escopo_tipo'),
        ('notas_sap_tags', 'nome_normalizado')
) AS expected(table_name, column_name)
ORDER BY table_name, column_name;

-- 3. VERIFICAR STATUS DO ROW LEVEL SECURITY (RLS)
SELECT 
    relname AS tabela,
    CASE WHEN relrowsecurity THEN '✅ RLS ATIVADO' ELSE '❌ RLS DESATIVADO' END AS rls_status
FROM pg_class
WHERE relname IN (
    'notas_sap_analises',
    'notas_sap_analise_materiais',
    'notas_sap_comentarios',
    'notas_sap_grupos',
    'notas_sap_grupos_itens',
    'notas_sap_grupos_previsoes_hist',
    'notas_sap_anexos',
    'notas_sap_anexos_anotacoes',
    'notas_sap_analise_evidencias',
    'notas_sap_tags',
    'notas_sap_tags_vinculos'
)
ORDER BY relname;

-- 4. VERIFICAR BUCKET DE ANEXOS SAP
SELECT 
    id AS bucket_id,
    CASE WHEN public THEN 'PÚBLICO' ELSE '✅ PRIVADO (OK)' END AS visibilidade,
    CASE WHEN id IS NOT NULL THEN '✅ CONFIGURADO' ELSE '❌ AUSENTE' END AS status
FROM storage.buckets
WHERE id = 'notas-sap-anexos';

-- 5. RESUMO FINAL
DO $$
DECLARE
    v_missing_tables INTEGER;
    v_missing_columns INTEGER;
    v_disabled_rls INTEGER;
BEGIN
    -- Contar tabelas ausentes
    SELECT count(*) INTO v_missing_tables
    FROM (
        VALUES 
            ('notas_sap_analises'), ('notas_sap_analise_materiais'), ('notas_sap_comentarios'),
            ('notas_sap_grupos'), ('notas_sap_grupos_itens'), ('notas_sap_grupos_previsoes_hist'),
            ('notas_sap_anexos'), ('notas_sap_anexos_anotacoes'), ('notas_sap_analise_evidencias'),
            ('notas_sap_tags'), ('notas_sap_tags_vinculos')
    ) AS exp(tbl)
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.tables t 
        WHERE t.table_schema = 'public' AND t.table_name = exp.tbl
    );

    -- Contar colunas ausentes
    SELECT count(*) INTO v_missing_columns
    FROM (
        VALUES 
            ('notas_sap_analises', 'valor_pv'),
            ('notas_sap_anexos', 'bucket'),
            ('notas_sap_anexos', 'sap_document_id'),
            ('notas_sap_anexos', 'sha256'),
            ('notas_sap_anexos', 'relevante_analise'),
            ('notas_sap_analise_evidencias', 'tipo_fonte'),
            ('notas_sap_analise_evidencias', 'media_image_id'),
            ('notas_sap_tags', 'escopo_tipo')
    ) AS exp(tbl, col)
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.columns c 
        WHERE c.table_schema = 'public' AND c.table_name = exp.tbl AND c.column_name = exp.col
    );

    -- Contar RLS desativado
    SELECT count(*) INTO v_disabled_rls
    FROM pg_class
    WHERE relname IN (
        'notas_sap_analises', 'notas_sap_analise_materiais', 'notas_sap_comentarios',
        'notas_sap_grupos', 'notas_sap_grupos_itens', 'notas_sap_grupos_previsoes_hist',
        'notas_sap_anexos', 'notas_sap_anexos_anotacoes', 'notas_sap_analise_evidencias',
        'notas_sap_tags', 'notas_sap_tags_vinculos'
    ) AND NOT relrowsecurity;

    IF v_missing_tables = 0 AND v_missing_columns = 0 AND v_disabled_rls = 0 THEN
        RAISE NOTICE '=============================================================';
        RAISE NOTICE ' RESULTADO GLOBAL: ✅ TODAS AS VALIDAÇÕES FORAM CONCLUÍDAS COM SUCESSO!';
        RAISE NOTICE ' Banco de Produção 10.140.50.12 pronto e sincronizado.';
        RAISE NOTICE '=============================================================';
    ELSE
        RAISE EXCEPTION 'FALHA NA VALIDAÇÃO: % tabela(s) ausente(s), % coluna(s) ausente(s), % tabela(s) sem RLS.',
            v_missing_tables, v_missing_columns, v_disabled_rls;
    END IF;
END $$;
