## Módulo Documents (TaskFlow)

### Visão geral
- Upload e gestão de documentos (PDF/DOCX/XLSX/PPTX/TXT/ZIP/imagens).
- Hierarquia idêntica ao álbum de mídia: segment → equipment → room + regional/divisão/local.
- Status dinâmico em `status_documents`.
- Bucket privado `taskflow-documents` com Signed URL (1 ano).
- Versionamento opcional via `document_versions`.

### Passos de setup
1. **Executar migrations**  
   ```sql
   \i lib/features/documents/migrations/EXECUTAR_MIGRATIONS_DOCUMENTS.sql
   ```
   Isso cria tabelas, RLS e storage policies (bucket `taskflow-documents`).

2. **Criar bucket (se necessário)**  
   Dashboard Supabase → Storage → New Bucket  
   - Nome: `taskflow-documents`  
   - Public bucket: desmarcado (privado)  
   - Tipos permitidos: PDF/DOCX/XLSX/PPTX/TXT/ZIP/JPEG/PNG/WEBP  
   - Limite sugerido: 100 MB

3. **Autenticação**  
   O login é feito internamente no Flutter (não no Supabase Auth). Certifique-se de passar o `userId` correto no upload para que os paths respeitem o prefixo `{userId}/...`.

4. **Rotas/UI**  
   - `DocumentsPage`: lista, filtros básicos e acesso ao detalhe.  
   - `DocumentDetailPage`: metadados, status e versões.  
   - `DocumentUploadPage`: fluxo de upload (placeholder usa dummy file; integrar file picker).  
   - `StatusDocumentsPage`: lista de status dinâmicos.

### Repositório / APIs principais
- `SupabaseDocumentsRepository`
  - `getDocuments`, `getDocumentById`
  - `uploadAndCreateDocument` (gera path, faz upload, cria documento + versão inicial)
  - `uploadNewVersion` (nova versão + atualização do documento)
  - `listStatuses`

### Estrutura de storage
`{userId}/{segmentId}/{equipmentId}/{roomId}/{yyyy}/{mm}/{uuid}.{ext}`

### Próximos passos sugeridos
- Integrar file picker real e `url_launcher` para download/preview.
- Conectar filtros de hierarquia/perfil usando os helpers já existentes do módulo de mídia.
- Restringir criação/edição de `status_documents` a admins quando a role estiver disponível.
