@echo off
title RO Controle - Executar Tudo
cd /d "%~dp0"

REM Criar pasta de logs se nao existir
if not exist "logs" mkdir "logs"

REM Nome do arquivo de log (por data)
for /f "tokens=1-3 delims=/" %%a in ("%date%") do set "LOGDATE=%%c-%%b-%%a"
set "LOGFILE=%~dp0logs\%LOGDATE%.log"

REM Verificar se ja esta executando (lock file)
set "LOCKFILE=%~dp0lib\.running.lock"

if exist "%LOCKFILE%" (
    echo [%date% %time%] Ja existe uma execucao em andamento. Saindo... >> "%LOGFILE%"
    exit /b 0
)

REM Criar lock file
echo %date% %time% > "%LOCKFILE%"

REM Iniciar log
echo. >> "%LOGFILE%"
echo ============================================ >> "%LOGFILE%"
echo [%date% %time%] INICIANDO >> "%LOGFILE%"
echo ============================================ >> "%LOGFILE%"

echo ============================================
echo   RO Controle - Leitura + Upload
echo ============================================
echo.
echo [%date% %time%] Iniciando...
echo Log: %LOGFILE%
echo.

echo === ETAPA 1: Leitura SNMP ===
echo.
echo [%date% %time%] Etapa 1: Leitura SNMP >> "%LOGFILE%"
powershell -ExecutionPolicy Bypass -File "lib\LerContadores.ps1" -Auto 2>&1 | powershell -Command "$input | Tee-Object -Append '%LOGFILE%'"

echo.
echo === ETAPA 2: Upload para servidor ===
echo.
echo [%date% %time%] Etapa 2: Upload >> "%LOGFILE%"
powershell -ExecutionPolicy Bypass -File "lib\ForcarUpload.ps1" -Auto 2>&1 | powershell -Command "$input | Tee-Object -Append '%LOGFILE%'"

echo.
echo ============================================
echo [%date% %time%] Concluido!
echo ============================================

echo [%date% %time%] CONCLUIDO >> "%LOGFILE%"
echo ============================================ >> "%LOGFILE%"

REM Remover lock file
del "%LOCKFILE%" 2>nul
