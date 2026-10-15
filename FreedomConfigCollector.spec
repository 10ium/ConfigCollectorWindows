# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['G:/Ai project/10ium/Freedom Config Collector/app_gui.py'],
    pathex=['G:/Ai project/10ium/Freedom Config Collector', 'G:/Ai project/10ium/Freedom Config Collector/tools'],
    binaries=[],
    datas=[
        ('G:/Ai project/10ium/Freedom Config Collector/app_icon.ico', '.'),
        ('G:/Ai project/10ium/Freedom Config Collector/app_icon.png', '.'),
        ('G:/Ai project/10ium/Freedom Config Collector/tools/tray_helper.ps1', 'tools')
    ],
    hiddenimports=[
        'yaml',
        'core_manager',
        'unit_parser',
        'gemini_tester',
        'telegram_sender',
        'exporter'
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='FreedomConfigCollector',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['G:/Ai project/10ium/Freedom Config Collector/app_icon.ico'],
)
