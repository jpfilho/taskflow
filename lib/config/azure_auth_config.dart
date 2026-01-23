/// Configuração Entra ID (Azure AD).
/// Dados fornecidos no registro "taskflow".
const String azureClientId = '90414d95-ac9b-4b95-9fc2-ebf677253e99';
const String azureTenantId = '8a0ffb54-9716-4a93-9158-9e3a7206f18e';

/// Redirect URI registrada no Entra ID (mantida conforme solicitado).
const String azureRedirectUri = 'com.taskflow.app://auth';

/// Authority padrão usando o tenant específico.
String get azureAuthority =>
    'https://login.microsoftonline.com/$azureTenantId';
