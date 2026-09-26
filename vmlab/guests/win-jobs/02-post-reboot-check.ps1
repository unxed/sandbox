# TIMEOUT=300
# Confirms both things job 01 needed: the two optional features actually
# took effect, and the agent (Startup-folder launch, via AutoLogon) survived
# the reboot on its own -- this job's mere response proves the second part.
dism.exe /online /get-features /format:table 2>$null | Select-String -Pattern 'Linux|VirtualMachinePlatform'
Write-Output '---'
Write-Output ('hostname: ' + $env:COMPUTERNAME)
Write-Output ('uptime since: ' + (Get-CimInstance Win32_OperatingSystem).LastBootUpTime)
Write-Output 'post-reboot agent: ok'
