@echo off
setlocal
chcp 65001 >nul 2>&1
title Echo Mates Demo - Mod Updater

:: Run PowerShell updater script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\update.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Update check failed or was aborted with error code %ERRORLEVEL%.
    pause
)

endlocal
