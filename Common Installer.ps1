# PowerShell script with progress bar for system setup, application checks, and Windows Update install/reboot
# Now gives user a choice between MariaDB and XAMPP

$apps = @(
    @{ Name = "Google Chrome"; WingetId = "Google.Chrome"; CheckName = "chrome.exe"; Manual = $false },
    @{ Name = "HeidiSQL"; WingetId = "HeidiSQL.HeidiSQL"; CheckName = "heidisql.exe"; Manual = $false },
    @{ Name = "Visual Studio Code"; WingetId = "Microsoft.VisualStudioCode"; CheckName = "Code.exe"; Manual = $false }
)

# Prompt user for MariaDB or XAMPP
Write-Host "Choose which database software to install:"
Write-Host "1. MariaDB"
Write-Host "2. XAMPP"
do {
    $dbChoice = Read-Host "Enter 1 for MariaDB or 2 for XAMPP"
} while ($dbChoice -notin @("1", "2"))

if ($dbChoice -eq "1") {
    $apps += @{ Name = "MariaDB"; WingetId = "MariaDB.MariaDB"; CheckName = "mysqld.exe"; Manual = $false }
    $dbName = "MariaDB"
} else {
    $apps += @{ Name = "XAMPP"; WingetId = "ApacheFriends.Xampp"; CheckName = "xampp-control.exe"; Manual = $false }
    $dbName = "XAMPP"
}

$steps = @(
    "Checking for Windows updates (scan only)...",
    "Installing Winget...",
    "Checking and installing/updating applications...",
    "Installing Windows updates...",
    "Rebooting system..."
)

$totalSteps = $steps.Count
$stepIndex = 0

function Show-Progress {
    param([string]$Activity)
    $percent = [int](($stepIndex / $totalSteps) * 100)
    Write-Progress -Activity "System Setup Progress" -Status $Activity -PercentComplete $percent
}

function Is-App-Installed {
    param([string]$exeName)
    $found = $false
    $paths = @(
        "$env:ProgramFiles",
        "$env:ProgramFiles (x86)",
        "$env:LOCALAPPDATA",
        "$env:APPDATA"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $result = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue -Filter $exeName | Select-Object -First 1
            if ($result) { return $true }
        }
    }
    return $false
}

function Install-Chrome-Direct {
    # Download and install Chrome directly from Google if Winget fails
    Write-Host "Attempting direct download and install of Google Chrome..."
    $chromeUrl = "https://dl.google.com/chrome/install/latest/chrome_installer.exe"
    $chromeInstaller = "$env:TEMP\chrome_installer.exe"
    try {
        Invoke-WebRequest -Uri $chromeUrl -OutFile $chromeInstaller -UseBasicParsing
        Start-Process -FilePath $chromeInstaller -ArgumentList "/silent /install" -Wait
        Remove-Item $chromeInstaller -Force
        Write-Host "Google Chrome installed via direct download."
    } catch {
        Write-Host "Direct download and install of Google Chrome failed: $_"
    }
}

function Update-Or-Install-App {
    param($app)
    $wingetId = $app.WingetId
    $name = $app.Name
    $exeName = $app.CheckName
    $manual = $app.Manual

    $installed = Is-App-Installed $exeName

    if ($installed) {
        Write-Host "`n$name is already installed. Checking for updates..."
        $updateResult = winget upgrade --id $wingetId -e --accept-source-agreements --accept-package-agreements 2>&1
        if ($updateResult -match "No applicable update found") {
            Write-Host "$name is up to date."
        } elseif ($updateResult -match "Installer hash does not match") {
            if ($name -eq "Google Chrome") {
                Write-Host "WARNING: Installer hash did not match for $name. Attempting direct install/update."
                Install-Chrome-Direct
            } else {
                Write-Host "WARNING: Installer hash did not match for $name. Skipping update."
            }
        } elseif ($updateResult -match "Could not find") {
            Write-Host "WARNING: $name could not be found in Winget sources."
        } else {
            Write-Host "$name updated (if applicable)."
        }
    } else {
        Write-Host "`n$name is not installed. Attempting to install..."
        $installResult = winget install --id $wingetId -e --accept-source-agreements --accept-package-agreements 2>&1
        if ($installResult -match "Installer hash does not match") {
            if ($name -eq "Google Chrome") {
                Write-Host "WARNING: Installer hash did not match for $name. Attempting direct install."
                Install-Chrome-Direct
            } else {
                Write-Host "WARNING: Installer hash did not match for $name. Skipping install."
            }
        } elseif ($installResult -match "Could not find") {
            Write-Host "WARNING: $name could not be found in Winget sources."
        } else {
            Write-Host "$name installation attempted. Please verify installation."
        }
    }
}

# Step 1: Check for Windows updates (scan only)
$stepIndex++
Show-Progress -Activity $steps[$stepIndex - 1]
Write-Host "`nScanning for Windows updates (this may take a while)..."
try {
    $updates = Get-WindowsUpdate -MicrosoftUpdate -IgnoreUserInput -AcceptAll -WhatIf -ErrorAction Stop
} catch {
    # If PSWindowsUpdate module is not installed, try to install it
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -AllowClobber
        Import-Module PSWindowsUpdate
        $updates = Get-WindowsUpdate -MicrosoftUpdate -IgnoreUserInput -AcceptAll -WhatIf
    }
}
Write-Host "Windows update scan complete. Updates found (not installed):"
if ($updates) {
    $updates | Format-Table -Property Title, KB, Size -AutoSize
} else {
    Write-Host "No updates found or unable to retrieve update list."
}

# Step 2: Install Winget
$stepIndex++
Show-Progress -Activity $steps[$stepIndex - 1]
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "`nWinget not found. Attempting to install App Installer (Winget)..."
    $wingetApp = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller"
    if (-not $wingetApp) {
        Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "$env:TEMP\AppInstaller.msixbundle"
        Add-AppxPackage -Path "$env:TEMP\AppInstaller.msixbundle"
        Remove-Item "$env:TEMP\AppInstaller.msixbundle"
    }
    Start-Sleep -Seconds 5
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "Winget installation failed. Please install manually and re-run this script."
        exit 1
    }
} else {
    Write-Host "Winget is already installed."
}

# Step 3: Check and install/update applications
$stepIndex++
Show-Progress -Activity $steps[$stepIndex - 1]
foreach ($app in $apps) {
    Update-Or-Install-App $app
}

# Step 4: Install Windows updates
$stepIndex++
Show-Progress -Activity $steps[$stepIndex - 1]
Write-Host "`nInstalling all available Windows updates. This may take a while..."
try {
    # Ensure PSWindowsUpdate is available
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -AllowClobber
    }
    Import-Module PSWindowsUpdate
    # Download and install all available updates, auto-accept EULAs
    Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -AutoReboot
} catch {
    Write-Host "Failed to install Windows updates: $_"
    Write-Host "You may need to run this script as Administrator."
}

# Step 5: Reboot system (if not already rebooted by Windows Update)
$stepIndex++
Show-Progress -Activity $steps[$stepIndex - 1]
Write-Host "`nRebooting system in 10 seconds. Press Ctrl+C to cancel."
Start-Sleep -Seconds 10
Restart-Computer -Force

# Final progress
$stepIndex = $totalSteps
Show-Progress -Activity "All steps completed!"
Write-Progress -Activity "System Setup Progress" -Completed

Write-Host "`nAll steps completed. Please review any warnings above."






