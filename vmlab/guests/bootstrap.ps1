# vmlab Windows guest: run once by autounattend.xml's FirstLogonCommands
# (A:\bootstrap.ps1, from the floppy also holding autounattend.xml itself).
# Installs the polling agent (vmlab/guests/windows-agent.ps1, also shipped on
# the same floppy as A:\windows-agent.ps1) so it starts on every future boot
# via the All-Users Startup folder -- AutoLogon (see autounattend.xml) means
# every reboot reaches an interactive Administrator session automatically,
# so a Startup-folder script is enough, no scheduled task/SYSTEM juggling
# needed. Deliberately does everything from the floppy (no network needed
# yet) so this step can't be blocked by DHCP/e1000 not being up yet.
$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force -Path C:\vmlab | Out-Null
Copy-Item -LiteralPath A:\windows-agent.ps1 -Destination C:\vmlab\windows-agent.ps1 -Force

$startupDir = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp'
New-Item -ItemType Directory -Force -Path $startupDir | Out-Null
Copy-Item -LiteralPath A:\vmlab-agent.cmd -Destination (Join-Path $startupDir 'vmlab-agent.cmd') -Force

Start-Process -FilePath powershell.exe -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
    '-File', 'C:\vmlab\windows-agent.ps1'
)
