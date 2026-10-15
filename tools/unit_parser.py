#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Freedom Config Collector v2 - Smart Unit & Number Parser
Parses Persian/Arabic and English digits and normalizes time units:
(milliseconds, seconds, minutes, hours)
"""

import re

PERSIAN_TO_ENGLISH_DIGITS = {
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9'
}

def normalize_digits(text: str) -> str:
    """Converts Persian and Arabic digits to standard English ASCII digits."""
    if text is None:
        return ""
    text = str(text).strip()
    for fa_digit, en_digit in PERSIAN_TO_ENGLISH_DIGITS.items():
        text = text.replace(fa_digit, en_digit)
    return text

def parse_number(val, default=0.0) -> float:
    """Safely extracts a float/int from mixed Persian/English input."""
    clean = normalize_digits(str(val))
    match = re.search(r"[-+]?\d*\.?\d+", clean)
    if match:
        try:
            return float(match.group(0))
        except ValueError:
            pass
    return float(default)

def parse_duration_seconds(val, unit="s") -> float:
    """
    Normalizes (number, unit) into seconds (float).
    Supports units:
      - 'ms', 'میلی‌ثانیه', 'میلی ثانیه'
      - 's', 'sec', 'ثانیه'
      - 'm', 'min', 'دقیقه'
      - 'h', 'hour', 'ساعت'
    """
    raw_str = normalize_digits(str(val)).lower()
    
    # Auto-detect unit if embedded in string
    detected_unit = str(unit).lower().strip()
    if "میلی" in raw_str or "ms" in raw_str:
        detected_unit = "ms"
    elif "دقیقه" in raw_str or "min" in raw_str:
        detected_unit = "min"
    elif "ساعت" in raw_str or "hour" in raw_str or "h" in raw_str:
        detected_unit = "h"
    elif "ثانیه" in raw_str or "sec" in raw_str or "s" in raw_str:
        detected_unit = "s"

    num = parse_number(raw_str, default=0.0)

    if detected_unit in ["ms", "میلی‌ثانیه", "میلی ثانیه"]:
        return num / 1000.0
    elif detected_unit in ["min", "m", "دقیقه"]:
        return num * 60.0
    elif detected_unit in ["h", "hour", "ساعت"]:
        return num * 3600.0
    else: # default seconds
        return num

def parse_duration_ms(val, unit="ms") -> float:
    """Converts input duration to milliseconds."""
    sec = parse_duration_seconds(val, unit=unit if unit != "ms" else "s")
    # If unit was ms:
    u = str(unit).lower().strip()
    if u in ["ms", "میلی‌ثانیه", "میلی ثانیه"]:
        return parse_number(val)
    return sec * 1000.0

def format_duration_fa(seconds: float) -> str:
    """Formats seconds into human-readable Persian string."""
    s = float(seconds)
    if s < 1.0:
        return f"{int(s * 1000)} میلی‌ثانیه"
    elif s < 60:
        return f"{s:.1f} ثانیه" if s % 1 != 0 else f"{int(s)} ثانیه"
    elif s < 3600:
        m = s / 60.0
        return f"{m:.1f} دقیقه" if m % 1 != 0 else f"{int(m)} دقیقه"
    else:
        h = s / 3600.0
        return f"{h:.1f} ساعت" if h % 1 != 0 else f"{int(h)} ساعت"
