#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Freedom Config Collector v2 - Mihomo Core & CPU Architecture Manager
Handles CPU feature detection (Modern AVX2 vs Legacy Compatible),
local version querying, remote GitHub release tracking, and automated 1-click updates.
"""

import os
import sys
import re
import json
import gzip
import zipfile
import shutil
import urllib.request
import urllib.parse
import subprocess
import platform

if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN_DIR = os.path.join(BASE_DIR, "bin")
CORE_PATH = os.path.join(BIN_DIR, "mihomo.exe")
GITHUB_API_LATEST = "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
GITHUB_API_ALPHA = "https://api.github.com/repos/MetaCubeX/mihomo/releases/tags/Prerelease-Alpha"

def detect_cpu_architecture() -> str:
    """
    Intelligently detects whether the CPU is modern (supports AVX2) or legacy.
    Returns: 'windows-amd64' or 'windows-amd64-compatible'
    """
    if platform.machine().lower() not in ["amd64", "x86_64"]:
        return "windows-arm64" if "arm" in platform.machine().lower() else "windows-amd64-compatible"

    # Query CPU Name in Windows
    cpu_name = ""
    try:
        import winreg
        key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"HARDWARE\DESCRIPTION\System\CentralProcessor\0")
        cpu_name, _ = winreg.QueryValueEx(key, "ProcessorNameString")
        winreg.CloseKey(key)
    except Exception:
        cpu_name = platform.processor()

    cpu_upper = str(cpu_name).upper()

    # Legacy or Low-power CPUs without AVX2
    legacy_indicators = [
        "CELERON", "PENTIUM", "CORE(TM)2", "ATOM", "ATHLON", "PHENOM",
        "I3-2", "I5-2", "I7-2",  # Sandy Bridge (Gen 2 - No AVX2)
        "I3-3", "I5-3", "I7-3",  # Ivy Bridge (Gen 3 - No AVX2)
        "I3-4000", "I3-4005", "I3-4010", "I3-4025", "I3-4030", # Some early 4th gen i3 mobile lack AVX2
    ]
    for leg in legacy_indicators:
        if leg in cpu_upper:
            return "windows-amd64-compatible"

    # Modern CPUs with guaranteed AVX2:
    # Intel Core 4th Gen Haswell (4xxx) through 14th Gen / Core Ultra
    # AMD Ryzen / Zen series
    modern_indicators = [
        "RYZEN", "THREADRIPPER", "EPYC", "CORE(TM) ULTRA",
        "I3-", "I5-", "I7-", "I9-", "XEON E5-26", "XEON PLATINUM", "XEON GOLD"
    ]
    for mod in modern_indicators:
        if mod in cpu_upper:
            return "windows-amd64"

    # Safe fallback for unknown/older DDR3 machines
    return "windows-amd64-compatible"

def get_local_core_info():
    """Returns local Mihomo executable details and version string."""
    if not os.path.exists(CORE_PATH):
        return {
            "installed": False,
            "version": None,
            "path": CORE_PATH,
            "message_fa": "هسته میهومو هنوز دانلود نشده است."
        }
    
    try:
        proc = subprocess.run(
            [CORE_PATH, "-v"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="ignore",
            timeout=4
        )
        out = (proc.stdout or proc.stderr or "").strip()
        ver_match = re.search(r"v\d+\.\d+\.\d+[^\s]*", out, re.IGNORECASE)
        ver_str = ver_match.group(0) if ver_match else out.split("\n")[0]
        return {
            "installed": True,
            "version": ver_str,
            "path": CORE_PATH,
            "raw_output": out,
            "message_fa": f"نسخه فعلی: {ver_str}"
        }
    except Exception as e:
        return {
            "installed": True,
            "version": "ناشناخته",
            "path": CORE_PATH,
            "message_fa": f"خطا در اجرای هسته: {e}"
        }

def get_remote_release_info(channel="stable", proxy_dict=None):
    """
    Queries GitHub API for latest release info of MetaCubeX/mihomo.
    proxy_dict example: {'http': 'http://127.0.0.1:7890', 'https': 'http://127.0.0.1:7890'}
    """
    url = GITHUB_API_LATEST if channel == "stable" else GITHUB_API_ALPHA
    headers = {
        "User-Agent": "Freedom-Config-Collector/2.0 (Windows NT)",
        "Accept": "application/vnd.github.v3+json"
    }
    
    try:
        handlers = []
        if proxy_dict:
            handlers.append(urllib.request.ProxyHandler(proxy_dict))
        opener = urllib.request.build_opener(*handlers)
        req = urllib.request.Request(url, headers=headers)
        
        with opener.open(req, timeout=12) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            tag = data.get("tag_name", "")
            assets = []
            for a in data.get("assets", []):
                name = a.get("name", "")
                if "windows" in name.lower() and (name.endswith(".zip") or name.endswith(".gz")):
                    assets.append({
                        "name": name,
                        "size": a.get("size", 0),
                        "download_url": a.get("browser_download_url")
                    })
            return {
                "ok": True,
                "tag": tag,
                "channel": channel,
                "published_at": data.get("published_at"),
                "assets": assets
            }
    except Exception as e:
        return {
            "ok": False,
            "error": str(e),
            "message_fa": f"خطا در ارتباط با گیت‌هاب: {e}"
        }

def download_and_install_core(arch_pref="auto", channel="stable", proxy_dict=None, progress_cb=None):
    """
    Downloads, extracts, and places the official Mihomo core into bin/mihomo.exe.
    arch_pref: 'auto', 'windows-amd64', 'windows-amd64-compatible'
    """
    os.makedirs(BIN_DIR, exist_ok=True)
    
    # 1. Determine target architecture
    if arch_pref == "auto":
        target_arch = detect_cpu_architecture()
    elif arch_pref in ["amd64", "windows-amd64"]:
        target_arch = "windows-amd64"
    else:
        target_arch = "windows-amd64-compatible"

    if progress_cb:
        progress_cb(10, f"معماری پردازنده شناسایی شد: {target_arch}. در حال بررسی آخرین نسخه گیت‌هاب...")

    # 2. Query GitHub Releases
    rel_info = get_remote_release_info(channel=channel, proxy_dict=proxy_dict)
    if not rel_info.get("ok"):
        return {"ok": False, "error": rel_info.get("message_fa", "عدم برقراری ارتباط با مخزن گیت‌هاب")}

    assets = rel_info.get("assets", [])
    matched_asset = None

    # Find the exact matching asset
    # e.g., mihomo-windows-amd64-compatible-v1.19.1.zip
    for a in assets:
        name_lower = a["name"].lower()
        if target_arch in name_lower:
            matched_asset = a
            break

    # Fallback to windows-amd64 if compatible wasn't found or vice versa
    if not matched_asset:
        for a in assets:
            if "windows" in a["name"].lower() and "amd64" in a["name"].lower():
                matched_asset = a
                break

    if not matched_asset:
        return {"ok": False, "error": f"فایل متناسب با معماری {target_arch} در این نسخه یافت نشد."}

    download_url = matched_asset["download_url"]
    file_name = matched_asset["name"]
    temp_archive = os.path.join(BIN_DIR, file_name)

    if progress_cb:
        progress_cb(30, f"در حال دانلود فایل {file_name} ({matched_asset['size'] // (1024*1024)} MB)...")

    # 3. Download Archive
    try:
        handlers = []
        if proxy_dict:
            handlers.append(urllib.request.ProxyHandler(proxy_dict))
        opener = urllib.request.build_opener(*handlers)
        req = urllib.request.Request(download_url, headers={"User-Agent": "Freedom-Config-Collector"})

        with opener.open(req, timeout=30) as resp, open(temp_archive, "wb") as out_f:
            total_size = int(resp.headers.get("Content-Length", matched_asset.get("size", 1)))
            downloaded = 0
            chunk_size = 64 * 1024
            while True:
                chunk = resp.read(chunk_size)
                if not chunk:
                    break
                out_f.write(chunk)
                downloaded += len(chunk)
                if progress_cb and total_size > 0:
                    pct = 30 + int((downloaded / total_size) * 50)
                    progress_cb(pct, f"دانلود هسته: {downloaded // 1024} KB از {total_size // 1024} KB")

    except Exception as e:
        if os.path.exists(temp_archive):
            try: os.remove(temp_archive)
            except Exception: pass
        return {"ok": False, "error": f"خطا در دانلود هسته: {e}"}

    if progress_cb:
        progress_cb(85, "دانلود تکمیل شد. در حال استخراج و نصب هسته...")

    # 4. Extract Archive (.zip or .gz)
    temp_exe = os.path.join(BIN_DIR, "temp_mihomo.exe")
    try:
        if file_name.endswith(".zip"):
            with zipfile.ZipFile(temp_archive, "r") as z:
                for member in z.namelist():
                    if member.lower().endswith(".exe"):
                        with z.open(member) as zf, open(temp_exe, "wb") as ef:
                            shutil.copyfileobj(zf, ef)
                        break
        elif file_name.endswith(".gz"):
            with gzip.open(temp_archive, "rb") as gz, open(temp_exe, "wb") as ef:
                shutil.copyfileobj(gz, ef)

        if not os.path.exists(temp_exe):
            return {"ok": False, "error": "فایل اجرایی داخل بسته فشرده یافت نشد."}

        # Backup old core if exists
        if os.path.exists(CORE_PATH):
            backup_path = os.path.join(BIN_DIR, "mihomo_old.bak")
            try:
                if os.path.exists(backup_path):
                    os.remove(backup_path)
                shutil.move(CORE_PATH, backup_path)
            except Exception:
                pass

        shutil.move(temp_exe, CORE_PATH)

        # Cleanup archive
        if os.path.exists(temp_archive):
            try: os.remove(temp_archive)
            except Exception: pass

    except Exception as e:
        return {"ok": False, "error": f"خطا در استخراج فایل: {e}"}

    # 5. Verify installed core
    info = get_local_core_info()
    if progress_cb:
        progress_cb(100, f"هسته میهومو با موفقیت نصب شد ({info.get('version', '')}).")

    return {
        "ok": True,
        "version": info.get("version"),
        "arch": target_arch,
        "message_fa": f"هسته میهومو با موفقیت نصب گردید ({info.get('version')})"
    }

if __name__ == "__main__":
    print("Detected CPU Architecture:", detect_cpu_architecture())
    print("Local core info:", get_local_core_info())
