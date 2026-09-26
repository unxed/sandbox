# Guest-side agent for Windows (PowerShell). Polls the host for job.ps1, runs
# it, uploads job.out. Same convention as the Haiku/Redox agents
# (vmlab/guests/haiku-agent.sh, redox-agent.ion): job.ps1's first line is a
# unique nonce comment, only a *new* job is executed. The host serves
# /tmp/vmlab/payload at http://10.0.2.2:8000/ and accepts PUT uploads there.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

function Send-Result([string]$path) {
    $uri = 'http://10.0.2.2:8000/job.out'
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $uri -Method Put -InFile $path -ErrorAction Stop | Out-Null
        return
    } catch {}
    try {
        (New-Object System.Net.WebClient).UploadFile($uri, 'PUT', $path) | Out-Null
    } catch {}
}

$last = ''
while ($true) {
    try {
        Invoke-WebRequest -UseBasicParsing -Uri 'http://10.0.2.2:8000/job.ps1' -OutFile C:\vmlab\job.ps1 -ErrorAction Stop
        $cur = Get-Content -LiteralPath C:\vmlab\job.ps1 -TotalCount 1 -ErrorAction SilentlyContinue
        if ($cur -ne $last) {
            $last = $cur
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\vmlab\job.ps1 *> C:\vmlab\job.out
            Add-Content -LiteralPath C:\vmlab\job.out -Value ('exit=' + $LASTEXITCODE)
            Send-Result C:\vmlab\job.out
        }
    } catch {
    }
    Start-Sleep -Seconds 1
}
