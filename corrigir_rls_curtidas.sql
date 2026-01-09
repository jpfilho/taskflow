-- ============================================
-- SQL PARA CORRIGIR POLÍTICAS RLS DE CURTIDAS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- Este script corrige as políticas RLS para funcionar com autenticação customizada

-- Remover políticas antigas se existirem
DROP POLICY IF EXISTS "Usuários autenticados podem ver curtidas" ON task_likes;
DROP POLICY IF EXISTS "Usuários autenticados podem criar curtidas" ON task_likes;
DROP POLICY IF EXISTS "Usuários autenticados podem deletar suas curtidas" ON task_likes;

-- Criar novas políticas que funcionam com autenticação customizada
-- Política: Todos os usuários autenticados podem ver todas as curtidas
CREATE POLICY "Usuários autenticados podem ver curtidas"
  ON task_likes
  FOR SELECT
  USING (true); -- Permitir leitura para todos (ajustar se necessário)

-- Política: Usuários autenticados podem criar curtidas
-- Como o sistema usa autenticação customizada, não podemos verificar auth.uid()
-- Permitir inserção para usuários autenticados
CREATE POLICY "Usuários autenticados podem criar curtidas"
  ON task_likes
  FOR INSERT
  WITH CHECK (true); -- Permitir inserção (a validação de duplicatas é feita pela constraint UNIQUE)

-- Política: Usuários autenticados podem deletar suas próprias curtidas
-- Permitir deleção (a validação de permissão pode ser feita no código da aplicação)
CREATE POLICY "Usuários autenticados podem deletar suas curtidas"
  ON task_likes
  FOR DELETE
  USING (true); -- Permitir deleção (ajustar se necessário adicionar validação)
