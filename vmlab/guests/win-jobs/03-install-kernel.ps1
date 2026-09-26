# TIMEOUT=600
# This ISO's build (20348.169, Oct 2021 RTM) predates wsl.exe's in-box/Store
# managed kernel; the classic standalone kernel MSI (still Microsoft's own
# current documented manual-install path for Server/older builds without the
# Store, https://learn.microsoft.com/windows/wsl/install-manual) is what
# makes `wsl.exe` itself functional at all.
Invoke-WebRequest -UseBasicParsing -Uri 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi' -OutFile C:\vmlab\wsl_update_x64.msi
$p = Start-Process msiexec.exe -ArgumentList '/i', 'C:\vmlab\wsl_update_x64.msi', '/quiet', '/norestart' -Wait -PassThru
Write-Output ('msiexec exit: ' + $p.ExitCode)

wsl --set-default-version 2
Write-Output '---'
wsl --status
Write-Output '---'
wsl --version
