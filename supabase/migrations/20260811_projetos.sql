-- Habilita extensão pgcrypto se ainda não existir
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. PROJETOS
CREATE TABLE IF NOT EXISTS projetos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo TEXT,
  nome TEXT NOT NULL,
  descricao TEXT,
  categoria TEXT,
  tipo TEXT,
  status TEXT DEFAULT 'EM PLANEJAMENTO',
  prioridade TEXT DEFAULT 'MEDIA',
  regional_id UUID REFERENCES regionais(id) ON DELETE SET NULL,
  divisao_id UUID REFERENCES divisoes(id) ON DELETE SET NULL,
  segmento_id UUID REFERENCES segmentos(id) ON DELETE SET NULL,
  local_id UUID REFERENCES locais(id) ON DELETE SET NULL,
  coordenador_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  responsavel_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  data_inicio_prevista DATE,
  data_fim_prevista DATE,
  data_inicio_real DATE,
  data_fim_real DATE,
  progresso NUMERIC DEFAULT 0,
  orcamento_previsto NUMERIC,
  orcamento_realizado NUMERIC,
  created_by UUID REFERENCES usuarios(id),
  updated_by UUID REFERENCES usuarios(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- 2. PROJETO MEMBROS
CREATE TABLE IF NOT EXISTS projeto_membros (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id UUID NOT NULL REFERENCES projetos(id) ON DELETE CASCADE,
  usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  papel TEXT NOT NULL,
  pode_visualizar BOOLEAN DEFAULT TRUE,
  pode_editar BOOLEAN DEFAULT FALSE,
  pode_planejar BOOLEAN DEFAULT FALSE,
  pode_aprovar BOOLEAN DEFAULT FALSE,
  pode_encerrar BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(projeto_id, usuario_id)
);

-- 3. MACROETAPAS
CREATE TABLE IF NOT EXISTS projeto_macroetapas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id UUID NOT NULL REFERENCES projetos(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  descricao TEXT,
  ordem INTEGER DEFAULT 0,
  data_inicio_prevista DATE,
  data_fim_prevista DATE,
  data_inicio_real DATE,
  data_fim_real DATE,
  status TEXT DEFAULT 'PENDENTE',
  progresso NUMERIC DEFAULT 0,
  peso NUMERIC DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- 4. ETAPAS
CREATE TABLE IF NOT EXISTS projeto_etapas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id UUID NOT NULL REFERENCES projetos(id) ON DELETE CASCADE,
  macroetapa_id UUID NOT NULL REFERENCES projeto_macroetapas(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  descricao TEXT,
  ordem INTEGER DEFAULT 0,
  data_inicio_prevista DATE,
  data_fim_prevista DATE,
  data_inicio_real DATE,
  data_fim_real DATE,
  status TEXT DEFAULT 'PENDENTE',
  progresso NUMERIC DEFAULT 0,
  peso NUMERIC DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- 5. ATIVIDADES
CREATE TABLE IF NOT EXISTS projeto_atividades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id UUID NOT NULL REFERENCES projetos(id) ON DELETE CASCADE,
  macroetapa_id UUID NOT NULL REFERENCES projeto_macroetapas(id) ON DELETE CASCADE,
  etapa_id UUID NOT NULL REFERENCES projeto_etapas(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  descricao TEXT,
  ordem INTEGER DEFAULT 0,
  data_inicio_prevista TIMESTAMPTZ,
  data_fim_prevista TIMESTAMPTZ,
  data_inicio_real TIMESTAMPTZ,
  data_fim_real TIMESTAMPTZ,
  status TEXT DEFAULT 'PENDENTE',
  progresso NUMERIC DEFAULT 0,
  peso NUMERIC DEFAULT 1,
  prioridade TEXT DEFAULT 'MEDIA',
  criticidade TEXT DEFAULT 'MEDIA',
  bloqueada BOOLEAN DEFAULT FALSE,
  motivo_bloqueio TEXT,
  executor_id UUID REFERENCES executores(id) ON DELETE SET NULL,
  equipe_id UUID REFERENCES equipes(id) ON DELETE SET NULL,
  horas_previstas NUMERIC,
  horas_realizadas NUMERIC,
  task_id UUID REFERENCES tasks(id) ON DELETE SET NULL, -- Integração opcional
  created_by UUID REFERENCES usuarios(id),
  updated_by UUID REFERENCES usuarios(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- 6. DEPENDENCIAS
CREATE TABLE IF NOT EXISTS projeto_atividade_dependencias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id UUID NOT NULL REFERENCES projetos(id) ON DELETE CASCADE,
  atividade_predecessora_id UUID NOT NULL REFERENCES projeto_atividades(id) ON DELETE CASCADE,
  atividade_sucessora_id UUID NOT NULL REFERENCES projeto_atividades(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN ('FS', 'SS', 'FF', 'SF')),
  lag_dias NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- 7. MARCOS
CREATE TABLE IF NOT EXISTS projeto_marcos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id UUID NOT NULL REFERENCES projetos(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  descricao TEXT,
  data_prevista DATE,
  data_real DATE,
  status TEXT DEFAULT 'PENDENTE',
  ordem INTEGER DEFAULT 0,
  criticidade TEXT DEFAULT 'ALTA',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- 8. RISCOS
CREATE TABLE IF NOT EXISTS projeto_riscos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  projeto_id UUID NOT NULL REFERENCES projetos(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  descricao TEXT,
  categoria TEXT,
  probabilidade TEXT CHECK (probabilidade IN ('Baixa', 'Média', 'Alta')),
  impacto TEXT CHECK (impacto IN ('Baixo', 'Médio', 'Alto')),
  criticidade TEXT CHECK (criticidade IN ('Baixa', 'Média', 'Alta', 'Crítica')),
  responsavel_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  plano_mitigacao TEXT,
  plano_contingencia TEXT,
  status TEXT DEFAULT 'IDENTIFICADO',
  data_identificacao DATE,
  data_limite DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- TRIGGERS PARA UPDATED_AT
-- Reutiliza a função existente 'update_updated_at_column()'
CREATE TRIGGER update_projetos_updated_at BEFORE UPDATE ON projetos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_projeto_membros_updated_at BEFORE UPDATE ON projeto_membros FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_projeto_macroetapas_updated_at BEFORE UPDATE ON projeto_macroetapas FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_projeto_etapas_updated_at BEFORE UPDATE ON projeto_etapas FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_projeto_atividades_updated_at BEFORE UPDATE ON projeto_atividades FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_projeto_atividade_dependencias_updated_at BEFORE UPDATE ON projeto_atividade_dependencias FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_projeto_marcos_updated_at BEFORE UPDATE ON projeto_marcos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_projeto_riscos_updated_at BEFORE UPDATE ON projeto_riscos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- INDICES SUGERIDOS
CREATE INDEX idx_projetos_regional ON projetos(regional_id);
CREATE INDEX idx_projetos_status ON projetos(status);
CREATE INDEX idx_projetos_deleted_at ON projetos(deleted_at);
CREATE INDEX idx_projeto_atividades_etapa ON projeto_atividades(etapa_id);
CREATE INDEX idx_projeto_atividades_executor ON projeto_atividades(executor_id);
CREATE INDEX idx_projeto_membros_usuario ON projeto_membros(usuario_id);

-- HABILITA RLS
ALTER TABLE projetos ENABLE ROW LEVEL SECURITY;
ALTER TABLE projeto_membros ENABLE ROW LEVEL SECURITY;
ALTER TABLE projeto_macroetapas ENABLE ROW LEVEL SECURITY;
ALTER TABLE projeto_etapas ENABLE ROW LEVEL SECURITY;
ALTER TABLE projeto_atividades ENABLE ROW LEVEL SECURITY;
ALTER TABLE projeto_atividade_dependencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE projeto_marcos ENABLE ROW LEVEL SECURITY;
ALTER TABLE projeto_riscos ENABLE ROW LEVEL SECURITY;

-- POLITICAS RLS PADRÃO PARA USUÁRIOS AUTENTICADOS (Mesmo nível que executores/equipes atuais)
CREATE POLICY "RLS projetos" ON projetos FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "RLS projeto_membros" ON projeto_membros FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "RLS projeto_macroetapas" ON projeto_macroetapas FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "RLS projeto_etapas" ON projeto_etapas FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "RLS projeto_atividades" ON projeto_atividades FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "RLS projeto_atividade_dependencias" ON projeto_atividade_dependencias FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "RLS projeto_marcos" ON projeto_marcos FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "RLS projeto_riscos" ON projeto_riscos FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
