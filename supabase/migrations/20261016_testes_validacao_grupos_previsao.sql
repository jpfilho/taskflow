-- ==============================================================================
-- SCRIPT DE TESTES E VALIDAÇÃO: BANCO DE DADOS (12 TESTES OBRIGATÓRIOS)
-- ==============================================================================

DO $$
DECLARE
  v_nota_1 UUID;
  v_nota_2 UUID;
  v_grupo_1 UUID;
  v_grupo_2 UUID;
  v_grupo_encerrado UUID;
  v_hist_count INTEGER;
  v_erro_ocorreu BOOLEAN;
BEGIN
  RAISE NOTICE '==================================================';
  RAISE NOTICE 'INICIANDO OS 12 TESTES DE BANCO: GRUPOS E PREVISÃO';
  RAISE NOTICE '==================================================';

  -- Obter 2 notas reais para os testes
  SELECT id INTO v_nota_1 FROM public.notas_sap LIMIT 1;
  SELECT id INTO v_nota_2 FROM public.notas_sap OFFSET 1 LIMIT 1;

  IF v_nota_1 IS NULL OR v_nota_2 IS NULL THEN
    RAISE EXCEPTION 'Notas SAP insuficientes para teste no banco!';
  END IF;

  -- Limpar vínculos anteriores dessas notas para isolar os testes
  DELETE FROM public.notas_sap_grupos_itens WHERE nota_sap_id IN (v_nota_1, v_nota_2);

  -- ----------------------------------------------------------------------------
  -- TESTE 1: Criar grupo básico
  -- ----------------------------------------------------------------------------
  INSERT INTO public.notas_sap_grupos (nome, descricao, motivo)
  VALUES ('Grupo Teste 1', 'Descrição do grupo 1', 'Motivo do grupo 1')
  RETURNING id INTO v_grupo_1;

  IF v_grupo_1 IS NULL THEN
    RAISE EXCEPTION '❌ TESTE 1 FALHOU: Não retornou ID ao criar grupo';
  END IF;
  RAISE NOTICE '✅ TESTE 1 APROVADO: Criou grupo com sucesso (ID: %)', v_grupo_1;

  -- ----------------------------------------------------------------------------
  -- TESTE 2: Grupo sem previsão (ambos NULL)
  -- ----------------------------------------------------------------------------
  IF EXISTS (
    SELECT 1 FROM public.notas_sap_grupos 
    WHERE id = v_grupo_1 AND mes_programacao_previsto IS NULL AND ano_programacao_previsto IS NULL
  ) THEN
    RAISE NOTICE '✅ TESTE 2 APROVADO: Grupo sem previsão persistido corretamente com campos NULL';
  ELSE
    RAISE EXCEPTION '❌ TESTE 2 FALHOU: Previsão não é NULL';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TESTE 3: Grupo com previsão válida
  -- ----------------------------------------------------------------------------
  UPDATE public.notas_sap_grupos 
  SET mes_programacao_previsto = 11, ano_programacao_previsto = 2026, motivo_previsao = 'Aguardar desligamento'
  WHERE id = v_grupo_1;

  IF EXISTS (
    SELECT 1 FROM public.notas_sap_grupos 
    WHERE id = v_grupo_1 AND mes_programacao_previsto = 11 AND ano_programacao_previsto = 2026
  ) THEN
    RAISE NOTICE '✅ TESTE 3 APROVADO: Grupo com previsão (11/2026) atualizado com sucesso';
  ELSE
    RAISE EXCEPTION '❌ TESTE 3 FALHOU: Falha ao definir previsão válida';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TESTE 4: Constraint de Mês inválido (< 1 ou > 12)
  -- ----------------------------------------------------------------------------
  v_erro_ocorreu := FALSE;
  BEGIN
    INSERT INTO public.notas_sap_grupos (nome, mes_programacao_previsto, ano_programacao_previsto)
    VALUES ('Grupo Mês Inválido', 13, 2026);
  EXCEPTION WHEN check_violation THEN
    v_erro_ocorreu := TRUE;
  END;

  IF v_erro_ocorreu THEN
    RAISE NOTICE '✅ TESTE 4 APROVADO: Bloqueou mês inválido (13)';
  ELSE
    RAISE EXCEPTION '❌ TESTE 4 FALHOU: Permitiu mês inválido (13)';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TESTE 5: Constraint de Ano inválido (< 2020 ou > 2100)
  -- ----------------------------------------------------------------------------
  v_erro_ocorreu := FALSE;
  BEGIN
    INSERT INTO public.notas_sap_grupos (nome, mes_programacao_previsto, ano_programacao_previsto)
    VALUES ('Grupo Ano Inválido', 10, 2018);
  EXCEPTION WHEN check_violation THEN
    v_erro_ocorreu := TRUE;
  END;

  IF v_erro_ocorreu THEN
    RAISE NOTICE '✅ TESTE 5 APROVADO: Bloqueou ano inválido (2018)';
  ELSE
    RAISE EXCEPTION '❌ TESTE 5 FALHOU: Permitiu ano inválido (2018)';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TESTE 6: Constraint de Paridade (Mês sem Ano)
  -- ----------------------------------------------------------------------------
  v_erro_ocorreu := FALSE;
  BEGIN
    INSERT INTO public.notas_sap_grupos (nome, mes_programacao_previsto, ano_programacao_previsto)
    VALUES ('Grupo Mês Sem Ano', 10, NULL);
  EXCEPTION WHEN check_violation THEN
    v_erro_ocorreu := TRUE;
  END;

  IF v_erro_ocorreu THEN
    RAISE NOTICE '✅ TESTE 6 APROVADO: Bloqueou mês preenchido sem ano';
  ELSE
    RAISE EXCEPTION '❌ TESTE 6 FALHOU: Permitiu mês preenchido sem ano';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TESTE 7: Constraint de Paridade (Ano sem Mês)
  -- ----------------------------------------------------------------------------
  v_erro_ocorreu := FALSE;
  BEGIN
    INSERT INTO public.notas_sap_grupos (nome, mes_programacao_previsto, ano_programacao_previsto)
    VALUES ('Grupo Ano Sem Mês', NULL, 2026);
  EXCEPTION WHEN check_violation THEN
    v_erro_ocorreu := TRUE;
  END;

  IF v_erro_ocorreu THEN
    RAISE NOTICE '✅ TESTE 7 APROVADO: Bloqueou ano preenchido sem mês';
  ELSE
    RAISE EXCEPTION '❌ TESTE 7 FALHOU: Permitiu ano preenchido sem mês';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TESTE 8: Nota duplicada no mesmo grupo (UNIQUE grupo_id, nota_sap_id)
  -- ----------------------------------------------------------------------------
  INSERT INTO public.notas_sap_grupos_itens (grupo_id, nota_sap_id, motivo_vinculo)
  VALUES (v_grupo_1, v_nota_1, 'Primeira inserção da nota');

  v_erro_ocorreu := FALSE;
  BEGIN
    INSERT INTO public.notas_sap_grupos_itens (grupo_id, nota_sap_id, motivo_vinculo)
    VALUES (v_grupo_1, v_nota_1, 'Tentativa duplicada');
  EXCEPTION WHEN unique_violation THEN
    v_erro_ocorreu := TRUE;
  END;

  IF v_erro_ocorreu THEN
    RAISE NOTICE '✅ TESTE 8 APROVADO: Bloqueou nota duplicada no mesmo grupo';
  ELSE
    RAISE EXCEPTION '❌ TESTE 8 FALHOU: Permitiu nota duplicada no mesmo grupo';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TESTE 9: Nota em segundo grupo ativo (Regra de ouro de grupo ativo único)
  -- ----------------------------------------------------------------------------
  INSERT INTO public.notas_sap_grupos (nome, status_grupo)
  VALUES ('Grupo Teste 2 Ativo', 'ativo')
  RETURNING id INTO v_grupo_2;

  v_erro_ocorreu := FALSE;
  BEGIN
    -- Tentando inserir a nota 1 (que já está no grupo 1 ativo) no grupo 2 ativo
    INSERT INTO public.notas_sap_grupos_itens (grupo_id, nota_sap_id, motivo_vinculo)
    VALUES (v_grupo_2, v_nota_1, 'Tentativa em outro grupo ativo');
  EXCEPTION WHEN OTHERS THEN
    v_erro_ocorreu := TRUE;
  END;

  IF v_erro_ocorreu THEN
    RAISE NOTICE '✅ TESTE 9 APROVADO: Bloqueou inserção de Nota em segundo grupo ativo simultâneo';
  ELSE
    RAISE EXCEPTION '❌ TESTE 9 FALHOU: Permitiu Nota em dois grupos ativos simultaneamente';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TESTE 10: Nota em grupo encerrado + novo grupo ativo
  -- ----------------------------------------------------------------------------
  -- Criar grupo 3 e encerrá-lo com a nota 2
  INSERT INTO public.notas_sap_grupos (nome, status_grupo)
  VALUES ('Grupo Encerrado Antigo', 'encerrado')
  RETURNING id INTO v_grupo_encerrado;

  INSERT INTO public.notas_sap_grupos_itens (grupo_id, nota_sap_id, motivo_vinculo)
  VALUES (v_grupo_encerrado, v_nota_2, 'Histórico encerrado');

  -- Agora associar a nota 2 ao grupo 2 ativo -> DEVE PERMITIR!
  INSERT INTO public.notas_sap_grupos_itens (grupo_id, nota_sap_id, motivo_vinculo)
  VALUES (v_grupo_2, v_nota_2, 'Novo grupo ativo');

  RAISE NOTICE '✅ TESTE 10 APROVADO: Permitiu Nota em grupo encerrado histórico ingressar em novo grupo ativo';

  -- ----------------------------------------------------------------------------
  -- TESTE 11: Histórico de alteração de previsão (Outubro -> Novembro)
  -- ----------------------------------------------------------------------------
  -- Grupo 1 estava 11/2026, vamos alterar para 12/2026
  UPDATE public.notas_sap_grupos
  SET mes_programacao_previsto = 12, ano_programacao_previsto = 2026, motivo_previsao = 'Adiado para dezembro'
  WHERE id = v_grupo_1;

  SELECT count(*) INTO v_hist_count
  FROM public.notas_sap_grupos_previsoes_hist
  WHERE grupo_id = v_grupo_1;

  IF v_hist_count >= 1 THEN
    RAISE NOTICE '✅ TESTE 11 APROVADO: Trigger gerou histórico de previsão (Qtd registros: %)', v_hist_count;
  ELSE
    RAISE EXCEPTION '❌ TESTE 11 FALHOU: Não registrou histórico ao alterar previsão';
  END IF;

  -- ----------------------------------------------------------------------------
  -- TESTE 12: Remoção de previsão (Dezembro/2026 -> NULL)
  -- ----------------------------------------------------------------------------
  UPDATE public.notas_sap_grupos
  SET mes_programacao_previsto = NULL, ano_programacao_previsto = NULL, motivo_previsao = NULL
  WHERE id = v_grupo_1;

  SELECT count(*) INTO v_hist_count
  FROM public.notas_sap_grupos_previsoes_hist
  WHERE grupo_id = v_grupo_1 AND mes_novo IS NULL AND ano_novo IS NULL;

  IF v_hist_count >= 1 THEN
    RAISE NOTICE '✅ TESTE 12 APROVADO: Remoção de previsão registrada no histórico com valores NULL';
  ELSE
    RAISE EXCEPTION '❌ TESTE 12 FALHOU: Não registrou histórico de remoção de previsão';
  END IF;

  -- Limpar dados de teste
  DELETE FROM public.notas_sap_grupos WHERE id IN (v_grupo_1, v_grupo_2, v_grupo_encerrado);
  RAISE NOTICE '==================================================';
  RAISE NOTICE 'TODOS OS 12 TESTES DE BANCO FORAM CONCLUÍDOS COM SUCESSO!';
  RAISE NOTICE '==================================================';
END $$;
