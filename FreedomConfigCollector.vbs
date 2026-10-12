' Freedom Config Collector v2 - Silent Desktop Launcher
' Launches the Material 3 Windows Application Window without displaying any CMD console

Set WshShell = CreateObject("WScript.Shell")
strPath = WshShell.CurrentDirectory

' Run pythonw silently (window style 0 = hidden)
WshShell.Run "pythonw.exe """ & strPath & "\app_gui.py""", 0, False
