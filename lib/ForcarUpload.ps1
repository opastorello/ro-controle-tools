# ============================================
# RO Controle - Forcar Upload de Leituras
# ============================================
# Ferramenta de engenharia reversa para envio
# manual de leituras ao servidor RO Controle
# ============================================

param(
    [switch]$Auto,
    [switch]$DryRun,
    [int]$Lote = 500,
    [string]$ConfigFile = ""
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================="
Write-Host "  RO Controle - Forcar Upload de Leituras  "
Write-Host "==========================================="
Write-Host ""

# Detectar diretorio do script
if ($PSScriptRoot) { $scriptDir = $PSScriptRoot }
elseif ($MyInvocation.MyCommand.Path) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
else { $scriptDir = Get-Location }

Push-Location $scriptDir

# ============================================
# CONFIGURACAO
# ============================================

# Carregar configuracao de arquivo ou detectar automaticamente
if ([string]::IsNullOrEmpty($ConfigFile)) {
    $ConfigFile = Join-Path $scriptDir "config.json"
}

$configLoaded = $false

# Opcao 1: Arquivo config.json local
if (Test-Path $ConfigFile) {
    Write-Host "Carregando config de: $ConfigFile" -ForegroundColor Gray
    $configJson = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    $securityKey = $configJson.securityKey
    $iv = $configJson.iv
    $dbPath = $configJson.dbPath
    $configLoaded = $true
}

# Opcao 2: Detectar automaticamente do RO Controle instalado
if (-not $configLoaded) {
    # Procurar em varios locais possiveis
    $possibleConfigs = @(
        "C:\RO\LeituraOID\Ro.Controle.Start.exe.config",
        "C:\RO\Ro.Controle.Start.exe.config",
        "C:\Program Files\RO\Ro.Configurador\Ro.Controle.Start.exe.config",
        "C:\Program Files (x86)\RO\Ro.Configurador\Ro.Controle.Start.exe.config",
        "C:\Program Files\RO\Ro.Configurador\RO.Configurador.UI.exe.config",
        "C:\Program Files (x86)\RO\Ro.Configurador\RO.Configurador.UI.exe.config",
        "C:\Program Files\RO Controle\Ro.Controle.Start.exe.config",
        "C:\Program Files (x86)\RO Controle\Ro.Controle.Start.exe.config"
    )

    foreach ($roConfig in $possibleConfigs) {
        if (Test-Path $roConfig) {
            Write-Host "Detectado config RO Controle: $roConfig" -ForegroundColor Gray
            try {
                [xml]$xml = Get-Content $roConfig
                $securityKey = ($xml.configuration.appSettings.add | Where-Object { $_.key -eq "SecurityKey" }).value
                $ivTemp = ($xml.configuration.appSettings.add | Where-Object { $_.key -eq "IV" }).value
                if ([string]::IsNullOrEmpty($ivTemp)) {
                    $iv = "64e7eaf31e849731ddd317cb9c0d1fd2"
                } else {
                    $iv = $ivTemp
                }
                $configLoaded = $true
                Write-Host "Chaves extraidas automaticamente!" -ForegroundColor Green
                break
            } catch {
                Write-Host "Erro ao ler config: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

    # Detectar banco de dados
    $possibleDbs = @(
        "C:\RO\LeituraOID\tarifador.db",
        "C:\RO\tarifador.db",
        "C:\Program Files (x86)\RO\LeituraOID\tarifador.db",
        "C:\Program Files\RO\LeituraOID\tarifador.db"
    )
    foreach ($db in $possibleDbs) {
        if (Test-Path $db) {
            $dbPath = $db
            break
        }
    }
    if ([string]::IsNullOrEmpty($dbPath)) { $dbPath = "C:\RO\LeituraOID\tarifador.db" }
}

# Se nao encontrou configuracao, pedir ao usuario
if (-not $configLoaded) {
    Write-Host "RO Controle nao encontrado automaticamente." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Informe o caminho onde esta o arquivo Ro.Controle.Start.exe.config"
    Write-Host "Exemplo: C:\RO\LeituraOID ou C:\Program Files (x86)\RO\Ro.Configurador"
    Write-Host ""
    $roPath = Read-Host "Caminho"

    if (-not [string]::IsNullOrEmpty($roPath)) {
        # Tentar varios nomes de config
        $configNames = @("Ro.Controle.Start.exe.config", "RO.Configurador.UI.exe.config")
        $roConfig = $null
        foreach ($name in $configNames) {
            $testPath = Join-Path $roPath $name
            if (Test-Path $testPath) { $roConfig = $testPath; break }
        }
        if ($roConfig -and (Test-Path $roConfig)) {
            Write-Host "Config encontrado!" -ForegroundColor Green
            try {
                [xml]$xml = Get-Content $roConfig
                $securityKey = ($xml.configuration.appSettings.add | Where-Object { $_.key -eq "SecurityKey" }).value
                $ivTemp = ($xml.configuration.appSettings.add | Where-Object { $_.key -eq "IV" }).value
                if ([string]::IsNullOrEmpty($ivTemp)) { $iv = "64e7eaf31e849731ddd317cb9c0d1fd2" } else { $iv = $ivTemp }
                $configLoaded = $true

                # Procurar banco na mesma pasta ou em LeituraOID
                $dbTest = Join-Path $roPath "tarifador.db"
                $dbTest2 = Join-Path (Split-Path $roPath) "LeituraOID\tarifador.db"
                if (Test-Path $dbTest) { $dbPath = $dbTest }
                elseif (Test-Path $dbTest2) { $dbPath = $dbTest2 }
                else { $dbPath = "C:\RO\LeituraOID\tarifador.db" }
            } catch {
                Write-Host "Erro ao ler: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "Arquivo nao encontrado: $roConfig" -ForegroundColor Red
        }
    }
}

if (-not $configLoaded) {
    Write-Host ""
    Write-Host "ERRO: Nao foi possivel carregar configuracao!" -ForegroundColor Red
    Write-Host "Copie config.example.json para config.json e preencha as chaves manualmente."
    Pop-Location; if (-not $Auto) { Read-Host "Enter para sair" }; exit 1
}

# Validar configuracao
if ([string]::IsNullOrEmpty($securityKey) -or $securityKey -like "*SUA_CHAVE*") {
    Write-Host "ERRO: SecurityKey nao configurada!" -ForegroundColor Red
    Write-Host "Edite config.json com as chaves corretas." -ForegroundColor Yellow
    Pop-Location; if (-not $Auto) { Read-Host "Enter para sair" }; exit 1
}

# Desbloquear DLLs (arquivos baixados da internet ficam bloqueados)
Get-ChildItem $scriptDir -Filter "*.dll" -Recurse | ForEach-Object {
    Unblock-File $_.FullName -ErrorAction SilentlyContinue
}
Get-ChildItem $scriptDir -Filter "*.exe" | ForEach-Object {
    Unblock-File $_.FullName -ErrorAction SilentlyContinue
}

# Carregar SQLite
$sqliteDll = Join-Path $scriptDir "System.Data.SQLite.dll"
if (-not (Test-Path $sqliteDll)) {
    Write-Host "ERRO: System.Data.SQLite.dll nao encontrado!" -ForegroundColor Red
    Pop-Location; if (-not $Auto) { Read-Host "Enter para sair" }; exit 1
}
Add-Type -Path $sqliteDll

if (-not (Test-Path $dbPath)) {
    Write-Host "ERRO: Banco nao encontrado: $dbPath" -ForegroundColor Red
    Pop-Location; if (-not $Auto) { Read-Host "Enter para sair" }; exit 1
}

# Compilar utilitario de criptografia se nao existir
$cryptoExe = Join-Path $scriptDir "RJ256Crypto.exe"
if (-not (Test-Path $cryptoExe)) {
    Write-Host "Compilando utilitario de criptografia..." -ForegroundColor Gray
    $cscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    $csFile = Join-Path $scriptDir "RJ256Crypto.cs"

    @"
using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

class Program {
    static void Main(string[] args) {
        if (args.Length < 3) {
            Console.WriteLine("Uso: RJ256Crypto.exe <key> <iv> <texto>");
            return;
        }
        string sKey = args[0];
        string sIV = args[1];
        string text = args[2];

        try {
            RijndaelManaged rijndael = new RijndaelManaged();
            rijndael.Padding = PaddingMode.PKCS7;
            rijndael.Mode = CipherMode.CBC;
            rijndael.KeySize = 256;
            rijndael.BlockSize = 256;

            byte[] keyBytes = Encoding.ASCII.GetBytes(sKey);
            byte[] ivBytes = Encoding.ASCII.GetBytes(sIV);

            ICryptoTransform encryptor = rijndael.CreateEncryptor(keyBytes, ivBytes);
            MemoryStream ms = new MemoryStream();
            CryptoStream cs = new CryptoStream(ms, encryptor, CryptoStreamMode.Write);

            byte[] textBytes = Encoding.ASCII.GetBytes(text);
            cs.Write(textBytes, 0, textBytes.Length);
            cs.FlushFinalBlock();

            Console.WriteLine(Convert.ToBase64String(ms.ToArray()));
        } catch (Exception ex) {
            Console.Error.WriteLine("Erro: " + ex.Message);
            Environment.Exit(1);
        }
    }
}
"@ | Set-Content $csFile -Encoding UTF8

    & $cscPath /out:$cryptoExe $csFile 2>&1 | Out-Null
    Remove-Item $csFile -Force -ErrorAction SilentlyContinue

    if (-not (Test-Path $cryptoExe)) {
        Write-Host "ERRO: Falha ao compilar utilitario de criptografia!" -ForegroundColor Red
        Pop-Location; if (-not $Auto) { Read-Host "Enter para sair" }; exit 1
    }
}

# ============================================
# FUNCOES
# ============================================

function Get-Configuracao {
    $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$dbPath;Version=3;")
    $conn.Open()
    $config = @{ UrlBase = ""; IdCliente = ""; IpPc = ""; ChaveAcesso = "" }

    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT url_ws, id_cliente, ip_pc, chave_acesso FROM configuracao LIMIT 1"
    $reader = $cmd.ExecuteReader()
    if ($reader.Read()) {
        $config.UrlBase = $reader["url_ws"]
        $config.IdCliente = $reader["id_cliente"]
        $config.IpPc = $reader["ip_pc"]
        $config.ChaveAcesso = $reader["chave_acesso"]
    }
    $reader.Close()
    $conn.Close()

    if ([string]::IsNullOrEmpty($config.UrlBase)) { $config.UrlBase = "https://rocontrole.com.br/api" }
    return $config
}

function Get-IdAuth {
    param($Config)
    $textToEncrypt = "$($Config.IdCliente);$($Config.IpPc);"
    $result = & $cryptoExe $securityKey $iv $textToEncrypt 2>&1
    return $result.Trim()
}

function Get-NrAutorizacao {
    param($Config, $IdAuth)

    $url = "$($Config.UrlBase.TrimEnd('/'))/Autorizacao"
    $body = "`"$IdAuth`""

    $headers = @{
        "Accept" = "application/json, application/xml, text/json, text/x-json, text/javascript, text/xml"
        "User-Agent" = "RestSharp/106.2.2.0"
    }

    Write-Host "  Obtendo autorizacao..." -ForegroundColor Gray
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType "application/json" -TimeoutSec 30
    return $response
}

function Get-ContagemLeituras {
    $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$dbPath;Version=3;")
    $conn.Open()
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT COUNT(*) FROM leitura_log"
    $count = $cmd.ExecuteScalar()
    $conn.Close()
    return $count
}

function Get-ContagemEquipamentos {
    $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$dbPath;Version=3;")
    $conn.Open()
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT COUNT(*) FROM equipamentos"
    $count = $cmd.ExecuteScalar()
    $conn.Close()
    return $count
}

function Get-Leituras {
    $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$dbPath;Version=3;")
    $conn.Open()
    $leituras = [System.Collections.ArrayList]::new()

    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT id, id_equipamento, id_oid, valor, data_leitura FROM leitura_log ORDER BY data_leitura DESC"

    $reader = $cmd.ExecuteReader()
    $i = 0
    while ($reader.Read()) {
        $null = $leituras.Add(@{
            Id = $reader["id"]
            Id_equipamento = $reader["id_equipamento"]
            Id_oid = $reader["id_oid"]
            Valor = $reader["valor"]
            Data_leitura = $reader["data_leitura"]
        })
        $i++
        if ($i % 1000 -eq 0) { Write-Host "  Carregadas: $i leituras..." -ForegroundColor Gray }
    }
    $reader.Close()
    $conn.Close()
    return $leituras
}

function Send-Leituras {
    param($Config, $NrAutorizacao, $Leituras)

    $url = "$($Config.UrlBase.TrimEnd('/'))/LeituraOID/PostLeituraOidAuth"

    foreach ($leitura in $Leituras) {
        if ([string]::IsNullOrEmpty($leitura.Id_cliente)) { $leitura.Id_cliente = $Config.IdCliente }
    }

    $json = $Leituras | ConvertTo-Json -Depth 10 -Compress
    if ($Leituras.Count -eq 1) { $json = "[$json]" }

    Write-Host "  Enviando $($Leituras.Count) leituras ($([math]::Round($json.Length/1024, 1)) KB)..." -ForegroundColor Yellow

    if ($DryRun) {
        Write-Host "  [DRY RUN] Nao enviado" -ForegroundColor Magenta
        return $true
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{
            "Accept" = "application/json, application/xml, text/json, text/x-json, text/javascript, text/xml"
            "User-Agent" = "RestSharp/106.2.2.0"
            "nr_autorizacao" = $NrAutorizacao
        }

        $response = Invoke-RestMethod -Uri $url -Method Post -Body $json -Headers $headers -ContentType "application/json" -TimeoutSec 120
        Write-Host "  OK! (resposta: $response)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  ERRO: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Update-DataTransmissao {
    $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$dbPath;Version=3;")
    $conn.Open()
    $agora = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "UPDATE clientes SET data_transmissao = '$agora'"
    $cmd.ExecuteNonQuery() | Out-Null
    $conn.Close()
    Write-Host "Data transmissao atualizada: $agora" -ForegroundColor Gray
}

# ============================================
# EXECUCAO
# ============================================

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Write-Host "Carregando configuracao do banco..." -ForegroundColor Gray
    $config = Get-Configuracao

    Write-Host ""
    Write-Host "URL Base: $($config.UrlBase)" -ForegroundColor Cyan
    Write-Host "ID Cliente: $($config.IdCliente)" -ForegroundColor Cyan
    Write-Host ""

    $totalEquip = Get-ContagemEquipamentos
    Write-Host "Equipamentos cadastrados: $totalEquip"

    Write-Host "Contando leituras..." -ForegroundColor Gray
    $totalLeituras = Get-ContagemLeituras
    Write-Host "Leituras no banco: $totalLeituras" -ForegroundColor $(if ($totalLeituras -gt 0) { "Yellow" } else { "Gray" })

    if ($totalLeituras -eq 0) {
        Write-Host ""
        Write-Host "Nenhuma leitura para enviar." -ForegroundColor Gray
    } else {
        if (-not $Auto) {
            Write-Host ""
            $resposta = Read-Host "Enviar $totalLeituras leituras em lotes de $Lote? (S/N)"
            if ($resposta.ToUpper() -ne "S") {
                Write-Host "Cancelado." -ForegroundColor Yellow
                Pop-Location; if (-not $Auto) { Read-Host "Enter para sair" }; exit 0
            }
        }

        # Obter autorizacao
        Write-Host ""
        Write-Host "=== Autenticando ===" -ForegroundColor Cyan
        $idAuth = Get-IdAuth -Config $config
        Write-Host "  Id_auth gerado" -ForegroundColor Gray
        $nrAutorizacao = Get-NrAutorizacao -Config $config -IdAuth $idAuth
        Write-Host "  nr_autorizacao obtido!" -ForegroundColor Green

        Write-Host ""
        Write-Host "Carregando leituras do banco..." -ForegroundColor Gray
        $leituras = Get-Leituras
        Write-Host "Total carregado: $($leituras.Count)" -ForegroundColor Green

        Write-Host ""
        Write-Host "=== Iniciando upload ===" -ForegroundColor Cyan

        $enviadas = 0
        $erros = 0
        $totalLotes = [math]::Ceiling($leituras.Count / $Lote)

        for ($i = 0; $i -lt $leituras.Count; $i += $Lote) {
            $loteNum = [math]::Floor($i / $Lote) + 1
            $loteAtual = $leituras[$i..[math]::Min($i + $Lote - 1, $leituras.Count - 1)]

            Write-Host ""
            Write-Host "Lote $loteNum/$totalLotes" -ForegroundColor Cyan

            if (Send-Leituras -Config $config -NrAutorizacao $nrAutorizacao -Leituras $loteAtual) {
                $enviadas += $loteAtual.Count
            } else {
                $erros += $loteAtual.Count
            }

            Write-Host "  Progresso: $enviadas enviadas, $erros erros" -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host "==========================================="
        Write-Host "  CONCLUIDO!" -ForegroundColor Green
        Write-Host "  Enviadas: $enviadas" -ForegroundColor Green
        Write-Host "  Erros: $erros" -ForegroundColor $(if ($erros -gt 0) { "Red" } else { "Gray" })
        Write-Host "==========================================="

        if ($enviadas -gt 0) { Update-DataTransmissao }
    }
} catch {
    Write-Host ""
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Pop-Location
}

if (-not $Auto) {
    Write-Host ""
    Read-Host "Enter para sair"
}
