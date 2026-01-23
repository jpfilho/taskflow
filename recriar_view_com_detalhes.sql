-- Recriar VIEW para garantir que o campo 'detalhes' esteja incluído
-- A VIEW usa ns.* que já inclui todos os campos, mas vamos recriar para garantir
-- que o campo detalhes (adicionado depois) esteja disponível

-- IMPORTANTE: Execute primeiro este script para remover a VIEW
-- Depois execute o arquivo criar_view_notas_sap_com_prazo.sql para recriar a VIEW

-- Remover a VIEW existente (CASCADE remove dependências)
DROP VIEW IF EXISTS public.notas_sap_com_prazo CASCADE;

-- Agora execute o arquivo criar_view_notas_sap_com_prazo.sql para recriar a VIEW
-- A VIEW será recriada com ns.* que inclui o campo detalhes

-- Após recriar a VIEW, execute este comando para verificar:
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'notas_sap_com_prazo' 
--   AND column_name = 'detalhes';
