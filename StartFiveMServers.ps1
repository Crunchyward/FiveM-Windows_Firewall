# Start FiveM Servers (Dynamic Version)
# Created by Crunchyward and King Issei
# Ask user how many servers to run
$serverCount = Read-Host "How many FiveM servers do you want to run?"

# Validate input
if (-not ($serverCount -as [int]) -or [int]$serverCount -lt 1) {
    Write-Host "Please enter a valid number greater than 0." -ForegroundColor Red
    exit
}

$serverCount = [int]$serverCount
$servers = @()

# Gather all server information
for ($i = 1; $i -le $serverCount; $i++) {
    $fxServerPath = Read-Host "Enter the full path to FXServer.exe for Server $i (e.g. C:\FXServer$i\FXServer.exe):"
    $workingDir   = Read-Host "Enter the working directory for Server $i (e.g. C:\FXServer$i or your fivem folder):"
    $cfgPath      = Read-Host "Enter the full path to server.cfg for Server $i (e.g. C:\FXServer$i\server.cfg):"

    $defaultPort  = 30120 + $i - 1 # Server port starts at 30120
    $defaultTxAdminPort = 40120 + $i - 1 # txAdmin port starts at 40120

    $txAdminPort  = Read-Host "Enter the txAdmin port for Server $i (default suggestion: $defaultTxAdminPort):"
    if (-not ($txAdminPort -as [int])) {
        Write-Host ("Invalid port, using default: {0}" -f $defaultTxAdminPort)
        $txAdminPort = $defaultTxAdminPort
    }

    $extraArgs = Read-Host "Enter any extra arguments for Server $i (or leave blank, default: +set onesync on):"
    if ([string]::IsNullOrWhiteSpace($extraArgs)) {
        $extraArgs = "+set onesync on"
    } else {
        $extraArgs = "$extraArgs +set onesync on"
    }

    $servers += [PSCustomObject]@{
        FXServerPath = $fxServerPath
        WorkingDir   = $workingDir
        CfgPath      = $cfgPath
        TxAdminPort  = $txAdminPort
        ExtraArgs    = $extraArgs
        DefaultPort  = $defaultPort
    }
}

# Start all servers as per provided input
for ($i = 0; $i -lt $servers.Count; $i++) {
    $server = $servers[$i]
    $index = $i + 1
    Write-Host "Starting FiveM Server $index..." -ForegroundColor Green
    Start-Process `
        -FilePath $server.FXServerPath `
        -WorkingDirectory $server.WorkingDir `
        -ArgumentList "+exec `"$($server.CfgPath)`" +set txAdminPort $($server.TxAdminPort) $($server.ExtraArgs)" `
        -WindowStyle Normal

    if ($index -lt $servers.Count) {
        Start-Sleep -Seconds 3 # Brief pause between servers
    }
}

Write-Host "$serverCount FiveM server(s) (and their txAdmin panels) have been started." -ForegroundColor Cyan

# Show txAdmin panel links
for ($i = 0; $i -lt $servers.Count; $i++) {
    $panelNum = $i + 1
    Write-Host ("txAdmin {0}: http://YOUR-IP:{1}/" -f $panelNum, $servers[$i].TxAdminPort) -ForegroundColor Yellow
}
Pause
