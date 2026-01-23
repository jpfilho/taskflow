-- VIEW para retornar notas_sap com cálculo automático de prazo
-- Calcula a data de vencimento e dias restantes baseado nas regras de prazo
-- Considera o segmento do centro de trabalho da nota
-- Isso evita processamento pesado no frontend

-- Remover a VIEW existente se houver (para permitir mudança de tipo)
DROP VIEW IF EXISTS public.notas_sap_com_prazo;

CREATE VIEW public.notas_sap_com_prazo AS
SELECT
    ns.*,
    -- Calcular data de vencimento
    -- A data de referência é determinada pela regra cadastrada
    -- Busca regras para ambas as datas (criacao e inicio_desejado) e usa a que encontrar
    -- NOTA: Quando a regra tem data_referencia = 'inicio_desejado', na verdade usa o campo inicio_avaria da tabela
    -- Prioriza a regra que corresponde à prioridade da nota
    CASE
        -- Se não tem prioridade, não calcula
        WHEN ns.text_prioridade IS NULL OR TRIM(ns.text_prioridade) = '' THEN NULL
        
        ELSE
            -- Usar COALESCE para tentar ambas as regras (criacao primeiro, depois inicio_desejado)
            -- A regra determina qual data usar, não a existência de inicio_desejado
            COALESCE(
                -- Primeiro tenta regra para criacao (se a nota tiver criado_em)
                (SELECT (ns.criado_em + INTERVAL '1 day' * rpn.dias_prazo)::date
                 FROM regras_prazo_notas rpn
                 WHERE UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
                   AND rpn.data_referencia = 'criacao'
                   AND rpn.ativo = true
                   AND ns.criado_em IS NOT NULL
                   AND (
                       -- Regra sem segmentos específicos (aplica a todos)
                       NOT EXISTS (
                           SELECT 1 FROM regras_prazo_notas_segmentos rpns
                           WHERE rpns.regra_prazo_nota_id = rpn.id
                       )
                       OR
                       -- Regra com segmentos específicos - verificar se o centro de trabalho da nota corresponde
                       EXISTS (
                           SELECT 1 
                           FROM regras_prazo_notas_segmentos rpns
                           WHERE rpns.regra_prazo_nota_id = rpn.id
                             AND EXISTS (
                                 SELECT 1
                                 FROM segmentos s
                                 INNER JOIN centros_trabalho ct ON ct.segmento_id = s.id
                                 WHERE s.id = rpns.segmento_id
                                   AND ct.ativo = true
                                   AND (
                                       UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
                                       OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
                                       OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
                                   )
                             )
                       )
                   )
                 ORDER BY 
                     CASE WHEN NOT EXISTS (
                         SELECT 1 FROM regras_prazo_notas_segmentos rpns
                         WHERE rpns.regra_prazo_nota_id = rpn.id
                     ) THEN 0 ELSE 1 END
                 LIMIT 1),
                
                -- Se não encontrou regra para criacao, tenta regra para inicio_desejado (usa inicio_avaria da tabela)
                (SELECT (ns.inicio_avaria + INTERVAL '1 day' * rpn.dias_prazo)::date
                 FROM regras_prazo_notas rpn
                 WHERE UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
                   AND rpn.data_referencia = 'inicio_desejado'
                   AND rpn.ativo = true
                   AND ns.inicio_avaria IS NOT NULL
                   AND (
                       -- Regra sem segmentos específicos (aplica a todos)
                       NOT EXISTS (
                           SELECT 1 FROM regras_prazo_notas_segmentos rpns
                           WHERE rpns.regra_prazo_nota_id = rpn.id
                       )
                       OR
                       -- Regra com segmentos específicos - verificar se o centro de trabalho da nota corresponde
                       EXISTS (
                           SELECT 1 
                           FROM regras_prazo_notas_segmentos rpns
                           WHERE rpns.regra_prazo_nota_id = rpn.id
                             AND EXISTS (
                                 SELECT 1
                                 FROM segmentos s
                                 INNER JOIN centros_trabalho ct ON ct.segmento_id = s.id
                                 WHERE s.id = rpns.segmento_id
                                   AND ct.ativo = true
                                   AND (
                                       UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
                                       OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
                                       OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
                                   )
                             )
                       )
                   )
                 ORDER BY 
                     CASE WHEN NOT EXISTS (
                         SELECT 1 FROM regras_prazo_notas_segmentos rpns
                         WHERE rpns.regra_prazo_nota_id = rpn.id
                     ) THEN 0 ELSE 1 END
                 LIMIT 1)
            )
    END AS data_vencimento,
    
    -- Calcular dias restantes
    -- A data de referência é determinada pela regra cadastrada
    -- Busca regras para ambas as datas (criacao e inicio_desejado) e usa a que encontrar
    -- NOTA: Quando a regra tem data_referencia = 'inicio_desejado', na verdade usa o campo inicio_avaria da tabela
    CASE
        WHEN ns.text_prioridade IS NULL OR TRIM(ns.text_prioridade) = '' THEN NULL
        
        ELSE
            -- Usar COALESCE para tentar ambas as regras (criacao primeiro, depois inicio_desejado)
            COALESCE(
                -- Primeiro tenta regra para criacao (se a nota tiver criado_em)
                (SELECT 
                    ((ns.criado_em + INTERVAL '1 day' * rpn.dias_prazo)::date - CURRENT_DATE)::integer
                 FROM regras_prazo_notas rpn
                 WHERE UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
                   AND rpn.data_referencia = 'criacao'
                   AND rpn.ativo = true
                   AND ns.criado_em IS NOT NULL
                   AND (
                       -- Regra sem segmentos específicos (aplica a todos)
                       NOT EXISTS (
                           SELECT 1 FROM regras_prazo_notas_segmentos rpns
                           WHERE rpns.regra_prazo_nota_id = rpn.id
                       )
                       OR
                       -- Regra com segmentos específicos - verificar se o centro de trabalho da nota corresponde
                       EXISTS (
                           SELECT 1 
                           FROM regras_prazo_notas_segmentos rpns
                           WHERE rpns.regra_prazo_nota_id = rpn.id
                             AND EXISTS (
                                 SELECT 1
                                 FROM segmentos s
                                 INNER JOIN centros_trabalho ct ON ct.segmento_id = s.id
                                 WHERE s.id = rpns.segmento_id
                                   AND ct.ativo = true
                                   AND (
                                       UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
                                       OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
                                       OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
                                   )
                             )
                       )
                   )
                 ORDER BY 
                     CASE WHEN NOT EXISTS (
                         SELECT 1 FROM regras_prazo_notas_segmentos rpns
                         WHERE rpns.regra_prazo_nota_id = rpn.id
                     ) THEN 0 ELSE 1 END
                 LIMIT 1),
                
                -- Se não encontrou regra para criacao, tenta regra para inicio_desejado (usa inicio_avaria da tabela)
                (SELECT 
                    ((ns.inicio_avaria + INTERVAL '1 day' * rpn.dias_prazo)::date - CURRENT_DATE)::integer
                 FROM regras_prazo_notas rpn
                 WHERE UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
                   AND rpn.data_referencia = 'inicio_desejado'
                   AND rpn.ativo = true
                   AND ns.inicio_avaria IS NOT NULL
                   AND (
                       -- Regra sem segmentos específicos (aplica a todos)
                       NOT EXISTS (
                           SELECT 1 FROM regras_prazo_notas_segmentos rpns
                           WHERE rpns.regra_prazo_nota_id = rpn.id
                       )
                       OR
                       -- Regra com segmentos específicos - verificar se o centro de trabalho da nota corresponde
                       EXISTS (
                           SELECT 1 
                           FROM regras_prazo_notas_segmentos rpns
                           WHERE rpns.regra_prazo_nota_id = rpn.id
                             AND EXISTS (
                                 SELECT 1
                                 FROM segmentos s
                                 INNER JOIN centros_trabalho ct ON ct.segmento_id = s.id
                                 WHERE s.id = rpns.segmento_id
                                   AND ct.ativo = true
                                   AND (
                                       UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
                                       OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
                                       OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
                                   )
                             )
                       )
                   )
                 ORDER BY 
                     CASE WHEN NOT EXISTS (
                         SELECT 1 FROM regras_prazo_notas_segmentos rpns
                         WHERE rpns.regra_prazo_nota_id = rpn.id
                     ) THEN 0 ELSE 1 END
                 LIMIT 1)
            )
    END AS dias_restantes
    
FROM notas_sap_com_local ns;

COMMENT ON VIEW public.notas_sap_com_prazo IS 'View de notas SAP que inclui cálculo automático de prazo (data_vencimento e dias_restantes) baseado nas regras de prazo configuradas. Quando a regra tem data_referencia = ''inicio_desejado'', usa o campo inicio_avaria da tabela notas_sap.';

-- Recarregar o schema do PostgREST para que a nova VIEW seja reconhecida
NOTIFY pgrst, 'reload schema';
