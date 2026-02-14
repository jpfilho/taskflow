# Análise dos scripts de deploy (.ps1)

## Objetivo

Identificar qual script de deploy **coloca versão sem precisar limpar o cache** do navegador.

---

## Script recomendado: **deploy-task2026.ps1**

Este é o mais atualizado e o único que implementa **cache-busting completo** + desativação do service worker.

### O que ele faz para evitar cache

1. **Cache-busting em `index.html`**  
   Adiciona `?v=yyyyMMdd_HHmmss` em:
   - `main.dart.js`
   - `flutter.js`
   - `canvaskit.wasm`
   - `flutter_service_worker.js`

2. **Service worker desabilitado**
   - Remove a chamada `navigator.serviceWorker.register(...)` em `flutter.js`
   - Substitui o conteúdo de `flutter_service_worker.js` por um comentário  
   Assim o navegador não fica preso a uma versão antiga em cache do SW.

3. **Referências ao SW com versão**
   - Em `flutter.js`: referência ao SW com `?v=timestamp`
   - Em `main.dart.js`: idem, se existir referência ao SW

4. **Arquivo `version.txt`**
   - Criado em `build/web/version.txt` com o mesmo timestamp  
   Útil para conferir no servidor qual versão está publicada.

5. **`.htaccess`**
   - `index.html`, `flutter_service_worker.js` e `version.txt`: `Cache-Control: no-store`
   - Assets (js, wasm, etc.): cache longo com `immutable`

6. **Verificação pós-deploy**
   - Lê `version.txt` no servidor e compara com o timestamp do build.

### Uso

```powershell
# Build + deploy (com flutter clean)
.\deploy-task2026.ps1

# Só transferir (usar build já existente)
.\deploy-task2026.ps1 -NoBuild
```

### Requisitos

- Chave SSH configurada para `root@212.85.0.249`
- Opcional: `rsync` no PATH (senão usa `scp`)

---

## Comparação com outros scripts

| Script               | Cache-busting      | SW desabilitado | .htaccess | Versão sem limpar cache |
|---------------------|--------------------|-----------------|-----------|---------------------------|
| **deploy-task2026.ps1** | Completo (4 arquivos) | Sim             | Sim       | **Sim**                   |
| deploy_agora.ps1    | Completo           | Sim             | Sim       | Sim (mas tem senha no código) |
| deploy_rapido.ps1   | Só main.dart.js    | Não             | Não       | Não                       |
| deploy_completo.ps1 | Só main.dart.js    | Não             | Não       | Não                       |
| deploy_final.ps1    | Só main.dart.js    | Não             | Não       | Não                       |

Scripts que **só** alteram `main.dart.js` no `index.html` não evitam cache do service worker nem de outros recursos; por isso ainda pode ser necessário Ctrl+Shift+R ou limpar cache.

---

## Resumo

- **Use:** `deploy-task2026.ps1` para deploy com versão que dispensa limpar cache.
- **Evite** como “deploy com versão”: `deploy_rapido.ps1`, `deploy_completo.ps1`, `deploy_final.ps1` (cache-busting incompleto e SW ativo).
- **deploy_agora.ps1** tem lógica parecida com deploy-task2026.ps1, mas contém senha em texto no script; para produção, prefira deploy-task2026.ps1 com chave SSH.
