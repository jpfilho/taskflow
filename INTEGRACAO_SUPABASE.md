# Integração com Supabase - Guia Completo

## 📋 Passos para Configuração

### 1. Obter a Chave Anon do Supabase

1. Acesse o dashboard do Supabase: https://srv750497.hstgr.cloud/project/default
2. Vá em **Settings** > **API**
3. Copie a **anon public** key
4. Abra o arquivo `lib/config/supabase_config.dart`
5. Substitua `YOUR_ANON_KEY_HERE` pela chave copiada

### 2. Criar as Tabelas no Supabase

1. No dashboard do Supabase, vá em **SQL Editor**
2. Clique em **New Query**
3. Copie todo o conteúdo do arquivo `supabase_schema.sql`
4. Cole no editor SQL
5. Clique em **Run** para executar

### 3. Instalar Dependências

Execute no terminal:
```bash
flutter pub get
```

### 4. Inicializar o Supabase no App

O arquivo `main.dart` já foi atualizado para inicializar o Supabase automaticamente.

## 🔧 Estrutura das Tabelas

### Tabela `tasks`
Armazena todas as tarefas do sistema com os seguintes campos:
- `id` (UUID): Identificador único
- `status`: ANDA, CONC, PROG
- `regional`, `divisao`, `local`, `tipo`, `ordem`, `tarefa`
- `executor`, `frota`, `coordenador`, `si`
- `data_inicio`, `data_fim`
- `observacoes`, `horas_previstas`, `horas_executadas`
- `prioridade`: ALTA, MEDIA, BAIXA
- `parent_id`: Referência para tarefa pai (subtarefas)
- `data_criacao`, `data_atualizacao`

### Tabela `gantt_segments`
Armazena os segmentos do gráfico Gantt:
- `id` (UUID): Identificador único
- `task_id`: Referência para a tarefa
- `data_inicio`, `data_fim`
- `label`, `tipo`: BEA, FER, COMP, TRN, BSL, APO, OUT, ADM

## 🔄 Funcionalidades

O `TaskService` foi refatorado para usar Supabase, mantendo compatibilidade total com a interface anterior. Todas as operações CRUD agora são assíncronas e usam o Supabase como backend.

### Operações Suportadas:
- ✅ Criar tarefa
- ✅ Atualizar tarefa
- ✅ Deletar tarefa
- ✅ Buscar todas as tarefas
- ✅ Buscar tarefa por ID
- ✅ Criar subtarefas
- ✅ Filtrar tarefas
- ✅ Buscar tarefas
- ✅ Estatísticas
- ✅ Exportar para CSV

## 🔐 Segurança (RLS)

As políticas RLS (Row Level Security) estão configuradas para permitir todas as operações. **Para produção, você deve criar políticas mais restritivas** baseadas em autenticação de usuários.

## 🐛 Troubleshooting

### Erro: "Invalid API key"
- Verifique se a chave anon foi configurada corretamente em `supabase_config.dart`

### Erro: "relation does not exist"
- Execute o script SQL em `supabase_schema.sql` no SQL Editor do Supabase

### Erro de conexão
- Verifique se a URL do Supabase está correta
- Verifique sua conexão com a internet

## 📝 Notas Importantes

1. O sistema mantém compatibilidade com dados mock. Se o Supabase não estiver configurado, o sistema usa dados locais.

2. Todas as operações são assíncronas. Certifique-se de usar `await` ao chamar métodos do `TaskService`.

3. Os segmentos do Gantt são carregados automaticamente quando uma tarefa é recuperada.

4. A exclusão de uma tarefa também exclui automaticamente seus segmentos e subtarefas (CASCADE).











