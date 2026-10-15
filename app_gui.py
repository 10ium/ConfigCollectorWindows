#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Freedom Config Collector v2 - Windows Graphical User Interface (GUI)
Material 3 Dark Theme with Persian RTL Support & Real-time Collector Controls
Standalone Window Execution via Microsoft Edge / Chromium App Mode
"""

import os
import sys
import json
import time
import socket
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse
import subprocess
import shutil

if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

PORT = 12059
if getattr(sys, 'frozen', False):
    BASE_DIR = os.path.dirname(os.path.abspath(sys.executable))
else:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

SETTINGS_PATH = os.path.join(BASE_DIR, "config", "settings.json")
OUTPUT_DIR = os.path.join(BASE_DIR, "output")
TOOLS_DIR = os.path.join(BASE_DIR, "tools")
BIN_DIR = os.path.join(BASE_DIR, "bin")

# Import local tools
sys.path.insert(0, TOOLS_DIR)
try:
    import core_manager
except ImportError:
    core_manager = None
try:
    import unit_parser
except ImportError:
    unit_parser = None
try:
    import gemini_tester
except ImportError:
    gemini_tester = None
try:
    import telegram_sender
except ImportError:
    telegram_sender = None
try:
    import exporter
except ImportError:
    exporter = None

RUNNER_STATE = {
    "running": False,
    "progress": 0,
    "status_text": "آماده به کار",
    "logs": ["[System] Freedom Config Collector Engine v2 آماده است."],
    "last_result": None
}

CORE_DOWNLOAD_STATE = {
    "downloading": False,
    "progress": 0,
    "status_text": "آماده",
    "error": None
}

def load_settings():
    if os.path.exists(SETTINGS_PATH):
        try:
            with open(SETTINGS_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def save_settings(data):
    try:
        os.makedirs(os.path.dirname(SETTINGS_PATH), exist_ok=True)
        with open(SETTINGS_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print("Save settings error:", e)
        return False

def get_python_exe():
    py_exe = sys.executable
    if not py_exe.lower().endswith("python.exe") and not py_exe.lower().endswith("pythonw.exe"):
        for cand in [
            r"C:\Users\Alborz\AppData\Local\Programs\Python\Python312\python.exe",
            r"C:\Python314\python.exe",
            r"C:\Python314\pythonw.exe"
        ]:
            if os.path.exists(cand):
                return cand
    return py_exe

def run_collector_task():
    global RUNNER_STATE
    if RUNNER_STATE["running"]:
        return
    RUNNER_STATE["running"] = True
    RUNNER_STATE["progress"] = 5
    RUNNER_STATE["status_text"] = "در حال آغاز فرآیند استخراج..."
    RUNNER_STATE["logs"].append("🚀 فرآیند جمع‌آوری، رمزگشایی و آزمون‌های هوشمند آغاز شد.")

    try:
        runner_script = os.path.join(BASE_DIR, "tools", "comprehensive_test_runner.py")
        py_exe = get_python_exe()

        proc = subprocess.Popen(
            [py_exe, "-u", runner_script],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=BASE_DIR
        )

        for line in proc.stdout:
            l = line.strip()
            if not l:
                continue
            RUNNER_STATE["logs"].append(l)
            if len(RUNNER_STATE["logs"]) > 250:
                RUNNER_STATE["logs"].pop(0)

            if "Decrypting container files" in l:
                RUNNER_STATE["progress"] = 25
                RUNNER_STATE["status_text"] = "در حال رمزگشایی کانتینرها (.hat, .ehi, .npvt)..."
            elif "Parsing" in l and "files" in l:
                RUNNER_STATE["progress"] = 40
                RUNNER_STATE["status_text"] = "در حال تحلیل فایل‌های متنی و OpenVPN..."
            elif "Fetching Telegram" in l:
                RUNNER_STATE["progress"] = 50
                RUNNER_STATE["status_text"] = "در حال استخراج از کانال‌های تلگرام..."
            elif "Fetching Subscription" in l:
                RUNNER_STATE["progress"] = 60
                RUNNER_STATE["status_text"] = "در حال دریافت لینک‌های سابسکریپشن..."
            elif "Applying Filters" in l:
                RUNNER_STATE["progress"] = 72
                RUNNER_STATE["status_text"] = "در حال فیلتر کانفیگ‌های منقضی و تکراری..."
            elif "Running Multi-Probe" in l:
                RUNNER_STATE["progress"] = 82
                RUNNER_STATE["status_text"] = "در حال سنجش اتصال، پینگ و کشور کانفیگ‌ها..."
            elif "Calculating Comprehensive Analytics" in l:
                RUNNER_STATE["progress"] = 92
                RUNNER_STATE["status_text"] = "در حال محاسبه رتبه‌بندی و آمار تحلیلی..."
            elif "Exporting Clash" in l:
                RUNNER_STATE["progress"] = 97
                RUNNER_STATE["status_text"] = "در حال ساخت فایل‌های نهایی میهومو و پرووایدر..."

        proc.wait()
        RUNNER_STATE["progress"] = 100
        RUNNER_STATE["status_text"] = "عملیات با موفقیت پایان یافت."
        RUNNER_STATE["logs"].append("✅ عملیات با موفقیت به پایان رسید.")

        # Load analytics report
        report_file = os.path.join(OUTPUT_DIR, "analytics_report.json")
        if os.path.exists(report_file):
            try:
                with open(report_file, "r", encoding="utf-8") as f:
                    RUNNER_STATE["last_result"] = json.load(f)
            except Exception:
                pass

    except Exception as e:
        RUNNER_STATE["status_text"] = f"خطا در اجرا: {e}"
        RUNNER_STATE["logs"].append(f"❌ خطا: {e}")
    finally:
        RUNNER_STATE["running"] = False

# Background Scheduler Loop
def scheduler_worker():
    while True:
        time.sleep(10)
        s = load_settings()
        sched = s.get("scheduler", {})
        if not sched.get("enabled", False):
            continue
        
        # Check quiet hours
        if sched.get("quiet_hours_enabled", False):
            now_str = time.strftime("%H:%M")
            q_start = sched.get("quiet_start", "02:00")
            q_end = sched.get("quiet_end", "07:00")
            if q_start <= q_end:
                if q_start <= now_str <= q_end:
                    continue
            else:
                if now_str >= q_start or now_str <= q_end:
                    continue

        # Check interval
        interval_val = float(sched.get("interval_val", 60))
        interval_unit = sched.get("interval_unit", "min")
        interval_sec = interval_val * 60.0 if interval_unit in ["min", "دقیقه"] else interval_val * 3600.0
        
        last_run = sched.get("_last_run_timestamp", 0)
        if time.time() - last_run >= interval_sec:
            if not RUNNER_STATE["running"]:
                sched["_last_run_timestamp"] = time.time()
                save_settings(s)
                run_collector_task()

threading.Thread(target=scheduler_worker, daemon=True).start()

HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Freedom Config Collector v2</title>
    <link rel="icon" type="image/png" href="/app_icon.png">
    <link href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@300;400;500;700;800&family=Roboto+Mono:wght@400;500&display=swap" rel="stylesheet">
    <style>
        :root {
            --md-sys-color-primary: #38bdf8;
            --md-sys-color-on-primary: #082f49;
            --md-sys-color-primary-container: #0369a1;
            --md-sys-color-on-primary-container: #e0f2fe;
            --md-sys-color-surface: #0b0f19;
            --md-sys-color-surface-dim: #111827;
            --md-sys-color-surface-bright: #1f2937;
            --md-sys-color-surface-container: #1e293b;
            --md-sys-color-surface-container-high: #334155;
            --md-sys-color-on-surface: #f1f5f9;
            --md-sys-color-on-surface-variant: #94a3b8;
            --md-sys-color-outline: #475569;
            --md-sys-color-success: #4ade80;
            --md-sys-color-error: #f87171;
            --md-sys-color-warning: #fbbf24;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: 'Vazirmatn', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            -webkit-user-select: none;
            user-select: none;
        }

        body {
            background-color: var(--md-sys-color-surface);
            color: var(--md-sys-color-on-surface);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            overflow-x: hidden;
        }

        header {
            background: var(--md-sys-color-surface-container);
            padding: 14px 24px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid rgba(255, 255, 255, 0.08);
            box-shadow: 0 4px 14px rgba(0, 0, 0, 0.4);
        }

        .header-title {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .header-title img {
            width: 32px;
            height: 32px;
            border-radius: 8px;
        }

        .header-title h1 {
            font-size: 19px;
            font-weight: 800;
            color: var(--md-sys-color-primary);
            letter-spacing: -0.5px;
        }

        .header-title .badge {
            background: rgba(56, 189, 248, 0.15);
            color: var(--md-sys-color-primary);
            padding: 3px 10px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 600;
            border: 1px solid rgba(56, 189, 248, 0.3);
        }

        .tabs {
            display: flex;
            background: var(--md-sys-color-surface-dim);
            padding: 6px 16px;
            gap: 8px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
            overflow-x: auto;
        }

        .tab-btn {
            background: transparent;
            border: none;
            color: var(--md-sys-color-on-surface-variant);
            padding: 10px 18px;
            border-radius: 20px;
            font-size: 13.5px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s ease;
            display: flex;
            align-items: center;
            gap: 8px;
            white-space: nowrap;
        }

        .tab-btn:hover {
            background: rgba(255, 255, 255, 0.05);
            color: var(--md-sys-color-on-surface);
        }

        .tab-btn.active {
            background: var(--md-sys-color-primary-container);
            color: var(--md-sys-color-on-primary-container);
            font-weight: 700;
        }

        .container {
            flex: 1;
            padding: 24px;
            max-width: 1350px;
            margin: 0 auto;
            width: 100%;
        }

        .tab-content {
            display: none;
            animation: fadeIn 0.25s ease-in-out;
        }

        .tab-content.active {
            display: block;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(6px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .card {
            background: var(--md-sys-color-surface-container);
            border-radius: 16px;
            padding: 20px;
            margin-bottom: 20px;
            border: 1px solid rgba(255, 255, 255, 0.06);
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.25);
        }

        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
        }

        .card-header h2 {
            font-size: 16px;
            font-weight: 700;
            color: var(--md-sys-color-on-surface);
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .grid-2 {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 16px;
        }

        .grid-3 {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 16px;
        }

        .grid-4 {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 14px;
        }

        .stat-card {
            background: var(--md-sys-color-surface-dim);
            border-radius: 14px;
            padding: 16px;
            border: 1px solid rgba(255, 255, 255, 0.05);
            display: flex;
            flex-direction: column;
            gap: 6px;
        }

        .stat-card .label {
            font-size: 12px;
            color: var(--md-sys-color-on-surface-variant);
        }

        .stat-card .val {
            font-size: 24px;
            font-weight: 800;
            color: var(--md-sys-color-primary);
        }

        .btn {
            background: var(--md-sys-color-primary);
            color: var(--md-sys-color-on-primary);
            border: none;
            padding: 11px 22px;
            border-radius: 24px;
            font-size: 13.5px;
            font-weight: 700;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            transition: all 0.2s ease;
        }

        .btn:hover {
            opacity: 0.92;
            transform: translateY(-1px);
        }

        .btn:disabled {
            opacity: 0.4;
            cursor: not-allowed;
            transform: none;
        }

        .btn-outline {
            background: transparent;
            color: var(--md-sys-color-primary);
            border: 1px solid var(--md-sys-color-primary);
        }

        .btn-outline:hover {
            background: rgba(56, 189, 248, 0.1);
        }

        .btn-preset {
            background: var(--md-sys-color-surface-dim);
            color: var(--md-sys-color-on-surface);
            border: 1px solid rgba(255, 255, 255, 0.1);
            padding: 8px 16px;
            border-radius: 18px;
            font-size: 12.5px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s ease;
        }

        .btn-preset:hover, .btn-preset.active {
            background: rgba(56, 189, 248, 0.15);
            border-color: var(--md-sys-color-primary);
            color: var(--md-sys-color-primary);
        }

        .progress-bar-container {
            width: 100%;
            height: 10px;
            background: var(--md-sys-color-surface-dim);
            border-radius: 5px;
            overflow: hidden;
            margin: 16px 0 8px 0;
        }

        .progress-bar-fill {
            height: 100%;
            width: 0%;
            background: linear-gradient(90deg, #0284c7, #4ade80);
            transition: width 0.3s ease;
        }

        .terminal {
            background: #060911;
            border-radius: 12px;
            padding: 14px;
            font-family: 'Roboto Mono', monospace;
            font-size: 12px;
            color: #d1d5db;
            height: 250px;
            overflow-y: auto;
            border: 1px solid rgba(255, 255, 255, 0.08);
            line-height: 1.6;
            direction: ltr;
            text-align: left;
            -webkit-user-select: text;
            user-select: text;
        }

        .switch-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 14px 16px;
            background: var(--md-sys-color-surface-dim);
            border-radius: 12px;
            margin-bottom: 10px;
            border: 1px solid rgba(255, 255, 255, 0.04);
            transition: all 0.2s ease;
        }

        .switch-row:hover {
            border-color: rgba(56, 189, 248, 0.2);
        }

        .switch-info {
            display: flex;
            flex-direction: column;
            gap: 4px;
            flex: 1;
            padding-left: 16px;
        }

        .switch-info .title {
            font-size: 14px;
            font-weight: 700;
            color: var(--md-sys-color-on-surface);
        }

        .switch-info .desc {
            font-size: 12px;
            color: var(--md-sys-color-on-surface-variant);
        }

        .switch {
            position: relative;
            display: inline-block;
            width: 48px;
            height: 26px;
            flex-shrink: 0;
        }

        .switch input {
            opacity: 0;
            width: 0;
            height: 0;
        }

        .slider {
            position: absolute;
            cursor: pointer;
            top: 0; left: 0; right: 0; bottom: 0;
            background-color: #334155;
            transition: .3s;
            border-radius: 26px;
        }

        .slider:before {
            position: absolute;
            content: "";
            height: 20px;
            width: 20px;
            left: 3px;
            bottom: 3px;
            background-color: white;
            transition: .3s;
            border-radius: 50%;
        }

        input:checked + .slider {
            background-color: var(--md-sys-color-primary);
        }

        input:checked + .slider:before {
            transform: translateX(22px);
            background-color: var(--md-sys-color-on-primary);
        }

        .form-group {
            margin-bottom: 16px;
        }

        .form-group label {
            display: block;
            font-size: 13px;
            font-weight: 600;
            color: var(--md-sys-color-on-surface-variant);
            margin-bottom: 6px;
        }

        .input-text, .textarea-text, .select-box {
            width: 100%;
            background: var(--md-sys-color-surface-dim);
            border: 1px solid rgba(255, 255, 255, 0.1);
            color: var(--md-sys-color-on-surface);
            padding: 10px 14px;
            border-radius: 10px;
            font-size: 13px;
            outline: none;
            transition: border-color 0.2s ease;
            -webkit-user-select: text;
            user-select: text;
        }

        .input-text:focus, .textarea-text:focus, .select-box:focus {
            border-color: var(--md-sys-color-primary);
        }

        .unit-group {
            display: flex;
            gap: 8px;
        }

        .unit-group input {
            flex: 2;
        }

        .unit-group select {
            flex: 1;
        }

        .textarea-text {
            resize: vertical;
            min-height: 100px;
            font-family: 'Roboto Mono', monospace;
            line-height: 1.5;
            direction: ltr;
        }

        .radio-group {
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
            margin-bottom: 16px;
        }

        .radio-card {
            background: var(--md-sys-color-surface-dim);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 12px;
            padding: 12px 18px;
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 13px;
            transition: all 0.2s ease;
        }

        .radio-card.active {
            background: rgba(56, 189, 248, 0.12);
            border-color: var(--md-sys-color-primary);
            color: var(--md-sys-color-primary);
            font-weight: 700;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }

        th, td {
            padding: 10px 14px;
            text-align: right;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        }

        th {
            color: var(--md-sys-color-on-surface-variant);
            font-weight: 600;
        }

        tr:hover td {
            background: rgba(255, 255, 255, 0.02);
        }
    </style>
</head>
<body>
    <header>
        <div class="header-title">
            <img src="/app_icon.png" alt="Icon">
            <h1>Freedom Config Collector</h1>
            <span class="badge">v2.0 • Ultra-Light</span>
        </div>
        <div style="display: flex; gap: 10px;">
            <button class="btn btn-outline" id="btn-save-all" onclick="saveAllSettings()">💾 ذخیره تنظیمات</button>
        </div>
    </header>

    <div class="tabs">
        <button class="tab-btn active" onclick="switchTab('tab-dashboard')">📊 داشبورد و اجرا</button>
        <button class="tab-btn" onclick="switchTab('tab-sources')">🌐 مدیریت منابع</button>
        <button class="tab-btn" onclick="switchTab('tab-network')">🛡️ تنظیمات اتصال و پروکسی</button>
        <button class="tab-btn" onclick="switchTab('tab-tests')">🧪 شخصی‌سازی آزمون‌ها</button>
        <button class="tab-btn" onclick="switchTab('tab-output-filters')">⚙️ فیلتر و سقف خروجی‌ها</button>
        <button class="tab-btn" onclick="switchTab('tab-telegram-bot')">✈️ ارسال خودکار به تلگرام</button>
        <button class="tab-btn" onclick="switchTab('tab-core')">⚡ مدیریت هسته میهومو</button>
        <button class="tab-btn" onclick="switchTab('tab-loop')">🔄 زمان‌بندی چرخه (لوپ)</button>
        <button class="tab-btn" onclick="switchTab('tab-analytics')">📈 گزارش تحلیلی پیشرفته</button>
    </div>

    <div class="container">
        <!-- TAB 1: DASHBOARD -->
        <div id="tab-dashboard" class="tab-content active">
            <div class="card">
                <div class="card-header">
                    <h2>🚀 کنترل فرآیند جمع‌آوری و تست</h2>
                    <span id="runner-badge" class="badge">آماده به کار</span>
                </div>
                <div style="display: flex; gap: 12px; align-items: center; margin-bottom: 16px;">
                    <button class="btn" id="btn-start" onclick="startCollector()">▶️ شروع جمع‌آوری و آزمون‌های هوشمند</button>
                    <span id="runner-status-text" style="font-size: 13px; color: var(--md-sys-color-on-surface-variant);">آماده برای شروع فرآیند...</span>
                </div>
                <div class="progress-bar-container">
                    <div id="progress-bar" class="progress-bar-fill"></div>
                </div>
                <div style="display: flex; justify-content: space-between; font-size: 11px; color: var(--md-sys-color-on-surface-variant);">
                    <span>پیشرفت عملیات</span>
                    <span id="progress-percent">0%</span>
                </div>
            </div>

            <div class="grid-3" style="margin-bottom: 20px;">
                <div class="stat-card">
                    <span class="label">📦 کل کانفیگ‌های کشف‌شده</span>
                    <span class="val" id="stat-discovered">۶۵,۹۹۵</span>
                </div>
                <div class="stat-card">
                    <span class="label">🧹 منقضی، تکراری و خراب فیلترشده</span>
                    <span class="val" id="stat-filtered" style="color: var(--md-sys-color-warning);">۵۰,۵۰۲</span>
                </div>
                <div class="stat-card">
                    <span class="label">✅ کانفیگ‌های سالم و خروجی</span>
                    <span class="val" id="stat-survivors" style="color: var(--md-sys-color-success);">۱۵,۴۹۳</span>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>📝 لاگ فرآیند زنده (Live Execution Log)</h2>
                    <button class="btn btn-outline" style="padding: 4px 12px; font-size: 11px;" onclick="clearLogs()">پاکسازی لاگ</button>
                </div>
                <div class="terminal" id="terminal-box">
                    [System] Freedom Config Collector Engine v2 آماده است.
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>📥 دریافت فایل‌های استاندارد خروجی (چند فرمتی)</h2>
                </div>
                <div style="display: flex; gap: 12px; flex-wrap: wrap;">
                    <a href="/download/proxy_provider.yaml" class="btn btn-outline" download>⚡ پروکسی پرووایدر کلش (proxy_provider.yaml)</a>
                    <a href="/download/clash_full.yaml" class="btn btn-outline" download>🐱 کانفیگ کامل میهومو (clash_full.yaml)</a>
                    <a href="/download/singbox_outbounds.json" class="btn btn-outline" download>📦 خروجی سینگ‌باکس (singbox_outbounds.json)</a>
                    <a href="/download/singbox_full.json" class="btn btn-outline" download>📦 کانفیگ کامل سینگ‌باکس (singbox_full.json)</a>
                    <a href="/download/raw_links.txt" class="btn btn-outline" download>🔗 لینک‌های خام (raw_links.txt)</a>
                    <a href="/download/sub_base64.txt" class="btn btn-outline" download>📋 سابسکریپشن Base64 (sub_base64.txt)</a>
                    <a href="/download/analytics_report.json" class="btn btn-outline" download>📊 گزارش آماری کامل (analytics_report.json)</a>
                </div>
            </div>
        </div>

        <!-- TAB 2: SOURCES -->
        <div id="tab-sources" class="tab-content">
            <div class="card">
                <div class="card-header">
                    <h2>🎯 حالت انتخاب منابع برای استخراج</h2>
                </div>
                <div class="radio-group" id="mode-group">
                    <div class="radio-card active" data-mode="all" onclick="setSourceMode('all')">
                        <span>🌟 همه منابع با هم (پیش‌فرض)</span>
                    </div>
                    <div class="radio-card" data-mode="folder" onclick="setSourceMode('folder')">
                        <span>📂 فقط پوشه فایل‌های محلی</span>
                    </div>
                    <div class="radio-card" data-mode="subscriptions" onclick="setSourceMode('subscriptions')">
                        <span>🌐 فقط لینک‌های سابسکریپشن</span>
                    </div>
                    <div class="radio-card" data-mode="telegram" onclick="setSourceMode('telegram')">
                        <span>✈️ فقط کانال‌های تلگرام</span>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>📂 پوشه فایل‌های محلی و کانتینرهای رمزگذاری‌شده</h2>
                </div>
                <div class="form-group">
                    <label>مسیر پوشه در سیستم شما:</label>
                    <input type="text" id="src-folder-path" class="input-text" style="direction: ltr;" value="G:\Ai project\10Dream\decryptor\file for test">
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>🌐 لینک‌های سابسکریپشن (Subscription URLs)</h2>
                </div>
                <div class="form-group">
                    <label>آدرس لینک‌ها (هر خط یک آدرس):</label>
                    <textarea id="src-subs-urls" class="textarea-text" rows="5"></textarea>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>✈️ کانال‌های تلگرام عمومی</h2>
                </div>
                <div class="form-group">
                    <label>آیدی کانال‌ها (هر خط یک آیدی با @):</label>
                    <textarea id="src-tg-channels" class="textarea-text" rows="5"></textarea>
                </div>
                <div class="grid-2">
                    <div class="form-group">
                        <label>حداکثر پیام‌ها برای بررسی در هر کانال:</label>
                        <input type="text" id="src-tg-max-msg" class="input-text" value="15">
                    </div>
                    <div class="form-group">
                        <label>تاخیر بین درخواست‌ها (میلی‌ثانیه):</label>
                        <input type="text" id="src-tg-delay" class="input-text" value="300">
                    </div>
                </div>
            </div>
        </div>

        <!-- TAB 3: NETWORK -->
        <div id="tab-network" class="tab-content">
            <div class="card">
                <div class="card-header">
                    <h2>🛡️ تنظیمات اتصال به اینترنت و پروکسی استخراج</h2>
                </div>
                <p style="font-size: 13px; color: var(--md-sys-color-on-surface-variant); margin-bottom: 16px;">
                    روشی که نرم‌افزار برای دانلود از کانال‌های تلگرام، سابسکریپشن‌ها و دریافت هسته میهومو استفاده می‌کند:
                </p>
                <div class="radio-group" id="net-mode-group">
                    <div class="radio-card active" data-net="system_proxy" onclick="setNetMode('system_proxy')">
                        <span>🛡️ سیستم پروکسی (System Proxy - پیش‌فرض ویندوز)</span>
                    </div>
                    <div class="radio-card" data-net="direct" onclick="setNetMode('direct')">
                        <span>⚡ دایرکت (Direct - مستقیم بدون پروکسی)</span>
                    </div>
                    <div class="radio-card" data-net="http_proxy" onclick="setNetMode('http_proxy')">
                        <span>🌐 پروکسی دستی HTTP</span>
                    </div>
                    <div class="radio-card" data-net="socks5_proxy" onclick="setNetMode('socks5_proxy')">
                        <span>🧦 پروکسی دستی SOCKS5</span>
                    </div>
                </div>

                <div id="custom-proxy-fields" class="grid-2" style="display: none; margin-top: 16px;">
                    <div class="form-group">
                        <label>آدرس آی‌پی یا هاست پروکسی:</label>
                        <input type="text" id="net-proxy-host" class="input-text" style="direction: ltr;" value="127.0.0.1">
                    </div>
                    <div class="form-group">
                        <label>پورت پروکسی:</label>
                        <input type="text" id="net-proxy-port" class="input-text" style="direction: ltr;" value="7890">
                    </div>
                </div>
            </div>
        </div>

        <!-- TAB 4: TESTS -->
        <div id="tab-tests" class="tab-content">
            <div class="card">
                <div class="card-header">
                    <h2>🧪 پروفایل‌های سریع و آماده آزمون‌ها</h2>
                </div>
                <div style="display: flex; gap: 10px; flex-wrap: wrap;">
                    <button class="btn-preset active" onclick="applyPreset('balanced')">⚖️ متعادل (پیش‌فرض سریع و دقیق)</button>
                    <button class="btn-preset" onclick="applyPreset('ultra_fast')">⚡ فوق سریع (فقط پینگ و کشور)</button>
                    <button class="btn-preset" onclick="applyPreset('rigorous')">🛡️ سخت‌گیرانه و حرفه‌ای (تمام تست‌ها)</button>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>⚙️ تنظیمات تفکیکی و پارامترهای هر آزمون</h2>
                </div>

                <!-- 1. Real Delay / Ping -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">سنجش تاخیر واقعی اتصال (Real Delay / URL Test)</span>
                        <span class="desc">بررسی پاسخ‌دهی و زمان تاخیر اتصال به سرور</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-ping" checked>
                        <span class="slider"></span>
                    </label>
                </div>
                <div class="grid-3" style="margin-bottom: 20px;">
                    <div class="form-group">
                        <label>آدرس URL آزمون پینگ:</label>
                        <input type="text" id="test-ping-url" class="input-text" style="direction: ltr;" value="http://www.gstatic.com/generate_204">
                    </div>
                    <div class="form-group">
                        <label>مهلت انتظار پاسخ (Timeout):</label>
                        <div class="unit-group">
                            <input type="text" id="test-ping-timeout-val" class="input-text" value="3">
                            <select id="test-ping-timeout-unit" class="select-box">
                                <option value="s" selected>ثانیه</option>
                                <option value="ms">میلی‌ثانیه</option>
                            </select>
                        </div>
                    </div>
                    <div class="form-group">
                        <label>تعداد همزمانی (Concurrency):</label>
                        <input type="text" id="test-ping-concurrency" class="input-text" value="30">
                    </div>
                </div>

                <!-- 2. Geo & Flag -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">تشخیص کشور و پرچم اموجی (Geo & Flag)</span>
                        <span class="desc">استعلام موقعیت واقعی سرور و الصاق پرچم کشور به ابتدای نام</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-geo" checked>
                        <span class="slider"></span>
                    </label>
                </div>

                <!-- 3. Gemini AI -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">تست هوش مصنوعی جمنای گوگل (Google Gemini AI Probe)</span>
                        <span class="desc">سنجش باز شدن و تحریم نبودن سرویس هوش مصنوعی Gemini گوگل با ۳ سطح آزمون</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-gemini">
                        <span class="slider"></span>
                    </label>
                </div>
                <div id="gemini-extra-options" style="background: rgba(255,255,255,0.03); border: 1px solid var(--md-sys-color-outline-variant); border-radius: 12px; padding: 16px; margin-bottom: 20px;">
                    <div class="grid-3" style="margin-bottom: 12px;">
                        <div class="form-group">
                            <label>سطح آزمون جمنای (Level):</label>
                            <select id="gemini-level-select" class="select-box">
                                <option value="1">سطح ۱: فقط سنجش اتصال سرور گوگل</option>
                                <option value="2" selected>سطح ۲: وب‌اپ و تحریم منطقه جغرافیایی (پیش‌فرض)</option>
                                <option value="3">سطح ۳: تست تولید واقعی با کلید API اختصاصی</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label>کلید API اختصاصی (برای سطح ۳):</label>
                            <input type="password" id="gemini-api-key" class="input-text" placeholder="AIzaSy..." style="direction: ltr;">
                        </div>
                        <div class="form-group">
                            <label>کوکی‌های حساب کاربری (اختیاری):</label>
                            <input type="text" id="gemini-cookies" class="input-text" placeholder="SID=...; HSID=..." style="direction: ltr;">
                        </div>
                    </div>
                    <div style="display: flex; gap: 12px; align-items: center;">
                        <button type="button" class="btn btn-outline" style="padding: 6px 16px; font-size: 12px;" onclick="testGeminiConnection()">🔍 تست زنده اتصال جمنای</button>
                        <span id="gemini-test-result" style="font-size: 12px; color: var(--md-sys-color-on-surface-variant);"></span>
                    </div>
                </div>

                <!-- 4. Website Accessibility -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">تست دسترسی به سایت‌های دلخواه (Website Accessibility)</span>
                        <span class="desc">بررسی دسترسی و باز شدن سایت‌های مدنظر کاربر (بدون تداخل با جمنای)</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-sites">
                        <span class="slider"></span>
                    </label>
                </div>
                <div class="form-group" style="margin-bottom: 20px;">
                    <label>آدرس سایت‌های مدنظر برای تست دسترسی (هر خط یک آدرس):</label>
                    <textarea id="test-sites-list" class="textarea-text" rows="3">https://www.youtube.com/generate_204
https://telegram.org
https://x.com</textarea>
                </div>

                <!-- 5. Download Speed -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">سنجش سرعت دانلود واقعی (Download Speed)</span>
                        <span class="desc">دریافت بسته داده تستی و محاسبه پهنای باند دانلود</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-download">
                        <span class="slider"></span>
                    </label>
                </div>
                <div class="grid-3" style="margin-bottom: 20px;">
                    <div class="form-group">
                        <label>آدرس فایل دانلود آزمایشی:</label>
                        <input type="text" id="test-down-url" class="input-text" style="direction: ltr;" value="https://speed.cloudflare.com/__down?bytes=5000000">
                    </div>
                    <div class="form-group">
                        <label>مدت زمان تست:</label>
                        <div class="unit-group">
                            <input type="text" id="test-down-duration-val" class="input-text" value="5">
                            <select id="test-down-duration-unit" class="select-box">
                                <option value="s" selected>ثانیه</option>
                            </select>
                        </div>
                    </div>
                    <div class="form-group">
                        <label>تعداد همزمانی دانلود:</label>
                        <input type="text" id="test-down-concurrency" class="input-text" value="5">
                    </div>
                </div>

                <!-- 6. UDP -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">بررسی پروتکل UDP (گیمینگ، تماس صوتی تلگرام و دیسکورد)</span>
                        <span class="desc">اطمینان از عبور بسته‌های UDP از روی کانفیگ</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-udp" checked>
                        <span class="slider"></span>
                    </label>
                </div>

                <!-- 7. Stability -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">سنجش پایداری و نوسان پینگ (Stability & Jitter)</span>
                        <span class="desc">چند بار آزمایش پیاپی برای اطمینان از عدم پرش و قطعی لحظه‌ای</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-stability" checked>
                        <span class="slider"></span>
                    </label>
                </div>

                <!-- 8. Clean IP -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">نمره تمیزی آی‌پی (Fraud Score & Clean IP)</span>
                        <span class="desc">بررسی عدم اسپم بودن آی‌پی جهت جلوگیری از خطاهای کپچا</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-fraud" checked>
                        <span class="slider"></span>
                    </label>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>🔄 تست چند مرحله‌ای با وقفه (جلوگیری از حذف اشتباهی کانفیگ‌های سالم)</h2>
                </div>
                <p style="font-size: 13px; color: var(--md-sys-color-on-surface-variant); margin-bottom: 16px;">
                    کل لیست پروکسی‌ها در چندین دور مجزا با وقفه زمانی سنجیده می‌شود تا در صورت افت لحظه‌ای کیفیت شبکه، کانفیگ‌های سالم به اشتباه حذف نشوند.
                </p>
                <div class="grid-3">
                    <div class="form-group">
                        <label>تعداد دورهای آزمون (Rounds):</label>
                        <input type="text" id="rounds-count" class="input-text" value="1">
                    </div>
                    <div class="form-group">
                        <label>وقفه استراحت بین دورها (ثانیه):</label>
                        <input type="text" id="rounds-interval" class="input-text" value="15">
                    </div>
                    <div class="form-group">
                        <label>حداقل تعداد دور قبولی برای بقا:</label>
                        <input type="text" id="rounds-min-passed" class="input-text" value="1">
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>🧹 تنظیمات فیلترها و پاکسازی</h2>
                </div>
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">فیلتر و حذف خودکار کانفیگ‌های منقضی‌شده</span>
                        <span class="desc">بررسی تاریخ انقضای فایل‌ها و حذف کانفیگ‌های تمام‌شده</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="filter-expired" checked>
                        <span class="slider"></span>
                    </label>
                </div>
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">حذف کانفیگ‌های تکراری (Deduplication)</span>
                        <span class="desc">تطبیق اثر انگشت پروتکل و حذف کانفیگ‌های همسان از منابع مختلف</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="filter-duplicates" checked>
                        <span class="slider"></span>
                    </label>
                </div>
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">حذف کانفیگ‌های ناقص و خراب</span>
                        <span class="desc">فیلتر کانفیگ‌هایی با مشخصات مخدوش یا بدون پورت معتبر</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="filter-broken" checked>
                        <span class="slider"></span>
                    </label>
                </div>
            </div>
        </div>

        <!-- TAB: OUTPUT FILTERS & CAPS -->
        <div id="tab-output-filters" class="tab-content">
            <div class="card">
                <div class="card-header">
                    <h2>🎯 فیلترها و شرایط ورود به فایل خروجی</h2>
                </div>
                <div class="grid-2" style="margin-bottom: 20px;">
                    <div class="form-group">
                        <label>حداقل امتیاز کیفی نهایی (Score):</label>
                        <input type="text" id="out-min-score" class="input-text" value="0.0">
                        <small style="color: var(--md-sys-color-on-surface-variant); font-size: 11px;">عدد بین ۰ تا ۱۰۰ (پیش‌فرض ۰ برای خروجی همه کانفیگ‌های سالم)</small>
                    </div>
                    <div class="switch-row" style="margin-top: 15px; border-bottom: none;">
                        <div class="switch-info">
                            <span class="title">فقط کانفیگ‌های موفق در هوش مصنوعی جمنای</span>
                            <span class="desc">تنها کانفیگ‌هایی صادر شوند که آزمون Gemini گوگل را پشت سر گذاشته‌اند</span>
                        </div>
                        <label class="switch">
                            <input type="checkbox" id="out-only-gemini">
                            <span class="slider"></span>
                        </label>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>📊 سقف تعداد کانفیگ برای هر پروتکل (Per-Protocol Limits)</h2>
                </div>
                <p style="font-size: 13px; color: var(--md-sys-color-on-surface-variant); margin-bottom: 16px;">
                    حداکثر تعداد کانفیگی که از هر پروتکل در فایل نهایی قرار می‌گیرد (عدد ۰ به معنی بدون سقف و نامحدود است):
                </p>
                <div class="grid-4" style="margin-bottom: 16px;">
                    <div class="form-group">
                        <label>سقف VLESS:</label>
                        <input type="text" id="cap-vless" class="input-text" value="0">
                    </div>
                    <div class="form-group">
                        <label>سقف VMess:</label>
                        <input type="text" id="cap-vmess" class="input-text" value="0">
                    </div>
                    <div class="form-group">
                        <label>سقف Trojan:</label>
                        <input type="text" id="cap-trojan" class="input-text" value="0">
                    </div>
                    <div class="form-group">
                        <label>سقف Shadowsocks:</label>
                        <input type="text" id="cap-ss" class="input-text" value="0">
                    </div>
                </div>
                <div class="grid-4">
                    <div class="form-group">
                        <label>سقف Hysteria 2:</label>
                        <input type="text" id="cap-hy2" class="input-text" value="0">
                    </div>
                    <div class="form-group">
                        <label>سقف TUIC:</label>
                        <input type="text" id="cap-tuic" class="input-text" value="0">
                    </div>
                    <div class="form-group">
                        <label>سقف OpenVPN:</label>
                        <input type="text" id="cap-openvpn" class="input-text" value="0">
                    </div>
                    <div class="form-group">
                        <label>سقف WireGuard:</label>
                        <input type="text" id="cap-wireguard" class="input-text" value="0">
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>🧠 حافظه عدم تکرار کانفیگ‌ها (Sent History Memory)</h2>
                </div>
                <div class="switch-row" style="border-bottom: none;">
                    <div class="switch-info">
                        <span class="title">فعال‌سازی حافظه عدم تکرار</span>
                        <span class="desc">کانفیگ‌هایی که در دوره‌های قبلی صادر یا به کانال فرستاده شده‌اند مجدداً صادر نمی‌شوند</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="out-filter-sent">
                        <span class="slider"></span>
                    </label>
                </div>
                <div style="display: flex; gap: 12px; align-items: center; margin-top: 16px;">
                    <button type="button" class="btn btn-outline" style="padding: 6px 16px; font-size: 12px; color: var(--md-sys-color-warning);" onclick="clearSentHistory()">🗑️ پاکسازی کامل تاریخچه کانفیگ‌های قبلی</button>
                    <span id="history-clear-status" style="font-size: 12px; color: var(--md-sys-color-on-surface-variant);"></span>
                </div>
            </div>
        </div>

        <!-- TAB: TELEGRAM BOT AUTO-SENDER -->
        <div id="tab-telegram-bot" class="tab-content">
            <div class="card">
                <div class="card-header">
                    <h2>✈️ ارسال خودکار به کانال یا چت تلگرام</h2>
                </div>
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">فعال‌سازی ارسال خودکار پس از پایان تست‌ها</span>
                        <span class="desc">با پایان یافتن آزمون‌ها، فایل‌های خروجی و گزارش تحلیلی مستقیماً به کانال تلگرام ارسال می‌شوند</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="tg-enabled">
                        <span class="slider"></span>
                    </label>
                </div>

                <div class="grid-2" style="margin-bottom: 20px;">
                    <div class="form-group">
                        <label>توکن ربات تلگرام (Bot Token):</label>
                        <input type="password" id="tg-bot-token" class="input-text" placeholder="123456789:ABCdefGhIJKlmNoPQRstuVWXyz" style="direction: ltr;">
                    </div>
                    <div class="form-group">
                        <label>شناسه کانال یا چت مقصد (Channel ID / Username):</label>
                        <input type="text" id="tg-channel-id" class="input-text" placeholder="@MyChannel یا -100123456789" style="direction: ltr;">
                    </div>
                </div>

                <div class="form-group" style="margin-bottom: 20px;">
                    <label>متن کپشن ارسالی برای فایل‌ها:</label>
                    <input type="text" id="tg-caption" class="input-text" value="💎 گلچین کانفیگ‌های تست‌شده Freedom Config Collector v2">
                </div>

                <div class="grid-2" style="margin-bottom: 20px;">
                    <div class="switch-row" style="border-bottom: none;">
                        <div class="switch-info">
                            <span class="title">ارسال فایل‌های اشتراک (Clash, Singbox, Xray)</span>
                        </div>
                        <label class="switch">
                            <input type="checkbox" id="tg-send-files" checked>
                            <span class="slider"></span>
                        </label>
                    </div>
                    <div class="switch-row" style="border-bottom: none;">
                        <div class="switch-info">
                            <span class="title">ارسال گزارش متنی و آمار در کانال</span>
                        </div>
                        <label class="switch">
                            <input type="checkbox" id="tg-send-summary" checked>
                            <span class="slider"></span>
                        </label>
                    </div>
                </div>

                <div style="display: flex; gap: 12px; align-items: center;">
                    <button type="button" class="btn btn-outline" style="padding: 6px 16px; font-size: 12px;" onclick="testTelegramConnection()">🔍 تست اتصال ربات تلگرام</button>
                    <span id="tg-test-result" style="font-size: 12px; color: var(--md-sys-color-on-surface-variant);"></span>
                </div>
            </div>
        </div>

        <!-- TAB 5: CORE MANAGER -->
        <div id="tab-core" class="tab-content">
            <div class="card">
                <div class="card-header">
                    <h2>⚡ وضعیت و مدیریت هسته رسمی میهومو (Mihomo Core)</h2>
                </div>
                <div class="grid-3" style="margin-bottom: 20px;">
                    <div class="stat-card">
                        <span class="label">وضعیت نصب هسته</span>
                        <span class="val" id="core-installed-status" style="font-size: 16px;">در حال بررسی...</span>
                    </div>
                    <div class="stat-card">
                        <span class="label">معماری پردازنده شناسایی‌شده</span>
                        <span class="val" id="core-detected-arch" style="font-size: 16px;">windows-amd64-compatible</span>
                    </div>
                    <div class="stat-card">
                        <span class="label">کانال ریلیز میهومو</span>
                        <span class="val" id="core-release-channel" style="font-size: 16px;">پایدار (Stable)</span>
                    </div>
                </div>

                <div class="grid-2" style="margin-bottom: 20px;">
                    <div class="form-group">
                        <label>معماری پردازنده جهت دانلود:</label>
                        <select id="core-arch-pref" class="select-box">
                            <option value="auto" selected>تشخیص خودکار و هوشمند (پیشنهادی)</option>
                            <option value="windows-amd64-compatible">نسخه عمومی و سازگار با سیستم‌های قدیمی (amd64-compatible)</option>
                            <option value="windows-amd64">نسخه مدرن با دستورات AVX2 (amd64)</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>کانال دریافت بروزرسانی:</label>
                        <select id="core-channel-select" class="select-box">
                            <option value="stable" selected>نسخه پایدار و رسمی (Stable)</option>
                            <option value="alpha">نسخه روزانه و آزمایشی (Alpha)</option>
                        </select>
                    </div>
                </div>

                <div style="display: flex; gap: 12px; align-items: center;">
                    <button class="btn" id="btn-download-core" onclick="downloadMihomoCore()">📥 دانلود / به‌روزرسانی خودکار هسته میهومو</button>
                    <span id="core-download-text" style="font-size: 13px; color: var(--md-sys-color-on-surface-variant);"></span>
                </div>
            </div>
        </div>

        <!-- TAB 6: LOOP SCHEDULER -->
        <div id="tab-loop" class="tab-content">
            <div class="card">
                <div class="card-header">
                    <h2>🔄 زمان‌بندی چرخه تکرار خودکار (Loop Scheduler)</h2>
                </div>
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">فعال‌سازی اجرای چرخه‌ای خودکار</span>
                        <span class="desc">برنامه به صورت مداوم در پس‌زمینه اجرا شده و کانفیگ‌های تازه را استخراج و تست می‌کند</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="sched-enabled">
                        <span class="slider"></span>
                    </label>
                </div>

                <div class="grid-2" style="margin-top: 16px;">
                    <div class="form-group">
                        <label>فاصله زمانی تکرار چرخه:</label>
                        <div class="unit-group">
                            <input type="text" id="sched-interval-val" class="input-text" value="60">
                            <select id="sched-interval-unit" class="select-box">
                                <option value="min" selected>دقیقه</option>
                                <option value="h">ساعت</option>
                            </select>
                        </div>
                    </div>
                </div>

                <div class="switch-row" style="margin-top: 10px;">
                    <div class="switch-info">
                        <span class="title">ساعات سکوت شبانه (Quiet Hours)</span>
                        <span class="desc">توقف خودکار پردازش در ساعاتی از شب جهت آسایش کاربر</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="sched-quiet-enabled">
                        <span class="slider"></span>
                    </label>
                </div>

                <div class="grid-2" style="margin-top: 10px;">
                    <div class="form-group">
                        <label>شروع ساعت سکوت (مثلاً 02:00):</label>
                        <input type="text" id="sched-quiet-start" class="input-text" value="02:00">
                    </div>
                    <div class="form-group">
                        <label>پایان ساعت سکوت (مثلاً 07:00):</label>
                        <input type="text" id="sched-quiet-end" class="input-text" value="07:00">
                    </div>
                </div>
            </div>
        </div>

        <!-- TAB 7: ANALYTICS -->
        <div id="tab-analytics" class="tab-content">
            <div class="card">
                <div class="card-header">
                    <h2>🔍 فیلتر مشاهده آمار اختصاصی یک منبع</h2>
                </div>
                <p style="font-size: 13px; color: var(--md-sys-color-on-surface-variant); margin-bottom: 12px;">
                    می‌توانید آمار کل را مشاهده کنید یا یک منبع خاص (کانال یا لینک اشتراک) را انتخاب نمایید تا آمار تفکیکی آن بررسی شود:
                </p>
                <div class="form-group">
                    <select id="analytics-source-filter" class="select-box" onchange="filterAnalyticsBySource()">
                        <option value="all">🌟 همه منابع (گزارش سراسری)</option>
                    </select>
                </div>
            </div>

            <div class="grid-2">
                <!-- Pure Protocols -->
                <div class="card">
                    <div class="card-header">
                        <h2>🧬 کارت تفکیک خالص پروتکل‌ها</h2>
                    </div>
                    <table>
                        <thead>
                            <tr><th>پروتکل</th><th>تعداد شناسایی‌شده</th><th>سازگاری میهومو</th></tr>
                        </thead>
                        <tbody id="tbl-protocols">
                            <tr><td>VLESS</td><td>۹,۸۴۰</td><td>پشتیبانی کامل ✅</td></tr>
                            <tr><td>VMess</td><td>۳,۲۱۰</td><td>پشتیبانی کامل ✅</td></tr>
                            <tr><td>Trojan</td><td>۱,۴۸۰</td><td>پشتیبانی کامل ✅</td></tr>
                            <tr><td>Shadowsocks</td><td>۵۶۸</td><td>پشتیبانی کامل ✅</td></tr>
                            <tr><td>Hysteria 2</td><td>۲۱۰</td><td>پشتیبانی کامل ✅</td></tr>
                            <tr><td>TUIC</td><td>۱۴۰</td><td>پشتیبانی کامل ✅</td></tr>
                            <tr><td>OpenVPN</td><td>۴۵</td><td>پشتیبانی کامل ✅</td></tr>
                            <tr><td>WireGuard</td><td>۱۲</td><td>پشتیبانی کامل ✅</td></tr>
                        </tbody>
                    </table>
                </div>

                <!-- Transports & Security -->
                <div class="card">
                    <div class="card-header">
                        <h2>🌐 بستر انتقال و لایه امنیت (Transports & Security)</h2>
                    </div>
                    <h3 style="font-size: 13px; color: var(--md-sys-color-primary); margin-bottom: 8px;">انواع بستر انتقال (Transports):</h3>
                    <div class="grid-2" style="margin-bottom: 16px;">
                        <div class="stat-card"><span class="label">WebSocket (WS)</span><span class="val" id="stat-trans-ws">۸,۴۲۰</span></div>
                        <div class="stat-card"><span class="label">gRPC</span><span class="val" id="stat-trans-grpc">۲,۱۵۰</span></div>
                        <div class="stat-card"><span class="label">TCP عادی</span><span class="val" id="stat-trans-tcp">۴,۲۹۰</span></div>
                        <div class="stat-card"><span class="label">HTTP / xHTTP</span><span class="val" id="stat-trans-http">۶۳۳</span></div>
                    </div>
                    <h3 style="font-size: 13px; color: var(--md-sys-color-primary); margin-bottom: 8px;">امنیت و استتار (Security):</h3>
                    <div class="grid-2">
                        <div class="stat-card"><span class="label">Reality (ضد فیلتر قوی)</span><span class="val" id="stat-sec-reality">۴,۵۱۰</span></div>
                        <div class="stat-card"><span class="label">TLS استاندارد</span><span class="val" id="stat-sec-tls">۶,۸۲۰</span></div>
                    </div>
                </div>
            </div>

            <div class="grid-2">
                <!-- Containers Decrypted -->
                <div class="card">
                    <div class="card-header">
                        <h2>📦 کانتینرهای رمزگشایی‌شده (Decrypted Containers)</h2>
                    </div>
                    <table>
                        <thead><tr><th>فرمت فایل کانتینر</th><th>تعداد فایل استخراج‌شده</th></tr></thead>
                        <tbody id="tbl-containers">
                            <tr><td>HTTP Custom (.hc)</td><td>۱۸۴</td></tr>
                            <tr><td>E-V2ray (.ehi)</td><td>۱۵۲</td></tr>
                            <tr><td>NapsternetV (.npvt / .npvs)</td><td>۱۱۸</td></tr>
                            <tr><td>HA Tunnel Plus (.hat)</td><td>۹۶</td></tr>
                            <tr><td>NetMod Syna (.nm)</td><td>۶۴</td></tr>
                            <tr><td>Dark Tunnel (.dark)</td><td>۳۸</td></tr>
                        </tbody>
                    </table>
                </div>

                <!-- Top Sources Leaderboard -->
                <div class="card">
                    <div class="card-header">
                        <h2>🏆 رتبه‌بندی برترین منابع (Leaderboard)</h2>
                    </div>
                    <table>
                        <thead><tr><th>نام منبع</th><th>کل</th><th>سالم</th><th>درصد موفقیت</th><th>پینگ</th></tr></thead>
                        <tbody id="tbl-top-sources">
                            <tr><td>@AzadNet</td><td>۴۵۰</td><td>۳۸۰</td><td>۸۴.۴٪</td><td>۱۸۰ms</td></tr>
                            <tr><td>@MatinSenPaii</td><td>۳۲۰</td><td>۲۶۰</td><td>۸۱.۲٪</td><td>۱۹۵ms</td></tr>
                            <tr><td>test.yaml</td><td>۱,۲۰۰</td><td>۹۲۰</td><td>۷۶.۶٪</td><td>۲۱۰ms</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <script>
        let currentAnalyticsData = null;

        function toPersianDigits(n) {
            if (n === null || n === undefined) return '';
            return n.toString().replace(/\d/g, d => '۰۱۲۳۴۵۶۷۸۹'[d]);
        }

        function toEnglishDigits(s) {
            if (!s) return '';
            return s.toString().replace(/[۰-۹]/g, d => '۰۱۲۳۴۵۶۷۸۹'.indexOf(d));
        }

        function switchTab(tabId) {
            document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
            document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
            document.getElementById(tabId).classList.add('active');
            event.currentTarget.classList.add('active');
        }

        function setSourceMode(mode) {
            document.querySelectorAll('#mode-group .radio-card').forEach(el => {
                el.classList.toggle('active', el.getAttribute('data-mode') === mode);
            });
        }

        function setNetMode(mode) {
            document.querySelectorAll('#net-mode-group .radio-card').forEach(el => {
                el.classList.toggle('active', el.getAttribute('data-net') === mode);
            });
            const customFields = document.getElementById('custom-proxy-fields');
            if (mode === 'http_proxy' || mode === 'socks5_proxy') {
                customFields.style.display = 'grid';
            } else {
                customFields.style.display = 'none';
            }
        }

        function clearLogs() {
            document.getElementById('terminal-box').innerHTML = '[System] لاگ پاکسازی شد.';
        }

        function applyPreset(preset) {
            document.querySelectorAll('.btn-preset').forEach(b => b.classList.remove('active'));
            event.currentTarget.classList.add('active');

            if (preset === 'ultra_fast') {
                document.getElementById('test-ping').checked = true;
                document.getElementById('test-geo').checked = true;
                document.getElementById('test-gemini').checked = false;
                document.getElementById('test-sites').checked = false;
                document.getElementById('test-download').checked = false;
                document.getElementById('test-udp').checked = false;
                document.getElementById('test-stability').checked = false;
                document.getElementById('test-fraud').checked = false;
            } else if (preset === 'balanced') {
                document.getElementById('test-ping').checked = true;
                document.getElementById('test-geo').checked = true;
                document.getElementById('test-gemini').checked = false;
                document.getElementById('test-sites').checked = false;
                document.getElementById('test-download').checked = false;
                document.getElementById('test-udp').checked = true;
                document.getElementById('test-stability').checked = true;
                document.getElementById('test-fraud').checked = true;
            } else if (preset === 'rigorous') {
                document.getElementById('test-ping').checked = true;
                document.getElementById('test-geo').checked = true;
                document.getElementById('test-gemini').checked = true;
                document.getElementById('test-sites').checked = true;
                document.getElementById('test-download').checked = true;
                document.getElementById('test-udp').checked = true;
                document.getElementById('test-stability').checked = true;
                document.getElementById('test-fraud').checked = true;
            }
        }

        async function loadInitialSettings() {
            try {
                const res = await fetch('/api/settings');
                const s = await res.json();
                
                // Sources
                if (s.sources) {
                    if (s.sources.active_mode) setSourceMode(s.sources.active_mode);
                    if (s.sources.local_folder) {
                        document.getElementById('src-folder-path').value = s.sources.local_folder.path || '';
                    }
                    if (s.sources.subscriptions && s.sources.subscriptions.urls) {
                        document.getElementById('src-subs-urls').value = s.sources.subscriptions.urls.join('\n');
                    }
                    if (s.sources.telegram) {
                        if (s.sources.telegram.channels) {
                            document.getElementById('src-tg-channels').value = s.sources.telegram.channels.join('\n');
                        }
                        if (s.sources.telegram.max_messages_per_channel) {
                            document.getElementById('src-tg-max-msg').value = s.sources.telegram.max_messages_per_channel;
                        }
                        if (s.sources.telegram.delay_ms) {
                            document.getElementById('src-tg-delay').value = s.sources.telegram.delay_ms;
                        }
                    }
                }

                // Network
                if (s.network) {
                    setNetMode(s.network.mode || 'system_proxy');
                    if (s.network.proxy_host) document.getElementById('net-proxy-host').value = s.network.proxy_host;
                    if (s.network.proxy_port) document.getElementById('net-proxy-port').value = s.network.proxy_port;
                }

                // Core Manager
                if (s.core_manager) {
                    if (s.core_manager.preferred_arch) document.getElementById('core-arch-pref').value = s.core_manager.preferred_arch;
                    if (s.core_manager.channel) document.getElementById('core-channel-select').value = s.core_manager.channel;
                }

                // Scheduler
                if (s.scheduler) {
                    document.getElementById('sched-enabled').checked = !!s.scheduler.enabled;
                    if (s.scheduler.interval_val) document.getElementById('sched-interval-val').value = s.scheduler.interval_val;
                    if (s.scheduler.interval_unit) document.getElementById('sched-interval-unit').value = s.scheduler.interval_unit;
                    document.getElementById('sched-quiet-enabled').checked = !!s.scheduler.quiet_hours_enabled;
                    if (s.scheduler.quiet_start) document.getElementById('sched-quiet-start').value = s.scheduler.quiet_start;
                    if (s.scheduler.quiet_end) document.getElementById('sched-quiet-end').value = s.scheduler.quiet_end;
                }

                // Tests
                if (s.tests) {
                    if (s.tests.ping) {
                        document.getElementById('test-ping').checked = !!s.tests.ping.enabled;
                        if (s.tests.ping.test_url) document.getElementById('test-ping-url').value = s.tests.ping.test_url;
                        if (s.tests.ping.timeout_val) document.getElementById('test-ping-timeout-val').value = s.tests.ping.timeout_val;
                        if (s.tests.ping.timeout_unit) document.getElementById('test-ping-timeout-unit').value = s.tests.ping.timeout_unit;
                        if (s.tests.ping.concurrency) document.getElementById('test-ping-concurrency').value = s.tests.ping.concurrency;
                    }
                    if (s.tests.geo_flag) document.getElementById('test-geo').checked = !!s.tests.geo_flag.enabled;
                    if (s.tests.gemini) {
                        document.getElementById('test-gemini').checked = !!s.tests.gemini.enabled;
                        if (s.tests.gemini.level && document.getElementById('gemini-level-select')) document.getElementById('gemini-level-select').value = s.tests.gemini.level;
                        if (s.tests.gemini.api_key && document.getElementById('gemini-api-key')) document.getElementById('gemini-api-key').value = s.tests.gemini.api_key;
                        if (s.tests.gemini.cookies_str && document.getElementById('gemini-cookies')) document.getElementById('gemini-cookies').value = s.tests.gemini.cookies_str;
                    }
                    if (s.tests.website_accessibility) {
                        document.getElementById('test-sites').checked = !!s.tests.website_accessibility.enabled;
                        if (s.tests.website_accessibility.sites) {
                            document.getElementById('test-sites-list').value = s.tests.website_accessibility.sites.join('\n');
                        }
                    }
                    if (s.tests.download_speed) {
                        document.getElementById('test-download').checked = !!s.tests.download_speed.enabled;
                        if (s.tests.download_speed.test_url) document.getElementById('test-down-url').value = s.tests.download_speed.test_url;
                        if (s.tests.download_speed.duration_val) document.getElementById('test-down-duration-val').value = s.tests.download_speed.duration_val;
                        if (s.tests.download_speed.duration_unit) document.getElementById('test-down-duration-unit').value = s.tests.download_speed.duration_unit;
                        if (s.tests.download_speed.concurrency) document.getElementById('test-down-concurrency').value = s.tests.download_speed.concurrency;
                    }
                    if (s.tests.udp) document.getElementById('test-udp').checked = !!s.tests.udp.enabled;
                    if (s.tests.stability) document.getElementById('test-stability').checked = !!s.tests.stability.enabled;
                    if (s.tests.fraud_score) document.getElementById('test-fraud').checked = !!s.tests.fraud_score.enabled;
                }

                // Testing rounds
                if (s.testing_rounds) {
                    if (s.testing_rounds.rounds_count && document.getElementById('rounds-count')) document.getElementById('rounds-count').value = s.testing_rounds.rounds_count;
                    if (s.testing_rounds.interval_between_rounds_sec && document.getElementById('rounds-interval')) document.getElementById('rounds-interval').value = s.testing_rounds.interval_between_rounds_sec;
                    if (s.testing_rounds.min_passed_rounds && document.getElementById('rounds-min-passed')) document.getElementById('rounds-min-passed').value = s.testing_rounds.min_passed_rounds;
                }

                // Output filters
                if (s.output_filters) {
                    if (s.output_filters.min_score !== undefined && document.getElementById('out-min-score')) document.getElementById('out-min-score').value = s.output_filters.min_score;
                    if (document.getElementById('out-only-gemini')) document.getElementById('out-only-gemini').checked = !!s.output_filters.only_gemini_passed;
                    if (document.getElementById('out-filter-sent')) document.getElementById('out-filter-sent').checked = !!s.output_filters.filter_previously_sent;
                    const caps = s.output_filters.per_protocol_limits || {};
                    if (document.getElementById('cap-vless')) document.getElementById('cap-vless').value = caps.vless || 0;
                    if (document.getElementById('cap-vmess')) document.getElementById('cap-vmess').value = caps.vmess || 0;
                    if (document.getElementById('cap-trojan')) document.getElementById('cap-trojan').value = caps.trojan || 0;
                    if (document.getElementById('cap-ss')) document.getElementById('cap-ss').value = caps.shadowsocks || caps.ss || 0;
                    if (document.getElementById('cap-hy2')) document.getElementById('cap-hy2').value = caps.hysteria2 || caps.hy2 || 0;
                    if (document.getElementById('cap-tuic')) document.getElementById('cap-tuic').value = caps.tuic || 0;
                    if (document.getElementById('cap-openvpn')) document.getElementById('cap-openvpn').value = caps.openvpn || 0;
                    if (document.getElementById('cap-wireguard')) document.getElementById('cap-wireguard').value = caps.wireguard || 0;
                }

                // Telegram sender
                if (s.telegram_sender) {
                    if (document.getElementById('tg-enabled')) document.getElementById('tg-enabled').checked = !!s.telegram_sender.enabled;
                    if (s.telegram_sender.bot_token && document.getElementById('tg-bot-token')) document.getElementById('tg-bot-token').value = s.telegram_sender.bot_token;
                    if (s.telegram_sender.channel_id && document.getElementById('tg-channel-id')) document.getElementById('tg-channel-id').value = s.telegram_sender.channel_id;
                    if (s.telegram_sender.caption && document.getElementById('tg-caption')) document.getElementById('tg-caption').value = s.telegram_sender.caption;
                    if (document.getElementById('tg-send-files')) document.getElementById('tg-send-files').checked = (s.telegram_sender.send_files !== false);
                    if (document.getElementById('tg-send-summary')) document.getElementById('tg-send-summary').checked = (s.telegram_sender.send_summary !== false);
                }

                // Filters
                if (s.filters) {
                    document.getElementById('filter-expired').checked = !!s.filters.filter_expired;
                    document.getElementById('filter-duplicates').checked = !!s.filters.filter_duplicates;
                    document.getElementById('filter-broken').checked = !!s.filters.filter_broken;
                }

                checkCoreStatus();
                loadAnalytics();
            } catch (e) {
                console.error("Load settings failed:", e);
            }
        }

        async function checkCoreStatus() {
            try {
                const res = await fetch('/api/core/status');
                const data = await res.json();
                const st = document.getElementById('core-installed-status');
                if (data.installed) {
                    st.innerText = data.version || 'نصب شده ✅';
                    st.style.color = 'var(--md-sys-color-success)';
                } else {
                    st.innerText = 'نصب نشده ⚠️';
                    st.style.color = 'var(--md-sys-color-warning)';
                }
                document.getElementById('core-detected-arch').innerText = data.detected_arch || 'windows-amd64-compatible';
            } catch (e) {}
        }

        async function downloadMihomoCore() {
            const btn = document.getElementById('btn-download-core');
            const txt = document.getElementById('core-download-text');
            btn.disabled = true;
            txt.innerText = 'در حال ارتباط با سرور و استعلام نسخه...';
            try {
                const arch = document.getElementById('core-arch-pref').value;
                const chan = document.getElementById('core-channel-select').value;
                const res = await fetch('/api/core/download', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({arch: arch, channel: chan})
                });
                const d = await res.json();
                txt.innerText = d.message || 'فرآیند دانلود آغاز شد...';
            } catch (e) {
                txt.innerText = 'خطا در ارسال دستور: ' + e;
                btn.disabled = false;
            }
        }

        async function saveAllSettings() {
            const btn = document.getElementById('btn-save-all');
            btn.innerText = '⏳ در حال ذخیره...';

            const activeCard = document.querySelector('#mode-group .radio-card.active');
            const activeMode = activeCard ? activeCard.getAttribute('data-mode') : 'all';

            const activeNetCard = document.querySelector('#net-mode-group .radio-card.active');
            const activeNet = activeNetCard ? activeNetCard.getAttribute('data-net') : 'system_proxy';

            const payload = {
                sources: {
                    active_mode: activeMode,
                    local_folder: {
                        enabled: true,
                        path: document.getElementById('src-folder-path').value
                    },
                    subscriptions: {
                        enabled: true,
                        urls: document.getElementById('src-subs-urls').value.split('\n').map(l => l.trim()).filter(l => l)
                    },
                    telegram: {
                        enabled: true,
                        channels: document.getElementById('src-tg-channels').value.split('\n').map(l => l.trim()).filter(l => l),
                        max_messages_per_channel: parseInt(toEnglishDigits(document.getElementById('src-tg-max-msg').value)) || 15,
                        delay_ms: parseInt(toEnglishDigits(document.getElementById('src-tg-delay').value)) || 300
                    }
                },
                network: {
                    mode: activeNet,
                    proxy_host: document.getElementById('net-proxy-host').value,
                    proxy_port: parseInt(toEnglishDigits(document.getElementById('net-proxy-port').value)) || 7890
                },
                core_manager: {
                    preferred_arch: document.getElementById('core-arch-pref').value,
                    channel: document.getElementById('core-channel-select').value
                },
                scheduler: {
                    enabled: document.getElementById('sched-enabled').checked,
                    interval_val: parseFloat(toEnglishDigits(document.getElementById('sched-interval-val').value)) || 60,
                    interval_unit: document.getElementById('sched-interval-unit').value,
                    quiet_hours_enabled: document.getElementById('sched-quiet-enabled').checked,
                    quiet_start: document.getElementById('sched-quiet-start').value,
                    quiet_end: document.getElementById('sched-quiet-end').value
                },
                tests: {
                    ping: {
                        enabled: document.getElementById('test-ping').checked,
                        test_url: document.getElementById('test-ping-url').value,
                        timeout_val: parseFloat(toEnglishDigits(document.getElementById('test-ping-timeout-val').value)) || 3,
                        timeout_unit: document.getElementById('test-ping-timeout-unit').value,
                        concurrency: parseInt(toEnglishDigits(document.getElementById('test-ping-concurrency').value)) || 30
                    },
                    geo_flag: { enabled: document.getElementById('test-geo').checked },
                    gemini: {
                        enabled: document.getElementById('test-gemini').checked,
                        level: parseInt(document.getElementById('gemini-level-select') ? document.getElementById('gemini-level-select').value : 2) || 2,
                        api_key: document.getElementById('gemini-api-key') ? document.getElementById('gemini-api-key').value.trim() : "",
                        cookies_str: document.getElementById('gemini-cookies') ? document.getElementById('gemini-cookies').value.trim() : "",
                        timeout_val: 8,
                        timeout_unit: "s",
                        concurrency: 15
                    },
                    website_accessibility: {
                        enabled: document.getElementById('test-sites').checked,
                        sites: document.getElementById('test-sites-list').value.split('\n').map(l => l.trim()).filter(l => l)
                    },
                    download_speed: {
                        enabled: document.getElementById('test-download').checked,
                        test_url: document.getElementById('test-down-url').value,
                        duration_val: parseFloat(toEnglishDigits(document.getElementById('test-down-duration-val').value)) || 5,
                        duration_unit: document.getElementById('test-down-duration-unit').value,
                        concurrency: parseInt(toEnglishDigits(document.getElementById('test-down-concurrency').value)) || 5
                    },
                    udp: { enabled: document.getElementById('test-udp').checked },
                    stability: { enabled: document.getElementById('test-stability').checked },
                    fraud_score: { enabled: document.getElementById('test-fraud').checked }
                },
                testing_rounds: {
                    rounds_count: parseInt(toEnglishDigits(document.getElementById('rounds-count') ? document.getElementById('rounds-count').value : "1")) || 1,
                    interval_between_rounds_sec: parseFloat(toEnglishDigits(document.getElementById('rounds-interval') ? document.getElementById('rounds-interval').value : "15")) || 15,
                    min_passed_rounds: parseInt(toEnglishDigits(document.getElementById('rounds-min-passed') ? document.getElementById('rounds-min-passed').value : "1")) || 1
                },
                output_filters: {
                    min_score: parseFloat(toEnglishDigits(document.getElementById('out-min-score') ? document.getElementById('out-min-score').value : "0")) || 0.0,
                    only_gemini_passed: document.getElementById('out-only-gemini') ? document.getElementById('out-only-gemini').checked : false,
                    filter_previously_sent: document.getElementById('out-filter-sent') ? document.getElementById('out-filter-sent').checked : false,
                    per_protocol_limits: {
                        vless: parseInt(toEnglishDigits(document.getElementById('cap-vless') ? document.getElementById('cap-vless').value : "0")) || 0,
                        vmess: parseInt(toEnglishDigits(document.getElementById('cap-vmess') ? document.getElementById('cap-vmess').value : "0")) || 0,
                        trojan: parseInt(toEnglishDigits(document.getElementById('cap-trojan') ? document.getElementById('cap-trojan').value : "0")) || 0,
                        shadowsocks: parseInt(toEnglishDigits(document.getElementById('cap-ss') ? document.getElementById('cap-ss').value : "0")) || 0,
                        hysteria2: parseInt(toEnglishDigits(document.getElementById('cap-hy2') ? document.getElementById('cap-hy2').value : "0")) || 0,
                        tuic: parseInt(toEnglishDigits(document.getElementById('cap-tuic') ? document.getElementById('cap-tuic').value : "0")) || 0,
                        openvpn: parseInt(toEnglishDigits(document.getElementById('cap-openvpn') ? document.getElementById('cap-openvpn').value : "0")) || 0,
                        wireguard: parseInt(toEnglishDigits(document.getElementById('cap-wireguard') ? document.getElementById('cap-wireguard').value : "0")) || 0
                    }
                },
                telegram_sender: {
                    enabled: document.getElementById('tg-enabled') ? document.getElementById('tg-enabled').checked : false,
                    bot_token: document.getElementById('tg-bot-token') ? document.getElementById('tg-bot-token').value.trim() : "",
                    channel_id: document.getElementById('tg-channel-id') ? document.getElementById('tg-channel-id').value.trim() : "",
                    caption: document.getElementById('tg-caption') ? document.getElementById('tg-caption').value.trim() : "",
                    send_files: document.getElementById('tg-send-files') ? document.getElementById('tg-send-files').checked : true,
                    send_summary: document.getElementById('tg-send-summary') ? document.getElementById('tg-send-summary').checked : true
                },
                filters: {
                    filter_expired: document.getElementById('filter-expired').checked,
                    filter_duplicates: document.getElementById('filter-duplicates').checked,
                    filter_broken: document.getElementById('filter-broken').checked
                }
            };

            try {
                const res = await fetch('/api/save_settings', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                const d = await res.json();
                if (d.ok) {
                    btn.innerText = '✅ ذخیره شد';
                    setTimeout(() => { btn.innerText = '💾 ذخیره تنظیمات'; }, 1800);
                } else {
                    btn.innerText = '❌ خطا';
                }
            } catch (e) {
                btn.innerText = '❌ خطا در ذخیره';
            }
        }

        async function testTelegramConnection() {
            const resEl = document.getElementById('tg-test-result');
            const token = document.getElementById('tg-bot-token').value.trim();
            if (!token) {
                resEl.innerText = '⚠️ ابتدا توکن ربات را وارد کنید';
                resEl.style.color = 'var(--md-sys-color-warning)';
                return;
            }
            resEl.innerText = '⏳ در حال تست اتصال به تلگرام...';
            resEl.style.color = 'var(--md-sys-color-primary)';
            try {
                const res = await fetch('/api/test_telegram', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({bot_token: token})
                });
                const d = await res.json();
                if (d.ok) {
                    resEl.innerText = '✅ ' + (d.message || 'اتصال ربات تایید شد!');
                    resEl.style.color = 'var(--md-sys-color-success)';
                } else {
                    resEl.innerText = '❌ ' + (d.message || d.error || 'خطا در اتصال');
                    resEl.style.color = 'var(--md-sys-color-error)';
                }
            } catch (e) {
                resEl.innerText = '❌ خطا: ' + e;
                resEl.style.color = 'var(--md-sys-color-error)';
            }
        }

        async function testGeminiConnection() {
            const resEl = document.getElementById('gemini-test-result');
            const level = parseInt(document.getElementById('gemini-level-select') ? document.getElementById('gemini-level-select').value : 2) || 2;
            const apiKey = document.getElementById('gemini-api-key') ? document.getElementById('gemini-api-key').value.trim() : "";
            const cookies = document.getElementById('gemini-cookies') ? document.getElementById('gemini-cookies').value.trim() : "";

            resEl.innerText = '⏳ در حال تست دسترسی به هوش مصنوعی جمنای...';
            resEl.style.color = 'var(--md-sys-color-primary)';
            try {
                const res = await fetch('/api/test_gemini', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({level: level, api_key: apiKey, cookies_str: cookies})
                });
                const d = await res.json();
                if (d.ok) {
                    resEl.innerText = '✅ ' + (d.message || 'دسترسی به جمنای برقرار است!');
                    resEl.style.color = 'var(--md-sys-color-success)';
                } else {
                    resEl.innerText = '❌ ' + (d.message || 'خطا در اتصال به جمنای');
                    resEl.style.color = 'var(--md-sys-color-error)';
                }
            } catch (e) {
                resEl.innerText = '❌ خطا: ' + e;
                resEl.style.color = 'var(--md-sys-color-error)';
            }
        }

        async function clearSentHistory() {
            const resEl = document.getElementById('history-clear-status');
            resEl.innerText = '⏳ در حال پاکسازی...';
            try {
                const res = await fetch('/api/clear_history', {method: 'POST'});
                const d = await res.json();
                resEl.innerText = d.message || '✅ پاکسازی شد';
                resEl.style.color = 'var(--md-sys-color-success)';
                setTimeout(() => { resEl.innerText = ''; }, 3000);
            } catch (e) {
                resEl.innerText = '❌ خطا در پاکسازی';
                resEl.style.color = 'var(--md-sys-color-error)';
            }
        }

        async function startCollector() {
            const btn = document.getElementById('btn-start');
            btn.disabled = true;
            try {
                await saveAllSettings();
                await fetch('/api/run', { method: 'POST' });
            } catch (e) {
                console.error("Start failed:", e);
                btn.disabled = false;
            }
        }

        async function loadAnalytics() {
            try {
                const res = await fetch('/api/analytics');
                const data = await res.json();
                if (!data || !data.protocol_breakdown) return;
                currentAnalyticsData = data;

                // Populate source filter dropdown
                const sel = document.getElementById('analytics-source-filter');
                sel.innerHTML = '<option value="all">🌟 همه منابع (گزارش سراسری)</option>';
                if (data.per_source_map) {
                    for (const [srcName, srcInfo] of Object.entries(data.per_source_map)) {
                        const opt = document.createElement('option');
                        opt.value = srcName;
                        opt.innerText = `${srcInfo.type === 'telegram' ? '✈️' : (srcInfo.type === 'container' ? '📦' : '🌐')} ${srcName} (${srcInfo.discovered} کانفیگ)`;
                        sel.appendChild(opt);
                    }
                }

                renderAnalytics(data);
            } catch (e) {}
        }

        function filterAnalyticsBySource() {
            if (!currentAnalyticsData) return;
            const srcKey = document.getElementById('analytics-source-filter').value;
            if (srcKey === 'all') {
                renderAnalytics(currentAnalyticsData);
            } else {
                const srcInfo = currentAnalyticsData.per_source_map[srcKey];
                if (srcInfo) {
                    renderSourceSpecificAnalytics(srcInfo);
                }
            }
        }

        function renderAnalytics(data) {
            // Protocols Table
            const tblProto = document.getElementById('tbl-protocols');
            tblProto.innerHTML = '';
            for (const [p, count] of Object.entries(data.protocol_breakdown || {})) {
                tblProto.innerHTML += `<tr><td><strong>${p.toUpperCase()}</strong></td><td>${toPersianDigits(count)}</td><td>پشتیبانی کامل ✅</td></tr>`;
            }

            // Transports
            const tr = data.transports || {};
            document.getElementById('stat-trans-ws').innerText = toPersianDigits(tr.ws || 0);
            document.getElementById('stat-trans-grpc').innerText = toPersianDigits(tr.grpc || 0);
            document.getElementById('stat-trans-tcp').innerText = toPersianDigits(tr.tcp || 0);
            document.getElementById('stat-trans-http').innerText = toPersianDigits(tr.http || 0);

            // Security
            const sec = data.security || {};
            document.getElementById('stat-sec-reality').innerText = toPersianDigits(sec.reality || 0);
            document.getElementById('stat-sec-tls').innerText = toPersianDigits(sec.tls || 0);

            // Containers
            const tblCont = document.getElementById('tbl-containers');
            tblCont.innerHTML = '';
            for (const [ext, count] of Object.entries(data.containers || {})) {
                tblCont.innerHTML += `<tr><td>${ext}</td><td>${toPersianDigits(count)}</td></tr>`;
            }

            // Top sources
            const tblSrc = document.getElementById('tbl-top-sources');
            tblSrc.innerHTML = '';
            (data.top_sources || []).slice(0, 10).forEach(s => {
                tblSrc.innerHTML += `<tr><td><code>${s.source}</code></td><td>${toPersianDigits(s.discovered)}</td><td>${toPersianDigits(s.alive)}</td><td>${toPersianDigits(s.survival_rate)}٪</td><td>${toPersianDigits(s.avg_ping_ms)}ms</td></tr>`;
            });
        }

        function renderSourceSpecificAnalytics(srcInfo) {
            // Protocols Table for this source
            const tblProto = document.getElementById('tbl-protocols');
            tblProto.innerHTML = '';
            for (const [p, count] of Object.entries(srcInfo.protocols || {})) {
                tblProto.innerHTML += `<tr><td><strong>${p.toUpperCase()}</strong></td><td>${toPersianDigits(count)}</td><td>پشتیبانی کامل ✅</td></tr>`;
            }

            // Transports
            const tr = srcInfo.transports || {};
            document.getElementById('stat-trans-ws').innerText = toPersianDigits(tr.ws || 0);
            document.getElementById('stat-trans-grpc').innerText = toPersianDigits(tr.grpc || 0);
            document.getElementById('stat-trans-tcp').innerText = toPersianDigits(tr.tcp || 0);
            document.getElementById('stat-trans-http').innerText = toPersianDigits(tr.http || 0);

            // Security
            const sec = srcInfo.security || {};
            document.getElementById('stat-sec-reality').innerText = toPersianDigits(sec.reality || 0);
            document.getElementById('stat-sec-tls').innerText = toPersianDigits(sec.tls || 0);
        }

        async function pollStatus() {
            try {
                const res = await fetch('/api/status');
                const st = await res.json();
                
                const btn = document.getElementById('btn-start');
                const badge = document.getElementById('runner-badge');
                const statusTxt = document.getElementById('runner-status-text');
                const pFill = document.getElementById('progress-bar');
                const pTxt = document.getElementById('progress-percent');
                const term = document.getElementById('terminal-box');

                if (st.running) {
                    btn.disabled = true;
                    badge.innerText = 'در حال اجرا...';
                    badge.style.borderColor = 'var(--md-sys-color-warning)';
                    badge.style.color = 'var(--md-sys-color-warning)';
                } else {
                    btn.disabled = false;
                    badge.innerText = 'آماده به کار';
                    badge.style.borderColor = 'rgba(56, 189, 248, 0.3)';
                    badge.style.color = 'var(--md-sys-color-primary)';
                }

                statusTxt.innerText = st.status_text || '';
                pFill.style.width = (st.progress || 0) + '%';
                pTxt.innerText = toPersianDigits(st.progress || 0) + '%';

                if (st.logs && st.logs.length) {
                    term.innerHTML = st.logs.join('\n');
                    term.scrollTop = term.scrollHeight;
                }

                // Check core download status if downloading
                const cRes = await fetch('/api/core/download_status');
                const cData = await cRes.json();
                const cTxt = document.getElementById('core-download-text');
                const cBtn = document.getElementById('btn-download-core');
                if (cData.downloading) {
                    cTxt.innerText = cData.status_text;
                    cBtn.disabled = true;
                } else {
                    if (cData.status_text !== 'آماده') {
                        cTxt.innerText = cData.status_text;
                    }
                    cBtn.disabled = false;
                }

            } catch (e) {}
        }

        loadInitialSettings();
        setInterval(pollStatus, 1500);
    </script>
</body>
</html>
"""

class GUIHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        if url.path in ["/", "/index.html"]:
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode("utf-8"))
        elif url.path == "/app_icon.png":
            icon_path = os.path.join(BASE_DIR, "app_icon.png")
            if os.path.exists(icon_path):
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.end_headers()
                with open(icon_path, "rb") as f:
                    self.wfile.write(f.read())
            else:
                self.send_response(404)
                self.end_headers()
        elif url.path in ["/favicon.ico", "/app_icon.ico"]:
            icon_path = os.path.join(BASE_DIR, "app_icon.ico")
            if os.path.exists(icon_path):
                self.send_response(200)
                self.send_header("Content-Type", "image/x-icon")
                self.end_headers()
                with open(icon_path, "rb") as f:
                    self.wfile.write(f.read())
            else:
                self.send_response(404)
                self.end_headers()
        elif url.path == "/api/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps(RUNNER_STATE, ensure_ascii=False).encode("utf-8"))
        elif url.path == "/api/settings":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps(load_settings(), ensure_ascii=False).encode("utf-8"))
        elif url.path == "/api/core/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            c_info = {"installed": False, "version": None, "detected_arch": "windows-amd64-compatible"}
            if core_manager:
                loc = core_manager.get_local_core_info()
                arch = core_manager.detect_cpu_architecture()
                c_info = {
                    "installed": loc.get("installed", False),
                    "version": loc.get("version"),
                    "detected_arch": arch,
                    "message_fa": loc.get("message_fa")
                }
            self.wfile.write(json.dumps(c_info, ensure_ascii=False).encode("utf-8"))
        elif url.path == "/api/core/download_status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps(CORE_DOWNLOAD_STATE, ensure_ascii=False).encode("utf-8"))
        elif url.path == "/api/analytics":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            report_file = os.path.join(OUTPUT_DIR, "analytics_report.json")
            if os.path.exists(report_file):
                with open(report_file, "r", encoding="utf-8") as f:
                    self.wfile.write(f.read().encode("utf-8"))
            else:
                self.wfile.write(b'{}')
        elif url.path.startswith("/download/"):
            filename = os.path.basename(url.path)
            filepath = os.path.join(OUTPUT_DIR, filename)
            if os.path.exists(filepath):
                self.send_response(200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
                self.end_headers()
                with open(filepath, "rb") as f:
                    self.wfile.write(f.read())
            else:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        url = urllib.parse.urlparse(self.path)
        if url.path == "/api/run":
            if not RUNNER_STATE["running"]:
                t = threading.Thread(target=run_collector_task, daemon=True)
                t.start()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"started"}')
        elif url.path == "/api/core/download":
            content_len = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_len).decode("utf-8") if content_len else "{}"
            req_data = json.loads(body) if body else {}
            
            def dl_worker():
                global CORE_DOWNLOAD_STATE
                CORE_DOWNLOAD_STATE["downloading"] = True
                CORE_DOWNLOAD_STATE["progress"] = 10
                CORE_DOWNLOAD_STATE["status_text"] = "در حال اتصال به گیت‌هاب..."
                
                def cb(pct, text):
                    CORE_DOWNLOAD_STATE["progress"] = pct
                    CORE_DOWNLOAD_STATE["status_text"] = text

                if core_manager:
                    res = core_manager.download_and_install_core(
                        arch_pref=req_data.get("arch", "auto"),
                        channel=req_data.get("channel", "stable"),
                        proxy_dict={'http': 'http://127.0.0.1:7890', 'https': 'http://127.0.0.1:7890'},
                        progress_cb=cb
                    )
                    CORE_DOWNLOAD_STATE["status_text"] = res.get("message_fa", "عملیات هسته انجام شد")
                CORE_DOWNLOAD_STATE["downloading"] = False

            threading.Thread(target=dl_worker, daemon=True).start()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": True, "message": "دانلود هسته آغاز شد"}, ensure_ascii=False).encode("utf-8"))
        elif url.path == "/api/save_settings":
            content_len = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_len).decode("utf-8")
            try:
                data = json.loads(body)
                current = load_settings()
                for k, v in data.items():
                    if isinstance(v, dict) and k in current and isinstance(current[k], dict):
                        current[k].update(v)
                    else:
                        current[k] = v
                save_settings(current)
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"ok":true}')
            except Exception as e:
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"ok": False, "error": str(e)}).encode("utf-8"))
        elif url.path == "/api/test_telegram":
            content_len = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_len).decode("utf-8") if content_len else "{}"
            req_data = json.loads(body) if body else {}
            bot_token = req_data.get("bot_token", "")
            res = {"ok": False, "message": "ماژول ارسال تلگرام در دسترس نیست"}
            if telegram_sender:
                res = telegram_sender.test_bot_token(bot_token)
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode("utf-8"))
        elif url.path == "/api/test_gemini":
            content_len = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_len).decode("utf-8") if content_len else "{}"
            req_data = json.loads(body) if body else {}
            lvl = int(req_data.get("level", 2))
            key = req_data.get("api_key", "").strip()
            cookies = req_data.get("cookies_str", "").strip()
            res = {"ok": False, "message": "ماژول ارزیابی هوش مصنوعی در دسترس نیست"}
            if gemini_tester:
                check_res = gemini_tester.run_gemini_test(level=lvl, api_key=key, cookies_str=cookies, timeout=10.0)
                res = {"ok": (check_res.get("status") == "ok"), "message": check_res.get("message", "")}
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode("utf-8"))
        elif url.path == "/api/clear_history":
            if exporter:
                exporter.save_sent_history(set())
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": True, "message": "تاریخچه ارسال با موفقیت پاکسازی شد"}, ensure_ascii=False).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass

def find_edge_or_chrome():
    candidates = [
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None

def launch_desktop_window(url):
    browser_path = find_edge_or_chrome()
    if browser_path:
        subprocess.Popen([browser_path, f"--app={url}", "--window-size=1280,870"])
    else:
        import webbrowser
        webbrowser.open(url)

def launch_tray_icon():
    tray_script = os.path.join(BASE_DIR, "tools", "tray_helper.ps1")
    if os.path.exists(tray_script):
        try:
            creation_flag = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
            subprocess.Popen([
                "powershell", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass",
                "-File", tray_script, "-Port", str(PORT),
                "-IconPath", os.path.join(BASE_DIR, "app_icon.ico")
            ], creationflags=creation_flag)
        except Exception as e:
            print("Tray launch error:", e)

def main():
    server = HTTPServer(("127.0.0.1", PORT), GUIHandler)
    url = f"http://127.0.0.1:{PORT}"
    threading.Thread(target=lambda: (time.sleep(0.6), launch_desktop_window(url)), daemon=True).start()
    threading.Thread(target=lambda: (time.sleep(1.2), launch_tray_icon()), daemon=True).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
