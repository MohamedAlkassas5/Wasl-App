@echo off
chcp 65001 >nul
title Wasl - Build and Install on Phone
setlocal

set "FLUTTER=C:\src\flutter\bin\flutter.bat"
set "ADB=C:\Android\Sdk\platform-tools\adb.exe"
cd /d "%~dp0\..\wasl_app"

echo ========================================
echo   بناء وتثبيت أحدث نسخة على الموبايل
echo ========================================
echo.

echo [1/4] التأكد إن الموبايل موصّل...
"%ADB%" devices | findstr "device$" >nul
if errorlevel 1 (
  echo.
  echo   ^!^! الموبايل مش موصّل. وصّل الكابل وفعّل USB debugging وحاول تاني.
  echo.
  pause
  exit /b 1
)
echo       الموبايل موصّل.

echo [2/4] ربط المنفذ 3000 عبر الكابل (adb reverse)...
"%ADB%" reverse tcp:3000 tcp:3000 >nul
echo       تم.

echo [3/4] بناء التطبيق... (ممكن ياخد دقيقة أو اتنين)
call "%FLUTTER%" build apk --debug
if errorlevel 1 (
  echo.
  echo   ^!^! فشل البناء. اقرا الرسايل فوق.
  echo.
  pause
  exit /b 1
)

echo [4/4] تثبيت النسخة الجديدة على الموبايل...
"%ADB%" install -r -t "build\app\outputs\flutter-apk\app-debug.apk"

echo.
echo ========================================
echo   تمّ. افتح التطبيق على الموبايل.
echo   (لازم يكون شباك السيرفر مفتوح - سكريبت رقم 1)
echo ========================================
echo.
pause
