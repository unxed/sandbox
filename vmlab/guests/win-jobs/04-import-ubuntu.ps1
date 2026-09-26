# TIMEOUT=900
# No Microsoft Store on Windows Server, so `wsl --install -d Ubuntu` (which
# needs it) is out; `wsl --import` from Ubuntu's own published WSL rootfs
# tarball (https://cloud-images.ubuntu.com/wsl/, documented at
# https://documentation.ubuntu.com/wsl/) sidesteps the Store *and* the
# interactive first-run UNIX-username/password prompt `wsl --install` would
# otherwise need (the imported distro logs in as root by default) -- exactly
# what an unattended pipeline needs.
New-Item -ItemType Directory -Force -Path C:\wsl\Ubuntu | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri 'https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-wsl.rootfs.tar.gz' -OutFile C:\vmlab\ubuntu.rootfs.tar.gz
Write-Output ('rootfs size: ' + (Get-Item C:\vmlab\ubuntu.rootfs.tar.gz).Length)

wsl --import Ubuntu C:\wsl\Ubuntu C:\vmlab\ubuntu.rootfs.tar.gz --version 2
Write-Output '---'
wsl -l -v
Write-Output '---'
wsl -d Ubuntu -- sh -c "echo ok; uname -a"
