# TIMEOUT=3000
# First job ever sent to the guest agent: the unattended install finished,
# Administrator auto-logged on, FirstLogonCommands ran bootstrap.ps1, and the
# agent is polling -- this is the actual "installed Windows is usable"
# checkpoint. TIMEOUT is generous (50 min) because it covers the *entire*
# unattended install (partition/copy/expand/specialize/reboot/oobe), not just
# this one command.
Write-Output ('hostname: ' + $env:COMPUTERNAME)
Write-Output ('date    : ' + (Get-Date))
Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture | Format-List
Write-Output 'agent alive: ok'
