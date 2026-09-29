# 39 - Densidade Global de Interface (Global UI Density)

## 1. Visão Geral e Contexto
O TaskFlow é utilizado em diversos formatos de hardware — desde monitores ultrawide (1920x1080+) até notebooks de 13", 14" e 15.6" com resoluções como 1366x768 ou 1920x1080 com escalonamento de tela do SO (125%/150%). Em telas compactas, a área útil vertical é um recurso crítico para a visualização de painéis densos, como tabelas operacionais, formulários e agendamento de recursos.

Para otimizar o aproveitamento de espaço sem quebrar acessibilidade nem causar regressões visuais, o TaskFlow introduz o sistema de **Densidade Global Controlada**, com três modos selecionáveis pelo usuário e persistidos localmente.

---

## 2. Princípios de Engenharia e Regras de Ouro
1. **Padrão Sem Regressão (`comfortable = baseline`)**: O modo padrão do sistema reproduz 100% das dimensões, espaçamentos e comportamentos já homologados do TFDS.
2. **Separação entre Densidade e Zoom**: Densidade **não é zoom óptico**. A tipografia base, tamanhos de fonte semânticos e espessuras de borda permanecem estáveis; o ganho de espaço provém da redução de paddings, margens e alturas de controles/linhas de tabela.
3. **Geometrias Críticas Protegidas (0 Pixel Drift)**:
   - `TaskTable`: Linhas, sublinhas, larguras de colunas e sincronização de rolagem permanecem inalteradas.
   - `GanttChart`: Relações data-para-pixel, pixel-para-data, alturas de barra e cabeçalho temporal permanecem inalteradas.
   - `Resource Schedule` (Team & Fleet): Alturas de linha e alinhamento split-screen permanecem inalteradas.
   - O ganho nessas telas provém de **toolbars, headers, filtros e cards externos compactados**.
4. **Segurança de Toque em Mobile**: Em dispositivos móveis ou telas tácteis, os componentes respeitam limites mínimos de acessibilidade (touch target >= 40x40px).
5. **Troca em Tempo Real (Live Switch)**: A alternância de densidade reflete instantaneamente em toda a aplicação sem exigir recarregamento ou reinicialização.

---

## 3. Especificação dos Modos de Densidade

| Métrica | Confortável (`comfortable`) | Compacta (`compact`) | Densa (`dense`) |
| :--- | :--- | :--- | :--- |
| **Público-Alvo** | Monitores grandes / Desktop padrão | Notebooks (13"–15.6", 1366x768) | Desktop intensivo em dados |
| **Aproveitamento** | Baseline (100%) | ~15–20% ganho de espaço | ~25–30% ganho de espaço |
| **Control Height** | `48.0 px` | `40.0 px` | `36.0 px` |
| **Generic Row Height** | `48.0 px` | `40.0 px` | `34.0 px` |
| **Vertical Padding** | `12.0 px` | `8.0 px` | `6.0 px` |
| **Horizontal Padding**| `16.0 px` | `12.0 px` | `8.0 px` |
| **Icon Size** | `22.0 px` | `20.0 px` | `18.0 px` |

---

## 4. Arquitetura e Fluxo de Estado

```text
[ SharedPreferences: 'ui_density' ]
                ▲
                │ (load / save)
                ▼
      [ ThemeService ]
                ▲
                │
                ▼
      [ ThemeProvider ] (ChangeNotifier)
                ▲
                │ (notifyListeners)
                ▼
          [ MyApp ] (ListenableBuilder)
                │
          [ ThemeData ]
                │ (ThemeExtension)
                ▼
    [ TaskFlowThemeExtension ]
          ├── colors
          ├── typography
          ├── spacing
          ├── elevation
          └── density: TFDensity
```

### Acesso no Código dos Componentes
```dart
// Através da extensão de contexto:
final density = context.tfDensity;

// Propriedades úteis:
density.controlHeight;
density.verticalPadding;
density.horizontalPadding;
density.rowHeight;
density.mode; // TFDensityMode.comfortable | compact | dense
```

---

## 5. Adaptação dos Componentes TFDS

- **`TFButton`**: Altura (`44 / 40 / 34 px`) e paddings horizontais escalonam suavemente.
- **`TFIconButton`**: Mantém touch target de pelo menos 40x40px para acessibilidade.
- **`TFTextField`**: Altura e `contentPadding` vertical se ajustam à densidade ativa (`12 / 8 / 6 px`).
- **`TFDropdown`**: Altura de controle varia (`48 / 40 / 36 px`) com padding interno reduzido nos modos compactos.
- **`TFCard`**: Padding padrão derivado da densidade quando não explicitamente especificado.
- **`TFDataTable`**: Alturas de cabeçalho (`48 / 40 / 32 px`) e linhas de dados (`52 / 44 / 36 px`).

---

## 6. Configuração do Usuário
A seleção de densidade está disponível em `Configurações` -> `Densidade da Interface`:
- **Confortável**: Mais espaçamento. Padrão atual.
- **Compacta**: Ideal para notebooks.
- **Densa**: Máxima informação em telas desktop.

A preferência é gravada na chave `ui_density` do `SharedPreferences` e restaurada automaticamente no bootstrap da aplicação.

---

## 7. Garantias de Não-Regressão e Segurança de Negócio
- **Lógica de Negócio**: 0 alterações.
- **Esquema de Banco de Dados (Supabase / SQLite)**: 0 alterações.
- **Sincronização Offline**: 0 alterações.
- **TaskTable / Gantt / Schedule Geometry**: 0 alterações (0 Pixel Drift).
