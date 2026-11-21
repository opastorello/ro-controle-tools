@echo off
setlocal enabledelayedexpansion
title RO Controle - Criar Agendamento
cd /d "%~dp0"

echo ============================================
echo   RO Controle - Criar Agendamento
echo ============================================
echo.

REM Verificar se esta rodando como admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERRO: Execute como Administrador!
    echo.
    echo Clique com botao direito no arquivo e selecione
    echo "Executar como administrador"
    echo.
    pause
    exit /b 1
)

REM Caminho do ExecutarTudo.bat
set "SCRIPT_PATH=%~dp0ExecutarTudo.bat"

echo Caminho detectado:
echo %SCRIPT_PATH%
echo.

REM Verificar se ja existe
schtasks /query /tn "RO Controle" >nul 2>&1
if %errorlevel% equ 0 (
    echo Agendamento "RO Controle" ja existe!
    echo.
    set /p "CHOICE=Deseja substituir? (S/N): "
    if /i not "!CHOICE!"=="S" (
        echo Cancelado.
        pause
        exit /b 0
    )
    echo Removendo agendamento antigo...
    schtasks /delete /tn "RO Controle" /f >nul 2>&1
)

echo.
echo Criando agendamento para executar a cada 1 hora...
echo.

schtasks /create /tn "RO Controle" /tr "\"%SCRIPT_PATH%\"" /sc hourly /mo 1 /ru SYSTEM /f

if %errorlevel% equ 0 (
    echo.
    echo ============================================
    echo   AGENDAMENTO CRIADO COM SUCESSO!
    echo ============================================
    echo.
    echo Nome: RO Controle
    echo Intervalo: A cada 1 hora
    echo Script: %SCRIPT_PATH%
    echo.
    echo Para testar agora, execute:
    echo   schtasks /run /tn "RO Controle"
    echo.
) else (
    echo.
    echo ERRO ao criar agendamento!
    echo.
)

pause
