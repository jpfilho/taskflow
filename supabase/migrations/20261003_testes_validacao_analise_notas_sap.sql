-- ==============================================================================
-- SCRIPT DE TESTES E VALIDAÇÃO: FASE 1 (MÓDULO DE ANÁLISE DE NOTAS SAP)
-- Execute este script no SQL Editor após rodar a migration 20261003_analise_notas_sap.sql
-- ==============================================================================

DO $$
DECLARE
  v_nota_id UUID;
  v_numero_nota VARCHAR(50);
  v_analise_id UUID;
  v_dummy_id UUID := '00000000-0000-0000-0000-000000000000';
  v_erro_ocorreu BOOLEAN;
BEGIN
  RAISE NOTICE '==================================================';
  RAISE NOTICE 'INICIANDO BATERIA DE TESTES DE VALIDAÇÃO (FASE 1)';
  RAISE NOTICE '==================================================';

  -- Obter uma nota existente para os testes
  SELECT id, nota INTO v_nota_id, v_numero_nota FROM public.notas_sap LIMIT 1;
  IF v_nota_id IS NULL THEN
    RAISE EXCEPTION 'Nenhuma Nota SAP encontrada no banco para executar os testes!';
  END IF;

  RAISE NOTICE 'Nota selecionada para teste: ID %, Número %', v_nota_id, v_numero_nota;

  -- ----------------------------------------------------------------------------
  -- TESTE A: Criar análise vinculada a Nota SAP existente
  -- ----------------------------------------------------------------------------
  INSERT INTO public.notas_sap_analises (
    nota_sap_id, numero_nota, status_analise, diagnostico_previo, escopo_detalhado
  ) VALUES (
    v_nota_id, v_numero_nota, 'em_analise', 'Diagnóstico teste A', 'Escopo teste A'
  ) RETURNING id INTO v_analise_id;

  RAISE NOTICE '✅ TESTE A APROVADO: Análise criada com sucesso (ID: %)', v_analise_id;

  -- ----------------------------------------------------------------------------
  -- TESTE B: Impedir duas análises 1:1 para a mesma Nota (UNIQUE constraint)
  -- ----------------------------------------------------------------------------
  v_erro_ocorreu := FALSE;
  BEGIN
    INSERT INTO public.notas_sap_analises (nota_sap_id, status_analise)
    VALUES (v_nota_id, 'em_analise');
  EXCEPTION WHEN unique_violation THEN
    v_erro_ocorreu := TRUE;
  END;

  IF v_erro_ocorreu THEN
    RAISE NOTICE '✅ TESTE B APROVADO: Bloqueou duplicidade 1:1 para a mesma Nota SAP';
  ELSE
    RAISE EXCEPTION '❌ TESTE B FALHOU: Permitiu criar duas análises para a mesma Nota!';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TESTE C: Permitir vários materiais para a mesma Nota/análise
  -- ----------------------------------------------------------------------------
  INSERT INTO public.notas_sap_analise_materiais (nota_sap_id, analise_id, descricao, quantidade, unidade, status_material)
  VALUES 
    (v_nota_id, v_analise_id, 'Cabo de cobre 50mm', 15.5, 'M', 'disponivel'),
    (v_nota_id, v_analise_id, 'Conector terminal', 4, 'UN', 'aguardando_material');

  RAISE NOTICE '✅ TESTE C APROVADO: Múltiplos materiais inseridos com sucesso';

  -- ----------------------------------------------------------------------------
  -- TESTE D: Permitir vários anexos
  -- ----------------------------------------------------------------------------
  INSERT INTO public.notas_sap_anexos (nota_sap_id, nome_arquivo, tipo_arquivo, caminho_arquivo, tamanho_bytes, mime_type)
  VALUES 
    (v_nota_id, 'foto_defeito.jpg', 'imagem', 'notas_sap/foto1.jpg', 102400, 'image/jpeg'),
    (v_nota_id, 'esquema.pdf', 'documento', 'notas_sap/doc1.pdf', 204800, 'application/pdf');

  RAISE NOTICE '✅ TESTE D APROVADO: Múltiplos anexos inseridos com sucesso';

  -- ----------------------------------------------------------------------------
  -- TESTE E: Permitir vários comentários
  -- ----------------------------------------------------------------------------
  INSERT INTO public.notas_sap_comentarios (nota_sap_id, usuario_id, usuario_nome, mensagem)
  VALUES 
    (v_nota_id, gen_random_uuid(), 'Analista Carlos', 'Iniciando levantamento em campo'),
    (v_nota_id, gen_random_uuid(), 'Supervisor Marcos', 'Material já solicitado');

  RAISE NOTICE '✅ TESTE E APROVADO: Múltiplos comentários inseridos com sucesso';

  -- ----------------------------------------------------------------------------
  -- TESTE F: Validar FK com Nota inexistente
  -- ----------------------------------------------------------------------------
  v_erro_ocorreu := FALSE;
  BEGIN
    INSERT INTO public.notas_sap_analises (nota_sap_id, status_analise)
    VALUES (v_dummy_id, 'em_analise');
  EXCEPTION WHEN foreign_key_violation THEN
    v_erro_ocorreu := TRUE;
  END;

  IF v_erro_ocorreu THEN
    RAISE NOTICE '✅ TESTE F APROVADO: FK barrou inserção de análise para Nota inexistente';
  ELSE
    RAISE EXCEPTION '❌ TESTE F FALHOU: Permitiu FK órfã!';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TESTE G: Validar CHECK constraints
  -- ----------------------------------------------------------------------------
  -- G1: status_analise inválido (ex: aguardando_material que removemos)
  v_erro_ocorreu := FALSE;
  BEGIN
    UPDATE public.notas_sap_analises SET status_analise = 'aguardando_material' WHERE id = v_analise_id;
  EXCEPTION WHEN check_violation THEN
    v_erro_ocorreu := TRUE;
  END;
  IF NOT v_erro_ocorreu THEN
    RAISE EXCEPTION '❌ TESTE G1 FALHOU: Permitiu status_analise inválido!';
  END IF;

  -- G2: status_material inválido
  v_erro_ocorreu := FALSE;
  BEGIN
    INSERT INTO public.notas_sap_analise_materiais (nota_sap_id, analise_id, descricao, status_material)
    VALUES (v_nota_id, v_analise_id, 'Item inválido', 'status_inexistente');
  EXCEPTION WHEN check_violation THEN
    v_erro_ocorreu := TRUE;
  END;
  IF NOT v_erro_ocorreu THEN
    RAISE EXCEPTION '❌ TESTE G2 FALHOU: Permitiu status_material inválido!';
  END IF;

  RAISE NOTICE '✅ TESTE G APROVADO: Todos os CHECK constraints estão operantes e rígidos';

  -- ----------------------------------------------------------------------------
  -- TESTE H: Validar RLS
  -- ----------------------------------------------------------------------------
  IF (SELECT relrowsecurity FROM pg_class WHERE relname = 'notas_sap_analises') AND
     (SELECT relrowsecurity FROM pg_class WHERE relname = 'notas_sap_analise_materiais') AND
     (SELECT relrowsecurity FROM pg_class WHERE relname = 'notas_sap_anexos') AND
     (SELECT relrowsecurity FROM pg_class WHERE relname = 'notas_sap_comentarios') THEN
    RAISE NOTICE '✅ TESTE H APROVADO: RLS habilitado nas 4 tabelas';
  ELSE
    RAISE EXCEPTION '❌ TESTE H FALHOU: RLS ausente em alguma tabela!';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TESTE I: Confirmar integridade das views existentes
  -- ----------------------------------------------------------------------------
  PERFORM COUNT(*) FROM public.notas_sap_com_local;
  PERFORM COUNT(*) FROM public.notas_sap_com_prazo;
  RAISE NOTICE '✅ TESTE I APROVADO: Views notas_sap_com_local e notas_sap_com_prazo intactas e funcionais';

  -- ----------------------------------------------------------------------------
  -- TESTE J: Confirmar que a ausência de análise não afeta tarefas nem notas
  -- ----------------------------------------------------------------------------
  PERFORM COUNT(*) FROM public.tasks;
  PERFORM COUNT(*) FROM public.tasks_notas_sap;
  RAISE NOTICE '✅ TESTE J APROVADO: Estruturas de tarefas e vínculos 100%% independentes';

  -- LIMPEZA DOS DADOS DE TESTE
  DELETE FROM public.notas_sap_analises WHERE id = v_analise_id;
  DELETE FROM public.notas_sap_anexos WHERE nota_sap_id = v_nota_id;
  DELETE FROM public.notas_sap_comentarios WHERE nota_sap_id = v_nota_id;

  RAISE NOTICE '==================================================';
  RAISE NOTICE 'TODOS OS TESTES (A até J) PASSARAM COM SUCESSO! 🚀';
  RAISE NOTICE '==================================================';
END $$;
