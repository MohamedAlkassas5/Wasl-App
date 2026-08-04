@echo off
chcp 65001 >nul
title Wasl - Backend + Database
cd /d "%~dp0"

echo ========================================
echo   تشغيل قاعدة البيانات والسيرفر
echo ========================================
echo.

echo [1/2] تشغيل قاعدة البيانات (PGlite)...
start "Wasl Database" cmd /c "cd /d %~dp0 && node pglite-server.mjs & pause"

echo       في انتظار قاعدة البيانات...
timeout /t 6 /nobreak >nul

echo [2/2] تشغيل السيرفر (NestJS) على المنفذ 3000...
echo.
echo   العنوان: http://localhost:3000
echo   لوحة الأدمن: 01555000111 / LocalReviewAdmin#2026
echo.
echo   سيبها مفتوحة طول ما بتجرّب. اقفلها بـ Ctrl+C.
echo ========================================
echo.

cd /d "%~dp0\..\Wasl_backend_database"

REM بناء السيرفر لو الكود اتغيّر (بيتخطّى بسرعة لو مفيش تغيير)
if not exist "dist\main.js" (
  echo       أول تشغيل — بناء السيرفر...
  call npm run build
)

set "PORT=3000"
set "DB_HOST=127.0.0.1"
set "DB_PORT=5432"
set "DB_USERNAME=postgres"
set "DB_PASSWORD=x"
set "DB_NAME=postgres"
set "DB_POOL_MAX=1"
set "JWT_SECRET=local_dev_secret_change_before_deploy_9f3a2b7c1e"
set "JWT_EXPIRES_IN=30d"
set "ADMIN_PHONE=01555000111"
set "ADMIN_PASSWORD=LocalReviewAdmin#2026"
node dist/main.js

pause
