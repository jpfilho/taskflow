# 📋 Instruções de Execução das Migrations

## 🎯 Objetivo
Integrar a tabela `status_albums` com o módulo de Media Albums, permitindo que os status sejam cadastrados e gerenciados com cores customizadas.

## 📝 Arquivos SQL

### Opção 1: Arquivo Consolidado (Recomendado)
Execute o arquivo **`EXECUTAR_TODAS_MIGRATIONS.sql`** que contém todas as migrations na ordem correta.

### Opção 2: Arquivos Separados
Execute na ordem:

1. **`create_status_albums_table.sql`** - Cria a tabela de status
2. **`ADICIONAR_STATUS_ALBUM_ID.sql`** - Adiciona a coluna `status_album_id` em `media_images`

## 🚀 Como Executar

### Via Supabase Dashboard

1. Acesse o **Supabase Dashboard**
2. Vá em **SQL Editor**
3. Clique em **New Query**
4. Cole o conteúdo do arquivo `EXECUTAR_TODAS_MIGRATIONS.sql`
5. Clique em **Run** (ou pressione `Ctrl+Enter`)

### Via Supabase CLI (se configurado)

```bash
supabase db execute -f lib/features/media_albums/migrations/EXECUTAR_TODAS_MIGRATIONS.sql
```

## ✅ Verificação Pós-Execução

Após executar as migrations, verifique:

### 1. Tabela criada
```sql
SELECT * FROM status_albums;
```

Deve retornar 3 status padrão:
- **OK** (verde: #10B981)
- **Atenção** (vermelho: #EF4444)
- **Revisão** (laranja: #F59E0B)

### 2. Coluna adicionada
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'media_images' 
  AND column_name = 'status_album_id';
```

### 3. Dados migrados
```sql
SELECT 
    COUNT(*) as total_imagens,
    COUNT(status_album_id) as com_status_vinculado
FROM media_images;
```

## 🔧 O que as Migrations Fazem

### Parte 1: Criar Tabela `status_albums`
- Cria tabela para cadastro de status
- Adiciona índices para performance
- Configura RLS (Row Level Security)
- Cria trigger para `updated_at`

### Parte 2: Integrar com `media_images`
- Adiciona coluna `status_album_id` (FK para `status_albums`)
- Cria índice na nova coluna
- Cria 3 status padrão (OK, Atenção, Revisão)
- Migra dados existentes: vincula status antigos (TEXT) aos novos (UUID)

## 📊 Status Padrão Criados

| Nome | Cor de Fundo | Cor do Texto | Ordem |
|------|--------------|--------------|-------|
| OK | #10B981 (verde) | #FFFFFF (branco) | 1 |
| Atenção | #EF4444 (vermelho) | #FFFFFF (branco) | 2 |
| Revisão | #F59E0B (laranja) | #FFFFFF (branco) | 3 |

## ⚠️ Observações

1. **Compatibilidade**: A coluna `status` (TEXT) antiga é mantida para compatibilidade
2. **Migração Gradual**: A coluna `status_album_id` é nullable, permitindo migração gradual
3. **RLS**: As políticas RLS permitem acesso público (similar ao padrão do sistema)
4. **Dados Existentes**: Imagens existentes são automaticamente vinculadas aos status padrão

## 🎨 Próximos Passos

Após executar as migrations:

1. ✅ Acesse **Configurações → Sistema → Status de Álbuns**
2. ✅ Cadastre novos status ou edite os existentes
3. ✅ As cores e nomes aparecerão automaticamente nos filtros e badges
4. ✅ Ao criar/editar imagens, selecione o status da tabela

## 🐛 Troubleshooting

### Erro: "relation status_albums does not exist"
- Execute primeiro a **Parte 1** (criar tabela)

### Erro: "column status_album_id already exists"
- A coluna já foi adicionada, pode pular essa parte

### Erro: "duplicate key value violates unique constraint"
- Os status padrão já existem, pode pular a criação

### Imagens não aparecem com status
- Verifique se a migration de dados foi executada:
  ```sql
  SELECT COUNT(*) FROM media_images WHERE status_album_id IS NULL;
  ```
