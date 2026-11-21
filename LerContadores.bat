@echo off
title RO Controle - Ler Contadores SNMP
cd /d "%~dp0"

echo ============================================
echo   RO Controle - Ler Contadores SNMP
echo ============================================
echo.

powershell -ExecutionPolicy Bypass -File "lib\LerContadores.ps1"
