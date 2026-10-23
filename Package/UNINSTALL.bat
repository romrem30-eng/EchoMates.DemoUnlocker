@echo off
setlocal
chcp 65001 >nul 2>&1
title Echo Mates Demo - Mod Uninstaller

:: Run PowerShell uninstaller with execution policy bypass
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\uninstall.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Uninstallation failed or was aborted with error code %ERRORLEVEL%.
    pause
)

endlocal
