# ============================================
# VINCULAR CONTATO DO GRUPO TELEGRAM
# Script interativo para vincular um contato que está no grupo
# ============================================

$SERVER = 'root@212.85.0.249'

function Invoke-RemotePsql {
    param(
        [Parameter(Mandatory=$true)][string]$Sql,
        [switch]$TuplesOnly,
        [switch]$Unaligned,
        [string]$FieldSep = '|'
    )

    $psqlFlags = @()

    if ($TuplesOnly) { $psqlFlags += '-t' }
    if ($Unaligned)  { $psqlFlags += '-A' }
    if ($FieldSep)   { $psqlFlags += ('-F' + '''' + $FieldSep + '''') }

    $cmd = 'docker exec -i supabase-db psql -U postgres -d postgres ' + ($psqlFlags -join ' ')

    # Envia SQL por STDIN (evita problemas com aspas/escape)
    $out = $Sql | ssh $SERVER $cmd 2>&1
    return $out
}

function Escape-SqlLiteral {
    param([string]$Value)
    if ($null -eq $Value -or $Value.Trim().Length -eq 0) { return $null }
    return $Value.Replace("'", "''")
}

function SqlOrNull {
    param([string]$Value)
    if ($null -eq $Value -or $Value.Trim().Length -eq 0) { return 'NULL' }
    return '''' + (Escape-SqlLiteral $Value) + ''''
}

Write-Host ''
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host 'VINCULAR CONTATO DO GRUPO TELEGRAM' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host ''

# ============================================
# PASSO 1: OBTER TELEGRAM USER ID
# ============================================
Write-Host 'PASSO 1: Obter Telegram User ID' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Opções para obter o Telegram User ID:' -ForegroundColor White
Write-Host '  1. Pedir para o contato enviar uma mensagem no grupo' -ForegroundColor Gray
Write-Host '  2. Executar: .\obter_telegram_user_id.ps1' -ForegroundColor Gray
Write-Host '  3. Usar o bot @userinfobot no grupo' -ForegroundColor Gray
Write-Host ''

$telegramUserId = Read-Host 'Digite o TELEGRAM USER ID (somente números)'

if ([string]::IsNullOrWhiteSpace($telegramUserId) -or -not ($telegramUserId -match '^\d+$')) {
    Write-Host '[ERRO] Telegram User ID inválido!' -ForegroundColor Red
    exit 1
}

# ============================================
# PASSO 2: IDENTIFICAR EXECUTOR
# ============================================
Write-Host ''
Write-Host 'PASSO 2: Identificar Executor no Sistema' -ForegroundColor Yellow
Write-Host ''

Write-Host 'Buscando executores ativos...' -ForegroundColor Cyan
$sqlListar = 'SELECT id, nome, matricula, telefone FROM executores WHERE ativo = true ORDER BY nome LIMIT 20;'
Invoke-RemotePsql -Sql $sqlListar | Out-Host

Write-Host ''
$matricula = Read-Host 'Digite a MATRICULA do executor'

if ([string]::IsNullOrWhiteSpace($matricula)) {
    Write-Host '[ERRO] Matrícula não informada!' -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host 'Verificando executor...' -ForegroundColor Cyan

$matriculaSql = Escape-SqlLiteral $matricula
$sqlVerificar = 'SELECT id, nome, matricula FROM executores WHERE matricula = ''' + $matriculaSql + ''' AND ativo = true;'

$resultado = Invoke-RemotePsql -Sql $sqlVerificar -TuplesOnly -Unaligned

if ($LASTEXITCODE -ne 0) {
    Write-Host '[ERRO] Falha ao consultar executor no banco!' -ForegroundColor Red
    Write-Host $resultado -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($resultado)) {
    Write-Host '[ERRO] Executor não encontrado ou inativo!' -ForegroundColor Red
    exit 1
}

$campos = $resultado.Trim() -split '\|'
$executorId = $campos[0].Trim()
$executorNome = $campos[1].Trim()
$executorMatricula = $campos[2].Trim()

Write-Host ('[OK] Executor encontrado: ' + $executorNome + ' (Matricula: ' + $executorMatricula + ')') -ForegroundColor Green

# ============================================
# PASSO 3: INFORMAÇÕES OPCIONAIS
# ============================================
Write-Host ''
Write-Host 'PASSO 3: Informações Adicionais (Opcional)' -ForegroundColor Yellow
Write-Host ''

$telegramUsername  = Read-Host 'Digite o TELEGRAM USERNAME (sem @, opcional)'
$telegramFirstName = Read-Host 'Digite o PRIMEIRO NOME no Telegram (opcional)'

# remove @ se vier
if ($telegramUsername) {
    $telegramUsername = $telegramUsername -replace '^@', ''
}

$tgUsernameSql  = SqlOrNull $telegramUsername
$tgFirstNameSql = SqlOrNull $telegramFirstName

Write-Host ''
Write-Host 'Resumo da vinculação:' -ForegroundColor Cyan
Write-Host ('  Executor: ' + $executorNome + ' (Matricula: ' + $executorMatricula + ')') -ForegroundColor White
Write-Host ('  Telegram User ID: ' + $telegramUserId) -ForegroundColor White
Write-Host ('  Telegram Username: ' + ($(if ($telegramUsername) { $telegramUsername } else { '(não informado)' }))) -ForegroundColor White
Write-Host ('  Telegram First Name: ' + ($(if ($telegramFirstName) { $telegramFirstName } else { '(não informado)' }))) -ForegroundColor White
Write-Host ''

$confirmar = Read-Host 'Confirmar vinculação? (S/N)'
if ($confirmar -notin @('S','s')) {
    Write-Host 'Operação cancelada.' -ForegroundColor Yellow
    exit 0
}

# ============================================
# VINCULAR NO BANCO
# ============================================
Write-Host ''
Write-Host 'Vinculando...' -ForegroundColor Yellow

$sqlVincularLines = @(
    'DO $$',
    'DECLARE',
    '    executor_id UUID;',
    '    executor_nome VARCHAR;',
    'BEGIN',
    '    SELECT id, nome INTO executor_id, executor_nome',
    '    FROM executores',
    '    WHERE matricula = ''' + $matriculaSql + ''' AND ativo = true;',
    '',
    '    IF executor_id IS NULL THEN',
    '        RAISE EXCEPTION ''Executor nao encontrado ou inativo'';',
    '    END IF;',
    '',
    '    INSERT INTO telegram_identities (',
    '        user_id,',
    '        telegram_user_id,',
    '        telegram_username,',
    '        telegram_first_name,',
    '        linked_at,',
    '        last_active_at',
    '    ) VALUES (',
    '        executor_id,',
    '        ' + $telegramUserId + ',',
    '        ' + $tgUsernameSql + ',',
    '        ' + $tgFirstNameSql + ',',
    '        NOW(),',
    '        NOW()',
    '    )',
    '    ON CONFLICT (telegram_user_id) DO UPDATE SET',
    '        user_id = EXCLUDED.user_id,',
    '        telegram_username = COALESCE(EXCLUDED.telegram_username, telegram_identities.telegram_username),',
    '        telegram_first_name = COALESCE(EXCLUDED.telegram_first_name, telegram_identities.telegram_first_name),',
    '        linked_at = NOW(),',
    '        last_active_at = NOW();',
    'END $$;'
)

$sqlVincular = $sqlVincularLines -join "`n"

$resultadoVincular = Invoke-RemotePsql -Sql $sqlVincular

if ($LASTEXITCODE -eq 0) {

    Write-Host ''
    Write-Host '[OK] Vinculação concluída com sucesso!' -ForegroundColor Green
    Write-Host ''

    Write-Host 'Verificando vinculação...' -ForegroundColor Cyan

    $sqlVerificarVinculacaoLines = @(
        'SELECT',
        '    ti.telegram_user_id,',
        '    ti.telegram_first_name,',
        '    ti.telegram_username,',
        '    e.matricula,',
        '    e.nome,',
        '    ti.linked_at',
        'FROM telegram_identities ti',
        'JOIN executores e ON e.id = ti.user_id',
        'WHERE ti.telegram_user_id = ' + $telegramUserId + ';'
    )
    $sqlVerificarVinculacao = $sqlVerificarVinculacaoLines -join "`n"

    Invoke-RemotePsql -Sql $sqlVerificarVinculacao | Out-Host

    Write-Host ''
    Write-Host '==========================================' -ForegroundColor Green
    Write-Host 'PRÓXIMOS PASSOS' -ForegroundColor Yellow
    Write-Host '==========================================' -ForegroundColor Green
    Write-Host ''
    Write-Host '1. Peça para o contato enviar uma mensagem no grupo do Telegram' -ForegroundColor White
    Write-Host '2. Verifique se a mensagem aparece no app Flutter' -ForegroundColor White
    Write-Host ('3. A mensagem deve aparecer com o nome: ' + $executorNome) -ForegroundColor White
    Write-Host ''

} else {

    Write-Host ''
    Write-Host '[ERRO] Erro ao vincular!' -ForegroundColor Red
    Write-Host $resultadoVincular -ForegroundColor Red
    exit 1
}
