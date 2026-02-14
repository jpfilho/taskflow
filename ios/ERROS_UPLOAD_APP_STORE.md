# Correção dos erros de upload para a App Store (iOS)

Este documento descreve os erros que podem aparecer ao distribuir o app (Archive → Upload) e as soluções aplicadas.

## 1. ✅ sqlite3arm64ios_sim.framework – Versão mínima do SO (corrigido)

**Erro:**  
"Invalid Bundle. The bundle Runner.app/Frameworks/sqlite3arm64ios_sim.framework does not support the minimum OS Version specified in the Info.plist."

**Causa:**  
O pacote Dart `sqlite3` (usado indiretamente por `sqflite_common_ffi`) entrega frameworks para dispositivo e para simulador. No archive para dispositivo, o framework de **simulador** (`*_sim`) não deve ir no bundle.

**Solução aplicada:**  
Foi adicionada a fase de build **"Remove Simulator Frameworks"** no Xcode (target Runner). Ela roda apenas em build para dispositivo (`iphoneos`) e remove do app qualquer framework cujo nome contenha `_sim`, por exemplo `sqlite3arm64ios_sim.framework`.

- Arquivo: `ios/Runner.xcodeproj/project.pbxproj`  
- Nome da fase: **Remove Simulator Frameworks**

Depois de arquivar de novo, esse erro de validação deve sumir.

---

## 2. LC_ENCRYPTION_INFO – Binário inválido

**Erro:**  
"The binary is invalid. The encryption info in the LC_ENCRYPTION_INFO load command is either missing or invalid, or the binary is already encrypted. This binary does not seem to have been built with Apple's linker."

**Causa possível:**  
Build anterior “sujo” ou framework (ex.: sqlite3) incluído de forma que a Apple considera inválida. Às vezes está ligado ao framework de simulador no bundle.

**O que fazer:**

1. **Limpar e gerar de novo**
   - No terminal: `flutter clean`
   - Em Xcode: **Product → Clean Build Folder** (Shift+Cmd+K)
   - Opcional: apagar `ios/Pods`, `ios/Podfile.lock` e rodar `cd ios && pod install`
   - Gerar o archive de novo: **Product → Archive** e fazer o upload.

2. Garantir que está usando **Xcode** para o Archive (não apenas `flutter build ipa` sem abrir o Xcode), para que assinatura e linker sejam os padrão da Apple.

Se o erro continuar após remover o `*_sim` e fazer clean + novo archive, pode ser necessário investigar se algum plugin ou dependência nativa está gerando binário incompatível (por exemplo, outro framework não construído com o linker da Apple).

---

## 3. dSYM do sqlite3arm64ios.framework (mitigado)

**Erro:**  
"The archive did not include a dSYM for the sqlite3arm64ios.framework with the UUIDs [...]." (Upload completed with warnings / Upload Symbols Failed)

**Causa:**  
Os frameworks do pacote `sqlite3` (native_assets) vêm pré-compilados e sem dSYM. A Apple reclama que não há símbolos de debug para esse framework.

**Solução aplicada:**  
Foi adicionada a fase de build **"Generate dSYM for sqlite3arm64ios"** no Xcode (target Runner). Ela roda apenas em **Release** e para **dispositivo** (iphoneos) e:

- Localiza o binário `sqlite3arm64ios` dentro de `Runner.app/Frameworks/sqlite3arm64ios.framework/`
- Executa `dsymutil` nesse binário e gera `sqlite3arm64ios.framework.dSYM` em `BUILT_PRODUCTS_DIR`
- O archive passa a incluir esse dSYM, reduzindo ou eliminando o aviso de "Upload Symbols Failed"

**Impacto:**  
- O upload costuma ser aceito mesmo com o aviso; com o dSYM gerado, o aviso tende a sumir.
- Crash reports que envolvam esse framework passam a ter melhor simbolização quando o dSYM é enviado.

---

## Resumo

| Erro                         | Ação principal                                                |
|-----------------------------|----------------------------------------------------------------|
| sqlite3arm64ios_sim.framework | Já tratado pela fase **Remove Simulator Frameworks** no Xcode. |
| LC_ENCRYPTION_INFO          | `flutter clean` + Clean Build Folder + novo Archive.          |
| dSYM sqlite3arm64ios        | Mitigado pela fase **Generate dSYM for sqlite3arm64ios** no Xcode. |

Depois de aplicar a fase de build e fazer um clean + novo archive, tente o upload de novo. Se algum erro persistir, use os logs do Xcode (por exemplo, **Show Logs** na tela de upload) para ver a mensagem exata e o passo que falhou.
