# Sistema de Perfil de Usuário

## Visão Geral

O sistema de perfil de usuário permite restringir o acesso de cada usuário apenas às tarefas relacionadas às suas regionais, divisões e segmentos configurados. Quando um usuário faz login, o sistema automaticamente filtra as tarefas exibidas baseado no seu perfil.

## Estrutura do Banco de Dados

### Tabelas Criadas

1. **usuarios_regionais**: Relacionamento many-to-many entre usuários e regionais
2. **usuarios_divisoes**: Relacionamento many-to-many entre usuários e divisões
3. **usuarios_segmentos**: Relacionamento many-to-many entre usuários e segmentos

### Script SQL

Execute o arquivo `criar_perfil_usuarios.sql` no Supabase para criar as tabelas necessárias:

```sql
-- Tabelas de relacionamento
CREATE TABLE usuarios_regionais (...)
CREATE TABLE usuarios_divisoes (...)
CREATE TABLE usuarios_segmentos (...)
```

## Como Funciona

### 1. Configuração do Perfil

Para configurar o perfil de um usuário, você precisa inserir registros nas tabelas de relacionamento:

```sql
-- Exemplo: Associar usuário a uma regional
INSERT INTO usuarios_regionais (usuario_id, regional_id)
VALUES ('uuid-do-usuario', 'uuid-da-regional');

-- Exemplo: Associar usuário a uma divisão
INSERT INTO usuarios_divisoes (usuario_id, divisao_id)
VALUES ('uuid-do-usuario', 'uuid-da-divisao');

-- Exemplo: Associar usuário a um segmento
INSERT INTO usuarios_segmentos (usuario_id, segmento_id)
VALUES ('uuid-do-usuario', 'uuid-do-segmento');
```

### 2. Comportamento Automático

Quando um usuário faz login:

1. O sistema carrega automaticamente o perfil do usuário (regionais, divisões, segmentos)
2. Todas as consultas de tarefas (`getAllTasks`, `filterTasks`, `searchTasks`) são automaticamente filtradas
3. O usuário só vê tarefas que correspondem ao seu perfil:
   - Se o usuário tem regionais configuradas, só vê tarefas dessas regionais
   - Se o usuário tem divisões configuradas, só vê tarefas dessas divisões
   - Se o usuário tem segmentos configurados, só vê tarefas desses segmentos

### 3. Regras de Filtro

- **Sem perfil configurado**: O usuário vê todas as tarefas (comportamento padrão)
- **Com perfil configurado**: O usuário vê apenas tarefas que correspondem ao seu perfil
- **Múltiplas opções**: Se o usuário tem múltiplas regionais/divisões/segmentos, ele vê tarefas de todas elas (OR lógico)

## Exemplo de Uso

### Configurar Perfil de um Usuário

```sql
-- 1. Obter o ID do usuário
SELECT id, email, nome FROM usuarios WHERE email = 'usuario@exemplo.com';

-- 2. Obter os IDs das regionais, divisões e segmentos desejados
SELECT id, regional FROM regionais WHERE regional = 'Norte';
SELECT id, divisao FROM divisoes WHERE divisao = 'Manutenção';
SELECT id, segmento FROM segmentos WHERE segmento = 'Rodovias';

-- 3. Associar o usuário ao perfil
INSERT INTO usuarios_regionais (usuario_id, regional_id)
VALUES ('uuid-usuario', 'uuid-regional-norte');

INSERT INTO usuarios_divisoes (usuario_id, divisao_id)
VALUES ('uuid-usuario', 'uuid-divisao-manutencao');

INSERT INTO usuarios_segmentos (usuario_id, segmento_id)
VALUES ('uuid-usuario', 'uuid-segmento-rodovias');
```

### Verificar Perfil de um Usuário

```sql
-- Ver regionais do usuário
SELECT u.email, r.regional
FROM usuarios u
JOIN usuarios_regionais ur ON u.id = ur.usuario_id
JOIN regionais r ON ur.regional_id = r.id
WHERE u.email = 'usuario@exemplo.com';

-- Ver divisões do usuário
SELECT u.email, d.divisao
FROM usuarios u
JOIN usuarios_divisoes ud ON u.id = ud.usuario_id
JOIN divisoes d ON ud.divisao_id = d.id
WHERE u.email = 'usuario@exemplo.com';

-- Ver segmentos do usuário
SELECT u.email, s.segmento
FROM usuarios u
JOIN usuarios_segmentos us ON u.id = us.usuario_id
JOIN segmentos seg ON us.segmento_id = seg.id
WHERE u.email = 'usuario@exemplo.com';
```

## Implementação Técnica

### Modelo Usuario

O modelo `Usuario` agora inclui:
- `regionalIds`: Lista de IDs das regionais permitidas
- `divisaoIds`: Lista de IDs das divisões permitidas
- `segmentoIds`: Lista de IDs dos segmentos permitidos
- `regionais`: Lista de nomes das regionais (para exibição)
- `divisoes`: Lista de nomes das divisões (para exibição)
- `segmentos`: Lista de nomes dos segmentos (para exibição)

### Métodos de Verificação

- `temAcessoRegional(String? regionalId)`: Verifica se o usuário tem acesso a uma regional
- `temAcessoDivisao(String? divisaoId)`: Verifica se o usuário tem acesso a uma divisão
- `temAcessoSegmento(String? segmentoId)`: Verifica se o usuário tem acesso a um segmento
- `temPerfilConfigurado()`: Verifica se o usuário tem algum perfil configurado

### TaskService

O `TaskService` agora aplica automaticamente os filtros de perfil em:
- `getAllTasks()`: Filtra todas as tarefas baseado no perfil
- `filterTasks()`: Aplica filtros de perfil além dos filtros fornecidos
- `searchTasks()`: Aplica filtros de perfil na busca

## Notas Importantes

1. **Sem perfil = acesso total**: Se um usuário não tem perfil configurado, ele vê todas as tarefas
2. **Filtros automáticos**: Os filtros são aplicados automaticamente, não é necessário configurar nada no código
3. **Performance**: Os filtros são aplicados após carregar as tarefas do banco, garantindo que apenas tarefas relevantes sejam processadas
4. **Segurança**: Os filtros são aplicados no nível do serviço, garantindo que mesmo se alguém tentar acessar diretamente, os dados serão filtrados

## Próximos Passos

Para criar uma interface de gerenciamento de perfis de usuário, você pode:

1. Criar uma tela de "Gerenciamento de Usuários" em `ConfiguracaoView`
2. Permitir seleção múltipla de regionais, divisões e segmentos
3. Salvar as associações nas tabelas de relacionamento






