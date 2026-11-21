@echo off
title RO Controle - Forcar Upload
cd /d "%~dp0"

echo ============================================
echo   RO Controle - Forcar Upload de Leituras
echo ============================================
echo.

powershell -ExecutionPolicy Bypass -File "lib\ForcarUpload.ps1"
