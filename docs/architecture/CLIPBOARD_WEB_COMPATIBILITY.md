# TaskFlow — Compatibilidade e Resiliência da Área de Transferência (Clipboard Web Hardening)

Este documento descreve a arquitetura de área de transferência (Clipboard) do TaskFlow, os desafios em ambientes Web produtivos (HTTP vs. HTTPS / Iframes) e o padrão adotado para garantir robustez multiplataforma sem regressões funcionais.

---

## 1. Problema Identificado

Ao executar a aplicação em ambientes de produção Web servidos por HTTP comum (sem certificado SSL/HTTPS ativo), acessados por IP direto de intranet ou dentro de `<iframe>` corporativo, cliques nos botões de cópia (Nota SAP, Ordem, SI, AT, Links, etc.) falhavam com a exceção:

```text
PlatformException(copy_fail, Clipboard is not available in the context., null, null)
```

### Por que funcionava no ambiente de desenvolvimento local?
No desenvolvimento local (`localhost` ou `127.0.0.1`), navegadores consideram a origem como um **Secure Context** por exceção de desenvolvimento, concedendo acesso livre à API moderna `navigator.clipboard.writeText`.

### A limitação em Produção (Secure Context Requirement)
Pela especificação W3C das Web APIs modernas, a `Clipboard API` assíncrona (`navigator.clipboard`) é estritamente restrita a **Secure Contexts** (HTTPS). Em qualquer origem HTTP não segura, a propriedade `navigator.clipboard` fica `undefined` ou rejeita qualquer operação de leitura/escrita.

---

## 2. Arquitetura da Solução

O TaskFlow adota uma arquitetura em camadas com compilação condicional limpa, centralizada na classe `ClipboardHelper`:

```text
               Chamada de UI: ClipboardHelper.copy(text)
                                   │
                                   ▼
                   Tentativa Primária (API Moderna)
                   Clipboard.setData(ClipboardData(...))
                                   │
                    ┌──────────────┴──────────────┐
                    │ Sucesso                     │ Erro / PlatformException
                    ▼                             ▼
               Retorna true           Está em ambiente Web?
                                       │                │
                                    Sim│                │Não
                                       ▼                ▼
                               Fallback Legado    Retorna false
                             copyToClipboardWeb
                                       │
                      ┌────────────────┴────────────────┐
                      │ queryCommandSupported('copy')?  │
                      ▼ Não                             ▼ Sim
                 Retorna false                  Cria TextArea invisível
                                                fora da tela (-9999px)
                                                Foca, Seleciona e executa
                                                document.execCommand('copy')
                                                        │
                                                        ▼
                                                Cleanup no finally (remove textarea)
                                                Restaura foco anterior
                                                Retorna resultado real (true/false)
```

### Arquivos do Módulo
- `lib/utils/clipboard_helper.dart`: Fachada universal e métodos de feedback visual (`copyAndNotify`).
- `lib/utils/clipboard_helper_web.dart`: Fallback de compatibilidade legado baseado em DOM (`execCommand('copy')`).
- `lib/utils/clipboard_helper_stub.dart`: Stub para plataformas nativas (Android, iOS, macOS, Windows, Linux), garantindo que nenhuma biblioteca `dart:html` seja referenciada ou importada em builds nativas.

---

## 3. Diretrizes de Segurança e Boas Práticas

1. **API Moderna Primeiro**: Sempre tenta `Clipboard.setData()` primeiramente.
2. **Detecção de Capacidade no Fallback**: Antes de criar elementos no DOM, verifica `html.document.queryCommandSupported('copy')`.
3. **Prevenção de Efeitos Colaterais Visuais**:
   - O `TextAreaElement` temporário possui posição fixa (`position: fixed`), coordenadas fora do viewport (`top: -9999px`, `left: -9999px`), opacidade zero e dimensões neutras, evitando qualquer *layout shift*, *scroll jump* ou flash visual.
4. **Cleanup Obrigatório**: A remoção do elemento temporário do DOM é encapsulada em um bloco `try ... finally`, assegurando que nenhum nó órfão permaneça no documento.
5. **Restauração de Foco**: O elemento focado antes da ação (`document.activeElement`) é capturado e refocado após o processo, preservando a navegação por teclado e acessibilidade.
6. **Integridade de Feedback**: `copyAndNotify` valida o retorno booleano real da operação antes de exibir a mensagem de sucesso ao usuário. Mensagens amigáveis são exibidas sem expor stack traces técnicos em tela.
7. **Tratamento de Strings Vazias**: Retorna `false` imediatamente para `""` ou texto em branco, sem acionar canais nativos ou manipular DOM desnecessariamente.

---

## 4. Limitações de Ambientes

- **HTTP / Intranet**: O fallback DOM estende significativamente a compatibilidade em servidores legados HTTP, mas como `execCommand` é uma API legada/deprecada, a longo prazo navegadores podem restringir ainda mais o acesso à área de transferência.
- **Iframes**: A operação dentro de iframes depende das diretivas de política de permissão do container pai (ex: atributo `allow="clipboard-write"` na tag `<iframe>`).
- **Recomendação Futura**: Recomenda-se disponibilizar o TaskFlow Web sempre sob protocolo **HTTPS** mesmo em redes internas corporativas, garantindo o funcionamento nativo da Clipboard API e das futuras APIs restritas a Secure Contexts.

---

## 5. Matriz de Testes

A suíte de testes em `test/utils/clipboard_helper_test.dart` cobre:
- Cópia com texto vazio (retorna `false` sem invocar canais de plataforma).
- Cópia com sucesso pela API de plataforma.
- Falha na API de plataforma sem quebra e com retorno `false`.
- Notificação de sucesso personalizada e padrão.
- Notificação de erro e contenção de falso positivo.
