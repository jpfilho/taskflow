# Status de Álbuns - Setup e Uso

## 📋 Descrição

Módulo para cadastro e gerenciamento de status de álbuns de imagens com cores customizadas. Permite definir status personalizados (ex: "OK", "Atenção", "Revisão") com cores de fundo e texto específicas.

## 🗄️ Migração SQL

### 1. Executar a Migration

Execute o arquivo SQL no Supabase SQL Editor:

```sql
-- Arquivo: lib/features/media_albums/migrations/create_status_albums_table.sql
```

Ou execute diretamente:

```bash
# Via Supabase CLI (se configurado)
supabase db execute -f lib/features/media_albums/migrations/create_status_albums_table.sql
```

### 2. Verificar Tabela Criada

Após executar a migration, verifique se a tabela foi criada:

```sql
SELECT * FROM status_albums;
```

## 📱 Acesso à Tela

A tela de cadastro de Status de Álbuns está disponível em:

**Configurações → Sistema → Status de Álbuns**

Ou navegue diretamente para:
- Menu lateral → Configurações
- Seção "Sistema"
- Card "Status de Álbuns"

## 🎨 Funcionalidades

### Cadastro de Status

1. **Nome** (obrigatório): Nome do status (ex: "OK", "Atenção", "Revisão")
2. **Descrição** (opcional): Descrição detalhada do status
3. **Cor de Fundo**: Cor de fundo do badge em hexadecimal (ex: #FF5733)
4. **Cor do Texto**: Cor do texto do badge em hexadecimal (ex: #FFFFFF)
5. **Ordem**: Ordem de exibição (número inteiro, padrão: 0)
6. **Ativo**: Toggle para ativar/desativar o status

### Visualizações

- **Lista (Cards)**: Visualização em cards com preview da cor
- **Tabela**: Visualização em tabela com todas as informações

### Ações Disponíveis

- ✅ **Criar**: Adicionar novo status
- ✏️ **Editar**: Modificar status existente
- 📋 **Duplicar**: Criar cópia de um status
- 🗑️ **Excluir**: Remover status (com confirmação)

## 🔧 Integração com Media Albums

Os status cadastrados podem ser usados no módulo de Media Albums. Para integrar:

1. Atualize o enum `MediaImageStatus` para usar os status da tabela `status_albums`
2. Ou crie um mapeamento entre os status cadastrados e os status do enum

## 📝 Exemplo de Uso

### Criar um Status

1. Acesse **Configurações → Sistema → Status de Álbuns**
2. Clique no botão **+** (Adicionar)
3. Preencha:
   - Nome: "Aprovado"
   - Descrição: "Imagem aprovada para uso"
   - Cor de Fundo: #10B981 (verde)
   - Cor do Texto: #FFFFFF (branco)
   - Ordem: 1
   - Ativo: Sim
4. Clique em **Criar Status**

### Editar um Status

1. Na lista de status, clique no ícone de **Editar** (✏️)
2. Modifique os campos desejados
3. Clique em **Salvar Alterações**

## 🎨 Seletor de Cores

O seletor de cores oferece:

- **Sliders HSV**: Ajuste fino de Matiz, Saturação e Brilho
- **Cores Rápidas**: Paleta pré-definida de cores comuns
- **Preview**: Visualização em tempo real da cor selecionada
- **Código Hexadecimal**: Exibição do código da cor (ex: #FF5733)

## 🔐 Permissões

- **RLS Habilitado**: A tabela usa Row Level Security
- **Leitura**: Todos os usuários autenticados podem ler
- **Escrita**: Usuários autenticados podem criar/editar/deletar
- **Criador**: Campo `created_by` referencia `usuarios.id`

## 📊 Estrutura da Tabela

```sql
status_albums
├── id (UUID, PK)
├── nome (VARCHAR(100), UNIQUE, NOT NULL)
├── descricao (TEXT, NULLABLE)
├── cor_fundo (VARCHAR(7), NULLABLE) -- Hexadecimal
├── cor_texto (VARCHAR(7), NULLABLE) -- Hexadecimal
├── ativo (BOOLEAN, DEFAULT true)
├── ordem (INTEGER, DEFAULT 0)
├── created_at (TIMESTAMP)
├── updated_at (TIMESTAMP)
└── created_by (UUID, FK -> usuarios.id)
```

## 🚀 Próximos Passos

1. Integrar os status cadastrados com o módulo de Media Albums
2. Atualizar `MediaImageStatus` para usar status dinâmicos
3. Adicionar validação de cores (contraste, acessibilidade)
4. Adicionar ícones personalizados por status
