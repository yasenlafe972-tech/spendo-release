@echo off
chcp 65001 >nul
title Spendo GitHub Auto-Sync
echo ======================================================
echo    Spendo GitHub Auto-Sync Service
echo    جاري تشغيل المزامنة التلقائية مع GitHub...
echo ======================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0auto_sync_github.ps1"
pause
