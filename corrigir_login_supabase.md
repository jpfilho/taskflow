# 🔧 SOLUÇÃO: Problema de Login no Supabase

## 🔍 **DIAGNÓSTICO**

Execute primeiro:
```powershell
.\diagnosticar_supabase.ps1
```

---

## ✅ **SOLUÇÃO 1: Se HTTP (porta 8000) estiver funcionando**

Manter o arquivo como está:

```dart
// lib/config/supabase_config.dart
static const String supabaseUrl = 'http://212.85.0.249:8000';
```

✅ **VANTAGEM:** Funciona sem problemas de certificado  
❌ **DESVANTAGEM:** Não funciona para Telegram (precisa HTTPS)

---

## ✅ **SOLUÇÃO 2: Usar HTTPS com domínio (RECOMENDADO)**

Atualizar para:

```dart
// lib/config/supabase_config.dart  
static const String supabaseUrl = 'https://api.taskflowv3.com.br';
```

✅ **VANTAGEM:** Funciona com Telegram, mais seguro  
⚠️ **REQUISITO:** Certificado SSL deve estar funcionando

---

## ✅ **SOLUÇÃO 3: HTTPS com IP (se domínio não funcionar)**

Se o domínio não resolver, usar IP com HTTPS:

```dart
static const String supabaseUrl = 'https://212.85.0.249';
```

E adicionar `HttpOverrides` no `main.dart`:

```dart
import 'dart:io';

// No início do main(), ANTES de inicializar o Supabase:
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Aceitar certificados auto-assinados (apenas para desenvolvimento)
  if (!kIsWeb) {
    HttpOverrides.global = MyHttpOverrides();
  }
  
  // ... resto do código
}

// Classe para aceitar certificados
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = 
          (X509Certificate cert, String host, int port) => true;
  }
}
```

⚠️ **ATENÇÃO:** Isso desabilita verificação de certificado (use apenas em desenvolvimento)

---

## 🚀 **QUAL USAR?**

1. Execute `.\diagnosticar_supabase.ps1`
2. Veja qual conexão está funcionando
3. Escolha a solução apropriada
4. Me avise o resultado!
