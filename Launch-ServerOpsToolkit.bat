@echo off
REM Double-click this file to launch Hybrid Infra Console (do not double-click .psm1 files)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch-ServerOpsToolkit.ps1"
if errorlevel 1 pause
