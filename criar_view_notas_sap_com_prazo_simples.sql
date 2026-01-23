-- VIEW MUITO SIMPLIFICADA para testar - ignora completamente segmentos
-- Use esta versão para testar se o problema é com segmentos ou com a lógica básica

DROP VIEW IF EXISTS public.notas_sap_com_prazo;

CREATE VIEW public.notas_sap_com_prazo AS
SELECT
    ns.*,
    -- Calcular data de vencimento (VERSÃO SIMPLES - SEM VERIFICAÇÃO DE SEGMENTOS)
    CASE
        WHEN ns.text_prioridade IS NULL OR TRIM(ns.text_prioridade) = '' THEN NULL
        
        WHEN ns.inicio_desejado IS NOT NULL THEN
            (SELECT (ns.inicio_desejado + INTERVAL '1 day' * rpn.dias_prazo)::date
             FROM regras_prazo_notas rpn
             WHERE UPPER(TRIM(rpn.prioridade)) = UPPER(TRIM(ns.text_prioridade))
               AND rpn.data_referencia = 'inicio_desejado'
               AND rpn.ativo = true
             LIMIT 1)
        
        WHEN ns.criado_em IS NOT NULL THEN
            (SELECT (ns.criado_em + INTERVAL '1 day' * rpn.dias_prazo)::date
             FROM regras_prazo_notas rpn
             WHERE UPPER(TRIM(rpn.prioridade)) = UPPER(TRIM(ns.text_prioridade))
               AND rpn.data_referencia = 'criacao'
               AND rpn.ativo = true
             LIMIT 1)
        
        ELSE NULL
    END AS data_vencimento,
    
    -- Calcular dias restantes (VERSÃO SIMPLES - SEM VERIFICAÇÃO DE SEGMENTOS)
    CASE
        WHEN ns.text_prioridade IS NULL OR TRIM(ns.text_prioridade) = '' THEN NULL
        
        WHEN ns.inicio_desejado IS NOT NULL THEN
            (SELECT 
                ((ns.inicio_desejado + INTERVAL '1 day' * rpn.dias_prazo)::date - CURRENT_DATE)::integer
             FROM regras_prazo_notas rpn
             WHERE UPPER(TRIM(rpn.prioridade)) = UPPER(TRIM(ns.text_prioridade))
               AND rpn.data_referencia = 'inicio_desejado'
               AND rpn.ativo = true
             LIMIT 1)
        
        WHEN ns.criado_em IS NOT NULL THEN
            (SELECT 
                ((ns.criado_em + INTERVAL '1 day' * rpn.dias_prazo)::date - CURRENT_DATE)::integer
             FROM regras_prazo_notas rpn
             WHERE UPPER(TRIM(rpn.prioridade)) = UPPER(TRIM(ns.text_prioridade))
               AND rpn.data_referencia = 'criacao'
               AND rpn.ativo = true
             LIMIT 1)
        
        ELSE NULL
    END AS dias_restantes
    
FROM notas_sap_com_local ns;

COMMENT ON VIEW public.notas_sap_com_prazo IS 'View de notas SAP que inclui cálculo automático de prazo (versão simplificada para teste - sem verificação de segmentos).';

NOTIFY pgrst, 'reload schema';
