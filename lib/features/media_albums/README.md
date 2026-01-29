# Módulo Álbuns de Mídia - TaskFlow

## Visão Geral

Módulo completo para registro e visualização de imagens técnicas relacionadas a ativos (Segmentos > Equipamentos > Salas).

## Estrutura

```
lib/features/media_albums/
├── data/
│   ├── models/
│   │   ├── segment.dart
│   │   ├── equipment.dart
│   │   ├── room.dart
│   │   └── media_image.dart
│   └── repositories/
│       └── supabase_media_repository.dart
├── application/
│   └── controllers/
│       ├── upload_controller.dart
│       └── gallery_controller.dart
├── presentation/
│   ├── pages/
│   │   ├── gallery_page.dart
│   │   ├── upload_page.dart
│   │   ├── detail_page.dart
│   │   └── edit_dialog.dart
│   └── widgets/
│       ├── filter_bar.dart
│       ├── media_grid.dart
│       ├── media_card.dart
│       ├── album_group_list.dart
│       └── status_badge.dart
├── util/
│   ├── path_builder.dart
│   └── validators.dart
└── migrations/
    └── create_media_albums_tables.sql
```

## Funcionalidades

### 1. Galeria de Imagens
- Visualização em grade ou agrupada por hierarquia
- Busca em tempo real (título, descrição, tags)
- Filtros: Segmento, Equipamento, Sala, Status
- Paginação infinita
- Visualização de detalhes com zoom

### 2. Upload de Imagens
- Seleção múltipla de imagens (galeria/câmera)
- Preview das imagens selecionadas
- Formulário completo: título, descrição, tags, hierarquia, status
- Progresso de upload por arquivo
- Validação de campos obrigatórios

### 3. Detalhes da Imagem
- Visualização em tela cheia com zoom/pan
- Metadados completos
- Edição de informações
- Exclusão (com confirmação)
- Compartilhamento

## Banco de Dados

### Tabelas

1. **segments** - Segmentos
2. **equipments** - Equipamentos (FK para segments)
3. **rooms** - Salas (FK para equipments)
4. **media_images** - Imagens de mídia

### Storage

- **Bucket**: `taskflow-media` (privado)
- **Estrutura de pastas**: `{userId}/{segmentId}/{equipmentId}/{roomId}/{yyyy}/{mm}/{uuid}.jpg`
- **URLs**: Signed URLs (válidas por 1 ano, renovadas automaticamente)
- **Limite**: 50 MB por arquivo
- **Tipos permitidos**: JPEG, PNG, WEBP, GIF

**Políticas de segurança**:
- ✅ Usuários autenticados podem ler qualquer arquivo
- ✅ Usuários só podem fazer upload em suas próprias pastas (`{userId}/...`)
- ✅ Usuários só podem deletar arquivos em suas próprias pastas

### RLS Policies

- **segments/equipments/rooms**: Leitura para autenticados, escrita para todos (TODO: restringir para admins)
- **media_images**: Leitura para autenticados, escrita/deleção apenas para o criador

## Instalação

### 1. Executar Migração SQL

Execute o arquivo `migrations/create_media_albums_tables.sql` no Supabase SQL Editor.

### 2. Configurar Storage

**IMPORTANTE**: O storage é obrigatório para o módulo funcionar!

1. **Criar o bucket** no Supabase Dashboard:
   - Vá em **Storage** > **Buckets** > **New Bucket**
   - Nome: `taskflow-media`
   - **Public bucket**: **DESMARCADO** (privado)
   - File size limit: 50 MB
   - Allowed MIME types: `image/jpeg, image/jpg, image/png, image/webp, image/gif`

2. **Executar políticas de storage**:
   - Execute o arquivo `migrations/create_storage_policies.sql` no SQL Editor
   - Isso cria as políticas RLS para o storage

3. **Verificar**:
   ```sql
   -- Verificar bucket
   SELECT * FROM storage.buckets WHERE id = 'taskflow-media';
   
   -- Verificar políticas
   SELECT * FROM pg_policies 
   WHERE tablename = 'objects' 
   AND policyname LIKE 'taskflow_media%';
   ```

### 3. Dependências

As dependências já estão no `pubspec.yaml`:
- `uuid: ^4.5.1`
- `intl: ^0.19.0`

**Ver documentação completa do storage**: `migrations/README_STORAGE.md`

## Uso

O módulo está integrado na sidebar do TaskFlow:
- Ícone: `Icons.photo_library`
- Índice: `23`
- Nome: "Álbuns de Imagens"

## Próximos Passos (TODOs)

1. Implementar geração de thumbnails client-side
2. Adicionar verificação de role admin para escrita em segments/equipments/rooms
3. Implementar cache local de imagens
4. Adicionar suporte a anotações nas imagens
5. Implementar busca avançada com múltiplos critérios
6. Adicionar exportação de imagens em lote

## Notas Técnicas

- Usa `ChangeNotifier` para gerenciamento de estado (não Riverpod)
- Compatível com Flutter Web e Mobile
- Responsivo (layout adapta-se ao tamanho da tela)
- Usa `cached_network_image` para cache de imagens
- Usa `photo_view` para visualização com zoom
