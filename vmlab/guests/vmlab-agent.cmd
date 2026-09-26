@echo off
rem vmlab Windows guest: All-Users Startup launcher for windows-agent.ps1
rem (dropped there by bootstrap.ps1). Runs on every interactive logon;
rem AutoLogon in autounattend.xml means that includes every reboot.
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\vmlab\windows-agent.ps1
