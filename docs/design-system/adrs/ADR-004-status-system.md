# ADR-004: Semântica Centralizada de Status Operacionais

## Status
Aprovado

## Contexto
O TaskFlow lida com múltiplos tipos de status: status de tarefas locais (`PLND`, `PROG`, `EXEC`, `CONC`, `CANC`), status de ordens e notas SAP (`MSPN`, `MSPR`, `ORDA`, `LIBE`, `ENCE`), status de equipes (`ATIVO`, `OCUPADO`, `DISPONÍVEL`), status de demandas e status de sincronização offline (`pending`, `synced`, `failed`). Hoje existem 34 implementações dispersas atribuindo cores arbitrárias para cada um.

## Decisão
Criar o enum unificado de severidade e o componente `TFStatusBadge`. O status visual será composto obrigatoriamente por:
* Cor de fundo sutil com borda e contraste de texto $\ge 4.5:1$.
* Ícone representativo da severidade ou estado.
* Rótulo textual legível.
* Para notas e ordens SAP: contagem regressiva de prazo destacada em chip interno.

## Consequências
* **Positivas:**
  * O operador reconhece o estado do ativo imediatamente em qualquer tela do sistema.
  * Acessibilidade completa para pessoas daltônicas.
* **Negativas:**
  * Necessidade de mapear os códigos legados de cada tabela/view para a severidade correspondente.
