# ADR-001: Arquitetura de Design Tokens via Flutter ThemeExtension

## Status
Aprovado

## Contexto
O TaskFlow suporta três temas (`light`, `dark`, `axia`) através de `ThemeProvider` e `ThemeService`. No entanto, 95% do código Flutter utiliza cores e estilos de texto declarados diretamente de forma estática (`Colors.white`, `Color(0xFF1E293B)`), impedindo que o tema escuro funcione de forma consistente e provocando 116 variações hexadecimais de cor.

## Decisão
Adotar o padrão nativo do Flutter **`ThemeExtension<T>`** para estruturar o `TaskFlowThemeExtension`. Todos os tokens de cor, tipografia, espaçamento, raios e bordas serão expostos através de `Theme.of(context).extension<TaskFlowThemeExtension>()!`.

## Consequências
* **Positivas:**
  * Suporte nativo a Hot Reload e animações de transição de tema via `lerp()`.
  * Fortemente tipado pelo compilador Dart (sem risco de *strings mágicas*).
  * Código desacoplado de Singletons estáticos.
* **Negativas:**
  * Exige que os widgets possuam acesso ao `BuildContext`.
