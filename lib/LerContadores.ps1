# ============================================
# RO Controle - Ler Contadores SNMP
# ============================================

param([switch]$Auto)

$ErrorActionPreference = "Stop"

Write-Host "==========================================="
Write-Host "  RO Controle - Ler Contadores SNMP"
Write-Host "==========================================="
Write-Host ""

# Detectar diretorio do script
if ($PSScriptRoot) { $scriptDir = $PSScriptRoot }
elseif ($MyInvocation.MyCommand.Path) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
else { $scriptDir = Get-Location }

Push-Location $scriptDir

# ============================================
# DETECTAR CONFIGURACAO
# ============================================

$dbPath = $null
$community = "public"
$configLoaded = $false

# Opcao 1: Arquivo config.json local
$ConfigFile = Join-Path $scriptDir "config.json"
if (Test-Path $ConfigFile) {
    Write-Host "Carregando config de: $ConfigFile" -ForegroundColor Gray
    $configJson = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    $dbPath = $configJson.dbPath
    if ($configJson.snmpCommunity) { $community = $configJson.snmpCommunity }
    $configLoaded = $true
}

# Opcao 2: Detectar automaticamente do RO Controle
if (-not $configLoaded) {
    # Procurar banco de dados em varios locais
    $possibleDbs = @(
        "C:\RO\LeituraOID\tarifador.db",
        "C:\RO\tarifador.db",
        "C:\Program Files (x86)\RO\LeituraOID\tarifador.db",
        "C:\Program Files\RO\LeituraOID\tarifador.db"
    )

    foreach ($db in $possibleDbs) {
        if (Test-Path $db) {
            $dbPath = $db
            Write-Host "Banco detectado: $dbPath" -ForegroundColor Green
            $configLoaded = $true
            break
        }
    }
}

# Opcao 3: Pedir ao usuario
if (-not $configLoaded -or -not $dbPath) {
    Write-Host "Banco de dados nao encontrado automaticamente." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Informe o caminho do banco tarifador.db"
    Write-Host "Exemplo: C:\RO\LeituraOID\tarifador.db"
    Write-Host ""
    $dbPath = Read-Host "Caminho"
}

# Validar
if (-not $dbPath -or -not (Test-Path $dbPath)) {
    Write-Host ""
    Write-Host "ERRO: Banco nao encontrado: $dbPath" -ForegroundColor Red
    Pop-Location; if (-not $Auto) { Read-Host "Enter para sair" }; exit 1
}

# Desbloquear arquivos (baixados da internet ficam bloqueados)
Get-ChildItem $scriptDir -Filter "*.dll" -Recurse | ForEach-Object {
    Unblock-File $_.FullName -ErrorAction SilentlyContinue
}
Get-ChildItem $scriptDir -Filter "*.exe" | ForEach-Object {
    Unblock-File $_.FullName -ErrorAction SilentlyContinue
}

# Verificar se exe existe
$exePath = Join-Path $scriptDir "LerContadores.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "ERRO: LerContadores.exe nao encontrado!" -ForegroundColor Red
    Pop-Location; if (-not $Auto) { Read-Host "Enter para sair" }; exit 1
}

# ============================================
# EXECUTAR
# ============================================

Write-Host ""
Write-Host "Banco: $dbPath" -ForegroundColor Cyan
Write-Host "Community SNMP: $community" -ForegroundColor Cyan
Write-Host ""

# Chamar o exe com os parametros
& $exePath $dbPath $community

Pop-Location

if (-not $Auto) {
    Write-Host ""
    Read-Host "Enter para sair"
}
