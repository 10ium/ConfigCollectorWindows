@echo off
chcp 65001 >nul
title Freedom Config Collector v2

cd /d "%~dp0"
start "" pythonw.exe app_gui.py
exit
