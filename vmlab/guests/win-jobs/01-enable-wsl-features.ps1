# TIMEOUT=180
# Enable the two optional features WSL2 needs, then reboot. This job restarts
# the machine itself, which kills the agent process mid-flight before it can
# upload job.out the normal way (windows-agent.ps1's own upload happens
# *after* this script returns, which never happens across a restart) -- so
# this script uploads its own log first and only then reboots. The next job
# (02-post-reboot-check.ps1) is what actually confirms the agent survived.
$log = 'C:\vmlab\job01.log'
Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue

dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart *>> $log
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart *>> $log
'restarting now' | Add-Content -LiteralPath $log

try {
    Invoke-WebRequest -UseBasicParsing -Uri 'http://10.0.2.2:8000/job.out' -Method Put -InFile $log -ErrorAction Stop | Out-Null
} catch {
    try { (New-Object System.Net.WebClient).UploadFile('http://10.0.2.2:8000/job.out', 'PUT', $log) | Out-Null } catch {}
}

Start-Sleep -Seconds 2
Restart-Computer -Force
