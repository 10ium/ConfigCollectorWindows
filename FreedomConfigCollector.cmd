@echo off
chcp 65001 >nul
title Freedom Config Collector v2
echo ======================================================================
echo 🚀 اجرای ابزار Freedom Config Collector v2
echo ======================================================================
python "%~dp0tools\comprehensive_test_runner.py"
echo.
echo عملیات به پایان رسید. خروجی‌ها در پوشه output ذخیره شدند.
pause
