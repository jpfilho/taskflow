# Solução para Erro SSL no Gradle

## 🐛 Problema

Erro ao executar `flutter run`:
```
javax.net.ssl.SSLHandshakeException: PKIX path building failed: 
unable to find valid certification path to requested target
```

## ✅ Solução 1: Configuração no gradle.properties (Aplicada)

Foi adicionada configuração no `android/gradle.properties` para usar o keystore do Windows.

**Se ainda não funcionar, tente as soluções abaixo:**

## ✅ Solução 2: Desabilitar Verificação SSL (Temporário)

Se a Solução 1 não funcionar, adicione ao `android/gradle.properties`:

```properties
# Desabilita verificação SSL (APENAS PARA DESENVOLVIMENTO)
systemProp.javax.net.ssl.trustStore=NONE
systemProp.javax.net.ssl.trustStoreType=Windows-ROOT
```

**⚠️ ATENÇÃO:** Isso desabilita a verificação SSL. Use apenas em desenvolvimento.

## ✅ Solução 3: Baixar Gradle Manualmente

1. Baixe o Gradle manualmente:
   - URL: https://services.gradle.org/distributions/gradle-8.12-all.zip
   - Salve em: `%USERPROFILE%\.gradle\wrapper\dists\gradle-8.12-all\<hash>\`

2. O hash pode ser obtido executando:
   ```powershell
   $url = "https://services.gradle.org/distributions/gradle-8.12-all.zip"
   $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($url))
   $hashString = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
   Write-Host $hashString
   ```

3. Ou simplesmente deixe o Gradle criar a pasta e copie o arquivo ZIP lá.

## ✅ Solução 4: Usar Gradle Local

1. Baixe o Gradle 8.12 de: https://gradle.org/releases/
2. Extraia em uma pasta (ex: `C:\gradle\gradle-8.12`)
3. Configure variável de ambiente:
   ```powershell
   [System.Environment]::SetEnvironmentVariable('GRADLE_HOME', 'C:\gradle\gradle-8.12', 'User')
   [System.Environment]::SetEnvironmentVariable('Path', $env:Path + ';C:\gradle\gradle-8.12\bin', 'User')
   ```
4. Reinicie o terminal e tente novamente.

## ✅ Solução 5: Verificar Proxy/Firewall

Se estiver atrás de proxy corporativo:

1. Configure proxy no `android/gradle.properties`:
   ```properties
   systemProp.http.proxyHost=proxy.empresa.com
   systemProp.http.proxyPort=8080
   systemProp.https.proxyHost=proxy.empresa.com
   systemProp.https.proxyPort=8080
   ```

2. Se o proxy requer autenticação:
   ```properties
   systemProp.http.proxyUser=usuario
   systemProp.http.proxyPassword=senha
   systemProp.https.proxyUser=usuario
   systemProp.https.proxyPassword=senha
   ```

## ✅ Solução 6: Limpar Cache do Gradle

```powershell
# Limpar cache do Gradle
Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle\caches"
Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle\wrapper"

# Tentar novamente
flutter clean
flutter pub get
flutter run
```

## ✅ Solução 7: Usar Mirror do Gradle (China/Brasil)

Se estiver em região com problemas de acesso:

1. Edite `android/gradle/wrapper/gradle-wrapper.properties`:
   ```properties
   # Use mirror brasileiro ou chinês
   distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-8.12-all.zip
   # Ou
   distributionUrl=https\://mirror.bjtu.edu.cn/gradle/gradle-8.12-all.zip
   ```

## 🔍 Verificar o Problema

Para diagnosticar melhor:

```powershell
# Testar conexão SSL
$url = "https://services.gradle.org/distributions/gradle-8.12-all.zip"
try {
    $response = Invoke-WebRequest -Uri $url -Method Head
    Write-Host "✅ Conexão OK: $($response.StatusCode)"
} catch {
    Write-Host "❌ Erro: $($_.Exception.Message)"
}
```

## 📝 Ordem de Tentativas Recomendada

1. ✅ **Solução 1** (já aplicada) - Configuração no gradle.properties
2. Se não funcionar: **Solução 6** - Limpar cache
3. Se ainda não funcionar: **Solução 3** - Baixar manualmente
4. Se houver proxy: **Solução 5** - Configurar proxy
5. Último recurso: **Solução 2** - Desabilitar SSL (não recomendado)

## ⚠️ Importante

- A **Solução 2** (desabilitar SSL) é apenas para desenvolvimento
- Nunca use em produção ou CI/CD
- Prefira sempre soluções que mantenham a segurança SSL ativa
