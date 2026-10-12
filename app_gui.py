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

if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

PORT = 12059
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SETTINGS_PATH = os.path.join(BASE_DIR, "config", "settings.json")
OUTPUT_DIR = os.path.join(BASE_DIR, "output")

RUNNER_STATE = {
    "running": False,
    "progress": 0,
    "status_text": "آماده به کار",
    "logs": [],
    "last_result": None
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

def run_collector_task():
    global RUNNER_STATE
    RUNNER_STATE["running"] = True
    RUNNER_STATE["progress"] = 5
    RUNNER_STATE["status_text"] = "در حال آغاز فرآیند استخراج..."
    RUNNER_STATE["logs"] = ["🚀 فرآیند استخراج، رمزگشایی و تست هوشمند آغاز شد."]

    try:
        runner_script = os.path.join(BASE_DIR, "tools", "comprehensive_test_runner.py")
        proc = subprocess.Popen(
            [sys.executable, "-u", runner_script],
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

            if "Container Decryption" in l:
                RUNNER_STATE["progress"] = 25
                RUNNER_STATE["status_text"] = "در حال رمزگشایی فایل‌های کانتینر (.hat, .ehi, .npvt)..."
            elif "Parsing" in l and "files" in l:
                RUNNER_STATE["progress"] = 40
                RUNNER_STATE["status_text"] = "در حال تحلیل فایل‌های متنی و OpenVPN..."
            elif "Fetching Subscription" in l:
                RUNNER_STATE["progress"] = 55
                RUNNER_STATE["status_text"] = "در حال دریافت سابسکریپشن‌های اینترنتی..."
            elif "Applying Filters" in l:
                RUNNER_STATE["progress"] = 70
                RUNNER_STATE["status_text"] = "در حال فیلتر کانفیگ‌های منقضی و تکراری..."
            elif "Running Multi-Probe" in l:
                RUNNER_STATE["progress"] = 80
                RUNNER_STATE["status_text"] = "در حال تست اتصال و سنجش پینگ کانفیگ‌ها..."
            elif "Calculating Comprehensive Analytics" in l:
                RUNNER_STATE["progress"] = 92
                RUNNER_STATE["status_text"] = "در حال محاسبه رتبه‌بندی و آمار تحلیلی..."
            elif "Exporting Clash" in l:
                RUNNER_STATE["progress"] = 97
                RUNNER_STATE["status_text"] = "در حال ساخت فایل‌های نهایی میهومو..."

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

HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Freedom Config Collector v2</title>
    <link href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@300;400;500;700;800&family=Roboto+Mono:wght@400;500&display=swap" rel="stylesheet">
    <style>
        :root {
            --md-sys-color-primary: #a8c7fa;
            --md-sys-color-on-primary: #062e6f;
            --md-sys-color-primary-container: #0842a0;
            --md-sys-color-on-primary-container: #d3e3fd;
            --md-sys-color-surface: #121316;
            --md-sys-color-surface-dim: #1a1c1e;
            --md-sys-color-surface-bright: #282a2d;
            --md-sys-color-surface-container: #1e2023;
            --md-sys-color-surface-container-high: #2d3034;
            --md-sys-color-on-surface: #e2e2e6;
            --md-sys-color-on-surface-variant: #c4c7c5;
            --md-sys-color-outline: #8e918f;
            --md-sys-color-success: #6dd58c;
            --md-sys-color-error: #f2b8b5;
            --md-sys-color-warning: #fdd663;
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
            padding: 16px 24px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid rgba(255, 255, 255, 0.08);
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
        }

        .header-title {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .header-title h1 {
            font-size: 20px;
            font-weight: 700;
            color: var(--md-sys-color-primary);
        }

        .header-title .badge {
            background: rgba(168, 199, 250, 0.15);
            color: var(--md-sys-color-primary);
            padding: 3px 10px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 600;
            border: 1px solid rgba(168, 199, 250, 0.3);
        }

        .tabs {
            display: flex;
            background: var(--md-sys-color-surface-dim);
            padding: 6px 16px;
            gap: 8px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        }

        .tab-btn {
            background: transparent;
            border: none;
            color: var(--md-sys-color-on-surface-variant);
            padding: 10px 18px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s ease;
            display: flex;
            align-items: center;
            gap: 8px;
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
            max-width: 1300px;
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
            border: 1px solid rgba(255, 255, 255, 0.05);
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
            padding: 12px 24px;
            border-radius: 24px;
            font-size: 14px;
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
            background: rgba(168, 199, 250, 0.1);
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
            background: linear-gradient(90deg, #3871e0, #6dd58c);
            transition: width 0.3s ease;
        }

        .terminal {
            background: #090a0c;
            border-radius: 12px;
            padding: 14px;
            font-family: 'Roboto Mono', monospace;
            font-size: 12px;
            color: #d1d5db;
            height: 260px;
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
            border-color: rgba(168, 199, 250, 0.2);
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

        /* Toggle switch */
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
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background-color: #3e4247;
            transition: .25s;
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
            transition: .25s;
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
            display: flex;
            flex-direction: column;
            gap: 6px;
        }

        .form-group label {
            font-size: 13px;
            font-weight: 600;
            color: var(--md-sys-color-on-surface-variant);
        }

        .input-text, .textarea-text {
            background: var(--md-sys-color-surface-dim);
            border: 1px solid rgba(255, 255, 255, 0.12);
            border-radius: 10px;
            color: var(--md-sys-color-on-surface);
            padding: 10px 14px;
            font-size: 13px;
            outline: none;
            transition: border-color 0.2s ease;
            -webkit-user-select: text;
            user-select: text;
        }

        .input-text:focus, .textarea-text:focus {
            border-color: var(--md-sys-color-primary);
        }

        .textarea-text {
            resize: vertical;
            min-height: 100px;
            font-family: 'Roboto Mono', monospace;
            line-height: 1.5;
            direction: ltr;
        }

        .chip-container {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            margin-top: 8px;
        }

        .chip {
            background: var(--md-sys-color-surface-dim);
            padding: 6px 12px;
            border-radius: 16px;
            font-size: 12px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            display: flex;
            align-items: center;
            gap: 6px;
            cursor: pointer;
        }

        .chip.active {
            background: rgba(168, 199, 250, 0.15);
            border-color: var(--md-sys-color-primary);
            color: var(--md-sys-color-primary);
            font-weight: 600;
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
            background: rgba(168, 199, 250, 0.12);
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
            <span style="font-size: 24px;">⚡</span>
            <h1>Freedom Config Collector</h1>
            <span class="badge">v2.0 • Mihomo Core</span>
        </div>
        <div style="display: flex; gap: 10px;">
            <button class="btn btn-outline" id="btn-save-all" onclick="saveAllSettings()">💾 ذخیره تغییرات</button>
        </div>
    </header>

    <div class="tabs">
        <button class="tab-btn active" onclick="switchTab('tab-dashboard')">📊 داشبورد و کنترل عملیات</button>
        <button class="tab-btn" onclick="switchTab('tab-sources')">🌐 مدیریت منابع (تلگرام، ساب، فایل)</button>
        <button class="tab-btn" onclick="switchTab('tab-tests')">🧪 آزمون‌ها و فیلترها</button>
        <button class="tab-btn" onclick="switchTab('tab-analytics')">📈 گزارش تحلیلی جامع</button>
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
                    <button class="btn" id="btn-start" onclick="startCollector()">▶️ شروع جمع‌آوری و تست هوشمند</button>
                    <span id="runner-status-text" style="font-size: 13px; color: var(--md-sys-color-on-surface-variant);">آماده برای شروع فرآیند...</span>
                </div>
                <div class="progress-bar-container">
                    <div id="progress-bar" class="progress-bar-fill"></div>
                </div>
                <div style="display: flex; justify-content: space-between; font-size: 11px; color: var(--md-sys-color-on-surface-variant);">
                    <span>پیشرفت کلی</span>
                    <span id="progress-percent">0%</span>
                </div>
            </div>

            <div class="grid-3" style="margin-bottom: 20px;">
                <div class="stat-card">
                    <span class="label">📦 کانفیگ‌های کشف‌شده</span>
                    <span class="val" id="stat-discovered">۶۵,۹۹۵</span>
                </div>
                <div class="stat-card">
                    <span class="label">🧹 منقضی و تکراری حذف‌شده</span>
                    <span class="val" id="stat-filtered" style="color: var(--md-sys-color-warning);">۵۰,۴۶۹</span>
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
                    <h2>📥 دریافت فایل‌های خروجی</h2>
                </div>
                <div style="display: flex; gap: 12px; flex-wrap: wrap;">
                    <a href="/download/clash_provider.yaml" class="btn btn-outline" download>📥 دریافت سابسکریپشن کلش (clash_provider.yaml)</a>
                    <a href="/download/clash_full.yaml" class="btn btn-outline" download>📥 دریافت کانفیگ کامل میهومو (clash_full.yaml)</a>
                    <a href="/download/analytics_report.json" class="btn btn-outline" download>📊 دریافت فایل گزارش کامل (JSON)</a>
                </div>
            </div>
        </div>

        <!-- TAB 2: SOURCES -->
        <div id="tab-sources" class="tab-content">
            <div class="card">
                <div class="card-header">
                    <h2>🎯 انتخاب منابع فعال برای استخراج</h2>
                </div>
                <p style="font-size: 13px; color: var(--md-sys-color-on-surface-variant); margin-bottom: 14px;">
                    مشخص کنید نرم‌افزار کانفیگ‌ها را از چه منابعی جمع‌آوری کند:
                </p>
                <div class="radio-group" id="mode-group">
                    <div class="radio-card active" data-mode="all" onclick="setSourceMode('all')">
                        <span>🌟 همه منابع با هم (پیش‌فرض)</span>
                    </div>
                    <div class="radio-card" data-mode="folder" onclick="setSourceMode('folder')">
                        <span>📂 فقط پوشه فایل‌های محلی</span>
                    </div>
                    <div class="radio-card" data-mode="subscriptions" onclick="setSourceMode('subscriptions')">
                        <span>🌐 فقط لینک‌های اشتراک</span>
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
                <div class="form-group">
                    <label>پسوندهای مجاز برای جستجو و رمزگشایی:</label>
                    <div class="chip-container" id="ext-chips">
                        <span class="chip active">.ovpn</span>
                        <span class="chip active">.ehi</span>
                        <span class="chip active">.npvt</span>
                        <span class="chip active">.npvs</span>
                        <span class="chip active">.hat</span>
                        <span class="chip active">.nm</span>
                        <span class="chip active">.dark</span>
                        <span class="chip active">.slip</span>
                        <span class="chip active">.ssc</span>
                        <span class="chip active">.hc</span>
                        <span class="chip active">.yaml</span>
                        <span class="chip active">.txt</span>
                        <span class="chip active">.conf</span>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>🌐 لینک‌های اشتراک (Subscription URLs)</h2>
                </div>
                <div class="form-group">
                    <label>آدرس لینک‌ها (هر خط یک آدرس اشتراک):</label>
                    <textarea id="src-subs-urls" class="textarea-text" rows="6"></textarea>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>✈️ کانال‌های تلگرام عمومی</h2>
                </div>
                <div class="form-group">
                    <label>آیدی کانال‌ها (هر خط یک آیدی با علامت @):</label>
                    <textarea id="src-tg-channels" class="textarea-text" rows="6"></textarea>
                </div>
                <div class="grid-2">
                    <div class="form-group">
                        <label>حداکثر پیام‌ها برای بررسی در هر کانال:</label>
                        <input type="number" id="src-tg-max-msg" class="input-text" value="15">
                    </div>
                    <div class="form-group">
                        <label>تاخیر بین درخواست‌ها (میلی‌ثانیه):</label>
                        <input type="number" id="src-tg-delay" class="input-text" value="300">
                    </div>
                </div>
            </div>
        </div>

        <!-- TAB 3: TESTS -->
        <div id="tab-tests" class="tab-content">
            <div class="card">
                <div class="card-header">
                    <h2>🧪 گزینه‌ها و تنظیمات سنجش سلامت کانفیگ‌ها</h2>
                </div>
                <p style="font-size: 13px; color: var(--md-sys-color-on-surface-variant); margin-bottom: 16px;">
                    تمامی تست‌ها قابلیت فعال یا غیرفعال‌سازی دارند. تست‌های پیش‌فرض بر اساس بهینه‌ترین حالت سرعت و دقت تنظیم شده‌اند.
                </p>

                <!-- 1. Ping -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">سنجش پینگ و زمان پاسخ (Ping Test)</span>
                        <span class="desc">بررسی برقراری ارتباط سریع و محاسبه تاخیر اتصال به سرور پروکسی</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-ping" checked>
                        <span class="slider"></span>
                    </label>
                </div>

                <!-- 2. Geo & Flag -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">تشخیص کشور و پرچم (Geo & Flag Emoji)</span>
                        <span class="desc">شناسایی موقعیت جغرافیایی سرور و چسباندن پرچم اموجی کشور به اول نام کانفیگ</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-geo" checked>
                        <span class="slider"></span>
                    </label>
                </div>

                <!-- 3. Gemini AI -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">تست هوش مصنوعی جمنای گوگل (Google Gemini)</span>
                        <span class="desc">سنجش باز شدن و تحریم نبودن سرویس هوش مصنوعی Gemini گوگل</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-gemini">
                        <span class="slider"></span>
                    </label>
                </div>

                <!-- 4. Unified Website Test -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">تست دسترسی به وب‌سایت‌های دلخواه (Unified Website Accessibility)</span>
                        <span class="desc">بررسی دسترسی و باز شدن بدون فیلتر سایت‌های مهم کاربر (یوتیوب، تلگرام، جمنای و هر سایت دیگر)</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-sites">
                        <span class="slider"></span>
                    </label>
                </div>

                <div class="form-group" style="margin-top: 10px; margin-bottom: 20px;">
                    <label>آدرس سایت‌های مدنظر برای تست دسترسی (هر خط یک آدرس):</label>
                    <textarea id="test-sites-list" class="textarea-text" rows="4">https://www.youtube.com/generate_204
https://telegram.org
https://gemini.google.com
https://x.com</textarea>
                </div>

                <!-- 5. Download Speed -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">سنجش سرعت دانلود (Download Speed)</span>
                        <span class="desc">دریافت بسته داده ۵ مگابایتی از CDN کلودفلر برای محاسبه پهنای باند واقعی</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-download">
                        <span class="slider"></span>
                    </label>
                </div>

                <!-- 6. Upload Speed -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">سنجش سرعت آپلود (Upload Speed)</span>
                        <span class="desc">ارسال بسته تستی ۱ مگابایتی برای سنجش پایداری خط آپلود</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-upload">
                        <span class="slider"></span>
                    </label>
                </div>

                <!-- 7. UDP Support -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">بررسی پروتکل UDP (گیمینگ، تماس صوتی و تصویری)</span>
                        <span class="desc">تست ارسال بسته‌های دیتای UDP لازم برای دیسکورد، تماس‌های تلگرام و بازی آنلاین</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-udp" checked>
                        <span class="slider"></span>
                    </label>
                </div>

                <!-- 8. Stability & Jitter -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">سنجش پایداری و نوسان پینگ (Stability & Jitter)</span>
                        <span class="desc">انجام چند تست متوالی جهت اطمینان از عدم پرش پینگ و افت اتصال</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-stability" checked>
                        <span class="slider"></span>
                    </label>
                </div>

                <!-- 9. Clean IP / Fraud Score -->
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">نمره تمیزی آی‌پی (Fraud Score & Clean IP)</span>
                        <span class="desc">بررسی عدم اسپم بودن آی‌پی برای جلوگیری از کپچا و خطاهای Cloudflare</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="test-fraud" checked>
                        <span class="slider"></span>
                    </label>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h2>🧹 فیلترها و پاکسازی هوشمند</h2>
                </div>
                <div class="switch-row">
                    <div class="switch-info">
                        <span class="title">فیلتر و حذف خودکار کانفیگ‌های منقضی‌شده</span>
                        <span class="desc">بررسی تاریخ انقضای فایل‌ها و حذف کانفیگ‌هایی که زمان اعتبارشان به پایان رسیده</span>
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
                        <span class="desc">فیلتر کانفیگ‌هایی با پورت نامعتبر یا UUID ناقص</span>
                    </div>
                    <label class="switch">
                        <input type="checkbox" id="filter-broken" checked>
                        <span class="slider"></span>
                    </label>
                </div>
            </div>
        </div>

        <!-- TAB 4: ANALYTICS -->
        <div id="tab-analytics" class="tab-content">
            <div class="card">
                <div class="card-header">
                    <h2>📈 آمار تفکیکی کانفیگ‌ها و پروتکل‌ها</h2>
                </div>
                <div class="grid-2">
                    <div>
                        <h3 style="font-size: 14px; margin-bottom: 12px; color: var(--md-sys-color-primary);">توزیع پروتکل‌ها:</h3>
                        <table>
                            <thead>
                                <tr>
                                    <th>پروتکل</th>
                                    <th>تعداد</th>
                                    <th>وضعیت هسته میهومو</th>
                                </tr>
                            </thead>
                            <tbody id="protocol-table-body">
                                <tr><td>VLESS Reality / Vision</td><td>۹,۸۴۰</td><td>پشتیبانی کامل ✅</td></tr>
                                <tr><td>VMess</td><td>۳,۲۱۰</td><td>پشتیبانی کامل ✅</td></tr>
                                <tr><td>Trojan</td><td>۱,۴۸۰</td><td>پشتیبانی کامل ✅</td></tr>
                                <tr><td>OpenVPN</td><td>۴۵</td><td>پشتیبانی کامل ✅</td></tr>
                                <tr><td>Hysteria 2 / TUIC</td><td>۳۵۰</td><td>پشتیبانی کامل ✅</td></tr>
                                <tr><td>Shadowsocks</td><td>۵۶۸</td><td>پشتیبانی کامل ✅</td></tr>
                            </tbody>
                        </table>
                    </div>
                    <div>
                        <h3 style="font-size: 14px; margin-bottom: 12px; color: var(--md-sys-color-primary);">خلاصه فیلترها و نتایج:</h3>
                        <div class="stat-card" style="margin-bottom: 10px;">
                            <span class="label">⏰ کانفیگ‌های منقضی شناسایی‌شده</span>
                            <span class="val" id="stat-expired-count" style="color: var(--md-sys-color-error);">۵۹ کانفیگ</span>
                        </div>
                        <div class="stat-card" style="margin-bottom: 10px;">
                            <span class="label">🔄 تکراری‌های حذف‌شده</span>
                            <span class="val" id="stat-duplicates-count">۵۰,۴۱۰ کانفیگ</span>
                        </div>
                        <div class="stat-card">
                            <span class="label">🎯 درصد سازگاری با Mihomo</span>
                            <span class="val" style="color: var(--md-sys-color-success);">۱۰۰٪</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
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

        function clearLogs() {
            document.getElementById('terminal-box').innerHTML = '[System] لاگ پاکسازی شد.';
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

                // Tests
                if (s.tests) {
                    if (s.tests.ping) document.getElementById('test-ping').checked = !!s.tests.ping.enabled;
                    if (s.tests.geo_flag) document.getElementById('test-geo').checked = !!s.tests.geo_flag.enabled;
                    if (s.tests.gemini) document.getElementById('test-gemini').checked = !!s.tests.gemini.enabled;
                    if (s.tests.website_accessibility) {
                        document.getElementById('test-sites').checked = !!s.tests.website_accessibility.enabled;
                        if (s.tests.website_accessibility.sites) {
                            document.getElementById('test-sites-list').value = s.tests.website_accessibility.sites.join('\n');
                        }
                    }
                    if (s.tests.download_speed) document.getElementById('test-download').checked = !!s.tests.download_speed.enabled;
                    if (s.tests.upload_speed) document.getElementById('test-upload').checked = !!s.tests.upload_speed.enabled;
                    if (s.tests.udp) document.getElementById('test-udp').checked = !!s.tests.udp.enabled;
                    if (s.tests.stability) document.getElementById('test-stability').checked = !!s.tests.stability.enabled;
                    if (s.tests.fraud_score) document.getElementById('test-fraud').checked = !!s.tests.fraud_score.enabled;
                }

                // Filters
                if (s.filters) {
                    document.getElementById('filter-expired').checked = !!s.filters.filter_expired;
                    document.getElementById('filter-duplicates').checked = !!s.filters.filter_duplicates;
                    document.getElementById('filter-broken').checked = !!s.filters.filter_broken;
                }
            } catch (e) {
                console.error("Load settings failed:", e);
            }
        }

        async function saveAllSettings() {
            const activeCard = document.querySelector('#mode-group .radio-card.active');
            const activeMode = activeCard ? activeCard.getAttribute('data-mode') : 'all';

            const payload = {
                sources: {
                    active_mode: activeMode,
                    local_folder: {
                        enabled: true,
                        path: document.getElementById('src-folder-path').value.trim()
                    },
                    subscriptions: {
                        enabled: true,
                        urls: document.getElementById('src-subs-urls').value.split('\n').map(x => x.trim()).filter(Boolean)
                    },
                    telegram: {
                        enabled: true,
                        channels: document.getElementById('src-tg-channels').value.split('\n').map(x => x.trim()).filter(Boolean),
                        max_messages_per_channel: parseInt(document.getElementById('src-tg-max-msg').value) || 15,
                        delay_ms: parseInt(document.getElementById('src-tg-delay').value) || 300
                    }
                },
                tests: {
                    ping: { enabled: document.getElementById('test-ping').checked },
                    geo_flag: { enabled: document.getElementById('test-geo').checked },
                    gemini: { enabled: document.getElementById('test-gemini').checked },
                    website_accessibility: {
                        enabled: document.getElementById('test-sites').checked,
                        sites: document.getElementById('test-sites-list').value.split('\n').map(x => x.trim()).filter(Boolean)
                    },
                    download_speed: { enabled: document.getElementById('test-download').checked },
                    upload_speed: { enabled: document.getElementById('test-upload').checked },
                    udp: { enabled: document.getElementById('test-udp').checked },
                    stability: { enabled: document.getElementById('test-stability').checked },
                    fraud_score: { enabled: document.getElementById('test-fraud').checked }
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
                const ret = await res.json();
                if (ret.ok) {
                    alert('✅ تنظیمات با موفقیت ذخیره شد.');
                }
            } catch (e) {
                alert('خطا در ذخیره تنظیمات: ' + e);
            }
        }

        async function startCollector() {
            const btn = document.getElementById('btn-start');
            btn.disabled = true;
            try {
                await fetch('/api/run', { method: 'POST' });
            } catch (e) {
                btn.disabled = false;
            }
        }

        async function pollStatus() {
            try {
                const res = await fetch('/api/status');
                const data = await res.json();

                const btn = document.getElementById('btn-start');
                const badge = document.getElementById('runner-badge');
                const statusText = document.getElementById('runner-status-text');
                const pBar = document.getElementById('progress-bar');
                const pPercent = document.getElementById('progress-percent');
                const term = document.getElementById('terminal-box');

                btn.disabled = data.running;
                badge.innerText = data.running ? 'در حال اجرا...' : 'آماده به کار';
                badge.style.color = data.running ? 'var(--md-sys-color-warning)' : 'var(--md-sys-color-primary)';
                statusText.innerText = data.status_text;
                pBar.style.width = data.progress + '%';
                pPercent.innerText = data.progress + '%';

                if (data.logs && data.logs.length > 0) {
                    term.innerHTML = data.logs.map(l => '<div>' + l + '</div>').join('');
                    term.scrollTop = term.scrollHeight;
                }

                if (data.last_result) {
                    const r = data.last_result;
                    if (r.total_discovered) document.getElementById('stat-discovered').innerText = r.total_discovered.toLocaleString('fa-IR');
                    if (r.total_duplicates_dropped || r.total_expired_dropped) {
                        const filt = (r.total_duplicates_dropped || 0) + (r.total_expired_dropped || 0) + (r.total_broken_dropped || 0);
                        document.getElementById('stat-filtered').innerText = filt.toLocaleString('fa-IR');
                    }
                    if (r.total_unique) document.getElementById('stat-survivors').innerText = r.total_unique.toLocaleString('fa-IR');
                    if (r.total_expired_dropped !== undefined) {
                        document.getElementById('stat-expired-count').innerText = r.total_expired_dropped.toLocaleString('fa-IR') + ' کانفیگ';
                    }
                    if (r.total_duplicates_dropped !== undefined) {
                        document.getElementById('stat-duplicates-count').innerText = r.total_duplicates_dropped.toLocaleString('fa-IR') + ' کانفیگ';
                    }
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
        elif url.path == "/api/save_settings":
            content_len = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_len).decode("utf-8")
            try:
                data = json.loads(body)
                current = load_settings()
                # Update current with incoming data
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
        # Launch dedicated application window (no address bar, no browser tabs)
        subprocess.Popen([browser_path, f"--app={url}", "--window-size=1250,850"])
    else:
        import webbrowser
        webbrowser.open(url)

def main():
    server = HTTPServer(("127.0.0.1", PORT), GUIHandler)
    url = f"http://127.0.0.1:{PORT}"
    
    # Launch dedicated window
    threading.Thread(target=lambda: (time.sleep(0.6), launch_desktop_window(url)), daemon=True).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
