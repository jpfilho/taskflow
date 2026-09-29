# AUDITORIA DA ARQUITETURA DE NAVEGAÇÃO — TASKFLOW MOBILE

Este documento avalia a experiência de navegação, ergonomia com uma mão (*one-handed use*), alcance do polegar (*thumb-zone*) e fluxos de transição do TaskFlow no mobile.

---

## 1. Arquitetura Atual e Problemas Estruturais

A navegação mobile atual no TaskFlow é uma herança direta da estrutura de desktop em `lib/main.dart`:

```
┌─────────────────────────────────────────────────────────┐
│ TopBar [Menu Hambúrguer] [Título] [Avisos] [Sync] [Sair]│  <- Zona Inalcançável (Topo)
├─────────────────────────────────────────────────────────┤
│ FilterBar: [Setor▼] [Regional▼] [Divisão▼] [Status▼]... │  <- Scroll Horizontal Denso
├─────────────────────────────────────────────────────────┤
│                                                         │
│                                                         │
│               Conteúdo Principal da Tela                │  <- Zona Neutra / Rolagem
│                                                         │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ Footbar Atual (Apenas em 3 telas: Atividades, Notas...) │  <- Ícones e textos minúsculos
└─────────────────────────────────────────────────────────┘
```

### 1.1 O Problema do Drawer com 27 Itens

Ao clicar no ícone de menu hambúrguer no canto superior esquerdo, o aplicativo abre um `Drawer` vertical contendo:
* **27 itens corridos** misturando tarefas operacionais diárias (Atividades, Checklist, Chat) com módulos estratégicos ou administrativos (Custos, Linhas de Transmissão, Supressão, Configurações, GTD).
* Nenhum agrupamento por categoria ou frequência de uso.
* Falta de destaque para "O que eu preciso fazer hoje".
* O técnico em campo precisa rolar o drawer por 3 telas verticais para encontrar o módulo de "Horas SAP" ou "Checklists".

### 1.2 O Problema do "Footbar" Fragmentado (`_buildFootbar`)

O código em `lib/main.dart` define:
```dart
bottomNavigationBar: (_sidebarSelectedIndex == 0 ||
        _sidebarSelectedIndex == 16 ||
        _sidebarSelectedIndex == 20)
    ? _buildFootbar(context)
    : null,
```
Isso gera três problemas graves:
1. **Descontinuidade Visual**: Ao navegar para Equipes (índice 1), Frota (2), Demandas (3) ou Chat (14), a barra inferior desaparece subitamente, desorientando o usuário.
2. **Falta de Ergonomia**: Os botões da barra medem menos de 36px de altura, com textos de 9px e ícones de 20px, violando a área de toque segura.
3. **Destinos Fixos Incompatíveis**: Os botões da Footbar alternam entre "Gantt", "Planner" e "Tabela" da mesma tela, em vez de atuar como barra de navegação global entre módulos.

---

## 2. Análise Ergonômica: A Zona do Polegar (*Thumb Zone*)

Em smartphones contemporâneos (telas entre 6.1" e 6.7"), a anatomia da mão humana operando com apenas uma mão define três zonas de acessibilidade:

```
┌─────────────────────────┐
│     ZONA DIFÍCIL        │  <- TopBar, Perfil, Sincronização, Título
│   (Exige segunda mão    │     (Hoje: onde estão 80% das ações de filtro
│    ou risco de queda)   │      e navegação do TaskFlow)
├─────────────────────────┤
│      ZONA NATURAL       │  <- Leitura de cards, status da tarefa atual
│     (Alcance médio)     │
├─────────────────────────┤
│       ZONA FÁCIL        │  <- Onde DEVE ficar a Navegação Principal,
│   (Conforto do polegar) │     Ações Primárias (Iniciar, Concluir, Foto)
└─────────────────────────┘
```

### Diagnóstico no TaskFlow:
* **85% das ações críticas** (abrir menu, aplicar filtros, pesquisar, sincronizar, voltar de tela) estão localizadas na **Zona Difícil** (topo da tela).
* A **Zona Fácil** (base da tela) está subutilizada ou ocupada por botões minúsculos de 9px.

---

## 3. Proposta de Arquitetura de Navegação Mobile

Para transformar o TaskFlow em uma ferramenta de campo ágil, a navegação deve ser baseada em **três pilares**:

### 3.1 Pilar 1: Bottom Navigation Bar Unificada (5 Destinos)

Uma barra inferior fixa presente em todas as telas operacionais principais:

1. **Hoje** (Ícone: `calendar_today`):
   * Tela inicial do operador: Atividades agendadas para o dia, equipe designada, veículo do dia e pendências imediatas.
2. **Atividades** (Ícone: `assignment`):
   * Lista completa de tarefas, filtros rápidos por status e busca por código/OS.
3. **Ações Rápidas / Campo** (Botão Central em Destaque):
   * Acesso instantâneo a: Tirar Foto/Evidência, Preencher Checklist/APR, Apontar Horas ou Vincular Nota SAP.
4. **Comunicação** (Ícone: `chat_bubble_outline`):
   * Chat de campo, mensagens da equipe e avisos operacionais.
5. **Mais** (Ícone: `menu`):
   * Menu estruturado em categorias lógicas:
     * *Operação*: Equipes, Frota, Demandas, Documentos;
     * *SAP*: Notas, Ordens, SIs, ATs, Confirmação;
     * *Especialidades*: Linhas de Transmissão, Supressão;
     * *Sistema*: Modo Offline, Sincronização, Configurações.

### 3.2 Pilar 2: BottomSheet de Filtros em Substituição à Barra Horizontal

Em vez de uma barra horizontal com 8 menus suspensos espremidos no topo:
* Um único botão de filtro na Zona Fácil: `[Filtrar (3 ativos)]`.
* Ao tocar, abre-se uma `ModalBottomSheet` arrastável ancorada na base da tela.
* Seleção confortável de Regional, Divisão, Equipe e Status através de chips grandes (≥44px de altura).
* Botão fixo no rodapé da folha: "Aplicar Filtros".

### 3.3 Pilar 3: Floating Action Button (FAB) Contextual

Cada tela operacional deve ter sua ação prioritária ancorada no canto inferior direito:
* Na tela de Atividades: `FAB [ + Nova Tarefa ]` ou `[ Escanear QR Code ]`.
* Na tela de Evidências/Mídia: `FAB [ Tirar Foto ]`.
* No Checklist: `FAB [ Concluir Inspeção ]`.
