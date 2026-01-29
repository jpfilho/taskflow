# Script para remover todos os usos de .in_() que nao existem mais no Supabase Flutter

$file = "lib\services\hora_sap_service.dart"
$content = Get-Content $file -Raw

# Substituir pattern .in_('campo', lista) por OR conditions
$content = $content -replace "query = query\.in_\('ordem', filtroOrdens\);", "final orConditions = filtroOrdens.map((v) => 'ordem.eq.${'$'}v').join(',');`n          query = query.or(orConditions);"
$content = $content -replace "query = query\.in_\('operacao', filtroOperacoes\);", "final orConditions = filtroOperacoes.map((v) => 'operacao.eq.${'$'}v').join(',');`n          query = query.or(orConditions);"
$content = $content -replace "query = query\.in_\('tipo_atividade_real', filtroTipoAtividade\);", "final orConditions = filtroTipoAtividade.map((v) => 'tipo_atividade_real.eq.${'$'}v').join(',');`n          query = query.or(orConditions);"
$content = $content -replace "query = query\.in_\('numero_pessoa', filtroNumeroPessoa\);", "final orConditions = filtroNumeroPessoa.map((v) => 'numero_pessoa.eq.${'$'}v').join(',');`n          query = query.or(orConditions);"
$content = $content -replace "query = query\.in_\('matricula', matriculasFiltro\);", "final orConditions = matriculasFiltro.map((v) => 'matricula.eq.${'$'}v').join(',');`n        query = query.or(orConditions);"

Set-Content $file $content -NoNewline

Write-Host "ARQUIVO CORRIGIDO!" -ForegroundColor Green
Write-Host "Todos os usos de .in_() foram substituidos por .or()" -ForegroundColor Cyan
