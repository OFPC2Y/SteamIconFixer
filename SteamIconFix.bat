@echo off
chcp 65001 >nul

powershell.exe ^
-ExecutionPolicy Bypass ^
-NoExit ^
-File "%~dp0SteamIconFix.ps1"