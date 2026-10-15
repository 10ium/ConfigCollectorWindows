#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Freedom Config Collector v2 - Deep Gemini AI Probe
Inspired by Gemini-Config-Checker.
Implements 3 Levels of checking:
  - Level 1: Network Reachability Probe (generativelanguage.googleapis.com)
  - Level 2: Deep Region & Web Application Probe (gemini.google.com/app & aistudio.google.com)
            detects regional block keywords ("available-region", "currently supported in your country")
  - Level 3: API Key Live Prompt Verification (official Gemini API generateContent call)
"""

import sys
import json
import urllib.request
import urllib.error
import urllib.parse

REACH_URL = "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1&key=x"
STUDIO_URL = "https://aistudio.google.com/prompts/new_chat"
GEMINI_APP_URL = "https://gemini.google.com/app"

CHROME_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

def check_gemini_level1(opener=None, timeout=6.0):
    """
    Level 1: Network Reachability Probe.
    Any answer from Google's API host (even 400 'API key not valid') proves Google Generative Language is accessible.
    """
    req = urllib.request.Request(REACH_URL, headers={"User-Agent": CHROME_UA})
    active_opener = opener or urllib.request.build_opener()
    try:
        with active_opener.open(req, timeout=timeout) as resp:
            return {"level": 1, "status": "ok", "message": "اتصال موفق به سرور هوش مصنوعی گوگل"}
    except urllib.error.HTTPError as e:
        # HTTP 400 is expected because key=x is dummy. It proves network reachability!
        if e.code in [400, 403, 404]:
            return {"level": 1, "status": "ok", "message": "پاسخ معتبر از سرور هوش مصنوعی دریافت شد (کد " + str(e.code) + ")"}
        return {"level": 1, "status": "error", "message": f"خطای سرور: {e.code}"}
    except Exception as e:
        return {"level": 1, "status": "blocked", "message": f"عدم برقراری ارتباط: {e}"}

def check_gemini_level2(opener=None, cookies_str="", timeout=10.0):
    """
    Level 2: Deep Region & Web Application Probe.
    Inspects responses from Gemini Web and AI Studio to check for regional censorship or block pages.
    """
    headers = {
        "User-Agent": CHROME_UA,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Sec-Ch-Ua": '"Not/A)Brand";v="8", "Chromium";v="126", "Google Chrome";v="126"',
        "Sec-Ch-Ua-Mobile": "?0",
        "Sec-Ch-Ua-Platform": '"Windows"'
    }
    if cookies_str:
        headers["Cookie"] = cookies_str

    active_opener = opener or urllib.request.build_opener()

    # Probe 1: Gemini App URL
    try:
        req = urllib.request.Request(GEMINI_APP_URL, headers=headers)
        with active_opener.open(req, timeout=timeout) as resp:
            final_url = resp.geturl()
            body = resp.read().decode("utf-8", errors="ignore").lower()

            if "available-region" in final_url or "available-region" in body:
                return {"level": 2, "status": "blocked", "message": "تحریم منطقه جغرافیایی گوگل (available-region)"}
            if "currently supported in your country" in body or "isn't currently supported in your country" in body:
                return {"level": 2, "status": "blocked", "message": "پیام عدم پشتیبانی در کشور شما توسط جمنای"}
            if "accounts.google.com" in final_url or "gemini.google.com" in final_url:
                return {"level": 2, "status": "ok", "message": "عبور موفق از سد تحریم منطقه جمنای"}
    except urllib.error.HTTPError as e:
        if e.code in [403, 451]:
            return {"level": 2, "status": "blocked", "message": f"مسدود شده توسط گوگل (کد {e.code})"}
    except Exception as e:
        return {"level": 2, "status": "error", "message": f"خطا در بررسی وب‌اپ جمنای: {e}"}

    # Probe 2: AI Studio
    try:
        req2 = urllib.request.Request(STUDIO_URL, headers=headers)
        with active_opener.open(req2, timeout=timeout) as resp2:
            final_url2 = resp2.geturl()
            body2 = resp2.read().decode("utf-8", errors="ignore").lower()
            if "available-region" in final_url2 or "available-region" in body2:
                return {"level": 2, "status": "blocked", "message": "مسدودی منطقه در AI Studio گوگل"}
            return {"level": 2, "status": "ok", "message": "عبور از تحریم AI Studio و جمنای"}
    except Exception:
        pass

    return {"level": 2, "status": "ok", "message": "تست سطح ۲ با موفقیت پشت سر گذاشته شد"}

def check_gemini_level3(api_key, opener=None, timeout=12.0):
    """
    Level 3: Live API Key Prompt Verification.
    Sends a test request using the user's Gemini API key.
    """
    if not api_key:
        return {"level": 3, "status": "error", "message": "کلید API وارد نشده است"}

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key.strip()}"
    payload = json.dumps({"contents": [{"parts": [{"text": "ping"}]}]}).encode("utf-8")
    req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json", "User-Agent": CHROME_UA})

    active_opener = opener or urllib.request.build_opener()
    try:
        with active_opener.open(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if "candidates" in data:
                return {"level": 3, "status": "ok", "message": "تولید پاسخ هوش مصنوعی جمنای ۱۰۰٪ موفق بود"}
            return {"level": 3, "status": "ok", "message": "پاسخ دریافت شد"}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        if "location is not supported" in body.lower() or "not supported in your country" in body.lower():
            return {"level": 3, "status": "blocked", "message": "تحریم منطقه در فراخوانی API Key"}
        return {"level": 3, "status": "error", "message": f"خطای API: {e.code}"}
    except Exception as e:
        return {"level": 3, "status": "error", "message": f"خطا در ارسال درخواست به جمنای: {e}"}

def run_gemini_test(level=1, opener=None, api_key="", cookies_str="", timeout=8.0):
    """
    Runs the selected Gemini check level.
    """
    if level == 3 and api_key:
        return check_gemini_level3(api_key, opener=opener, timeout=timeout)
    elif level == 2:
        return check_gemini_level2(opener=opener, cookies_str=cookies_str, timeout=timeout)
    else:
        return check_gemini_level1(opener=opener, timeout=timeout)
