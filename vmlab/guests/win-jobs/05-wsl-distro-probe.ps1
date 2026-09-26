# TIMEOUT=900
# Verbatim from unxed/f4#1494 (sogonov), reproduced exactly as given in the
# ticket/task -- this file's only job is to be run unmodified by the agent.
# (The generator that turns this into a guest job prepends its own one-line
# nonce comment ahead of everything below, per vmlab's job-bus convention,
# and strips the "# TIMEOUT=" line above; nothing below this point is
# changed.)

# Probe and benchmark for unxed/f4#1494 - is a locally spawned wsl.exe a better
# route to a WSL distribution's filesystem than \\wsl.localhost\ ?
#
# Run on Windows, in PowerShell. Touches nothing outside a temp directory it
# creates inside the distribution and removes it at the end. Nothing here needs
# f4: it measures the premise, not the implementation.
#
# Usage:  .\wsl-distro-probe.ps1 [-Distro <name>] [-SizeMB 256] [-Reps 3]

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param(
    [string]$Distro = '',
    [int]$SizeMB = 256,
    [int]$Reps = 3
)

$ErrorActionPreference = 'Stop'

function Rule([string]$t) { Write-Host ('---- ' + $t) }
function Say([string]$t)  { Write-Host $t }

function Measure-Elapsed([scriptblock]$Action) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $Action | Out-Null
    $sw.Stop()
    return [int]$sw.ElapsedMilliseconds
}

Rule 'wsl'

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) { Say 'wsl.exe not found - nothing to measure here'; exit 1 }
Say ('wsl.exe: ' + $wsl.Source)

$distros = (& wsl.exe -l -q) -replace "`0", '' | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
if (-not $distros) { Say 'no distributions installed'; exit 1 }
Say ('distributions: ' + ($distros -join ', '))

if (-not $Distro) { $Distro = $distros[0] }
Say ('using: ' + $Distro)

$probe = (& wsl.exe -d $Distro -- sh -c 'echo ok') -replace "`0", ''
if ($probe -notmatch 'ok') { Say 'could not run sh inside the distribution'; exit 1 }
Say 'sh inside the distribution: ok'

$multi = ("printf 'a\n'; printf 'b\n'" | & wsl.exe -d $Distro -- sh) -replace "`0", ''
if (($multi -join '') -match 'ab') { Say 'script over stdin: ok' } else { Say ('script over stdin: UNEXPECTED (' + ($multi -join '') + ')') }

$startup = [int]((1..$Reps | ForEach-Object { Measure-Elapsed { & wsl.exe -d $Distro -- true } } | Measure-Object -Average).Average)
Say ('wsl.exe startup: ' + $startup + ' ms (subtract from the wsl timings below)')

Rule 'workspace'

$dir = '/tmp/f4-probe-' + $PID
& wsl.exe -d $Distro -- mkdir -p $dir | Out-Null
$unc = '\\wsl.localhost\' + $Distro + ($dir -replace '/', '\')

if (-not (Test-Path -LiteralPath $unc)) {
    Say ('cannot see ' + $unc + ' - is this WSL2? on WSL1 the UNC path does not exist')
    & wsl.exe -d $Distro -- rm -rf $dir | Out-Null
    exit 1
}
Say ('linux: ' + $dir)
Say ('unc  : ' + $unc)

try {
    Rule ('create ' + $SizeMB + 'MB inside the distribution')
    $ms = Measure-Elapsed { & wsl.exe -d $Distro -- dd if=/dev/zero of="$dir/src.bin" bs=1M count=$SizeMB status=none }
    Say ('  ' + $ms + ' ms')

    Rule ('copy ' + $SizeMB + 'MB within the distribution - THE measurement')
    Say '  every byte crosses the boundary twice through the UNC path, and not at all through wsl.exe'
    for ($i = 1; $i -le $Reps; $i++) {
        Remove-Item -LiteralPath ($unc + '\dst-unc.bin') -Force -ErrorAction SilentlyContinue
        $ms = Measure-Elapsed { Copy-Item -LiteralPath ($unc + '\src.bin') -Destination ($unc + '\dst-unc.bin') }
        Say ('  run ' + $i + '  Copy-Item over UNC : ' + $ms + ' ms')

        & wsl.exe -d $Distro -- rm -f "$dir/dst-wsl.bin" | Out-Null
        $ms = Measure-Elapsed { & wsl.exe -d $Distro -- cp "$dir/src.bin" "$dir/dst-wsl.bin" }
        Say ('  run ' + $i + '  cp inside distro   : ' + $ms + ' ms (incl. ~' + $startup + ' ms startup)')
    }

    Rule 'list a large directory'
    $big = '/usr/bin'
    $bigUnc = '\\wsl.localhost\' + $Distro + '\usr\bin'
    if (Test-Path -LiteralPath $bigUnc) {
        for ($i = 1; $i -le $Reps; $i++) {
            $ms = Measure-Elapsed { Get-ChildItem -LiteralPath $bigUnc -Force }
            Say ('  run ' + $i + '  Get-ChildItem UNC  : ' + $ms + ' ms')
            $ms = Measure-Elapsed { & wsl.exe -d $Distro -- ls -la $big }
            Say ('  run ' + $i + '  ls inside distro   : ' + $ms + ' ms (incl. ~' + $startup + ' ms startup)')
        }
    } else {
        Say ('  skipped: ' + $bigUnc + ' not visible')
    }
}
finally {
    & wsl.exe -d $Distro -- rm -rf $dir | Out-Null
}

Rule 'done'
Say 'What matters: if the UNC copy is far slower than cp inside the distro minus startup,'
Say 'a helper inside the distribution is worth building. If they are close, it is not.'
