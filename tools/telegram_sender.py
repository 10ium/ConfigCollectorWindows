#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Freedom Config Collector v2 - Telegram Bot Auto-Sender
Automatically posts collected healthy configs, subscriptions, or output files
to the user's private or public Telegram channel via Bot API.
"""

import os
import sys
import json
import urllib.request
import urllib.parse
import mimetypes

def send_telegram_message(bot_token, chat_id, text, opener=None, parse_mode="HTML"):
    """Sends a text message to Telegram channel/chat."""
    if not bot_token or not chat_id or not text:
        return {"ok": False, "error": "Missing bot token, chat ID, or text"}

    url = f"https://api.telegram.org/bot{bot_token.strip()}/sendMessage"
    payload = json.dumps({
        "chat_id": chat_id.strip(),
        "text": text,
        "parse_mode": parse_mode,
        "disable_web_page_preview": True
    }).encode("utf-8")

    headers = {"Content-Type": "application/json"}
    req = urllib.request.Request(url, data=payload, headers=headers)
    active_opener = opener or urllib.request.build_opener()

    try:
        with active_opener.open(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return {"ok": True, "result": data}
    except Exception as e:
        return {"ok": False, "error": str(e)}

def send_telegram_document(bot_token, chat_id, file_path, caption="", opener=None):
    """Sends a file document to Telegram channel/chat via multipart/form-data."""
    if not bot_token or not chat_id or not os.path.exists(file_path):
        return {"ok": False, "error": "Missing bot token, chat ID, or file"}

    filename = os.path.basename(file_path)
    url = f"https://api.telegram.org/bot{bot_token.strip()}/sendDocument"

    boundary = "----FreedomCollectorBoundary" + str(int(os.path.getmtime(file_path)))
    body_parts = []

    # chat_id field
    body_parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n{chat_id.strip()}\r\n")

    # caption field
    if caption:
        body_parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\n{caption}\r\n")

    # file field
    mime_type = mimetypes.guess_type(file_path)[0] or "application/octet-stream"
    body_parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"document\"; filename=\"{filename}\"\r\nContent-Type: {mime_type}\r\n\r\n")

    with open(file_path, "rb") as f:
        file_bytes = f.read()

    body = b"".join([part.encode("utf-8") for part in body_parts]) + file_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")

    headers = {
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "Content-Length": str(len(body))
    }

    req = urllib.request.Request(url, data=body, headers=headers)
    active_opener = opener or urllib.request.build_opener()

    try:
        with active_opener.open(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return {"ok": True, "result": data}
    except Exception as e:
        return {"ok": False, "error": str(e)}

def test_bot_token(bot_token, opener=None):
    """Validates bot token via getMe API."""
    if not bot_token:
        return {"ok": False, "message": "توکن ربات وارد نشده است"}
    url = f"https://api.telegram.org/bot{bot_token.strip()}/getMe"
    req = urllib.request.Request(url, headers={"User-Agent": "FreedomCollector"})
    active_opener = opener or urllib.request.build_opener()
    try:
        with active_opener.open(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data.get("ok"):
                username = data.get("result", {}).get("username", "")
                return {"ok": True, "message": f"اتصال ربات تایید شد: @{username}"}
    except Exception as e:
        return {"ok": False, "message": f"خطا در اتصال به تلگرام: {e}"}
    return {"ok": False, "message": "توکن ربات نامعتبر است"}
