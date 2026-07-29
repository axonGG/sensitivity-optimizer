<#
.SYNOPSIS
    Installs, updates, and launches the application via GitHub Releases.
.DESCRIPTION
    This script queries the GitHub Releases API to find the latest version,
    downloads the executable if an update is needed (or if not installed),
    updates the local version tracking, and launches the application.
.NOTES
    This script is designed to be run directly via:
    irm https://raw.githubusercontent.com/<OWNER>/<REPOSITORY>/main/install.ps1 | iex
#>

# ==============================================================================
# Configuration
# ==============================================================================
$Owner = "axonGG"                                  # GitHub Username or Organization
$Repository = "sensitivity-optimizer"              # GitHub Repository Name
$ApplicationName = "Sensitivity Optimiser"         # Local folder name
$ExeName = "SensitivityOptimiser.exe"              # Executable filename

# ==============================================================================
# Environment Setup
# ==============================================================================
$ErrorActionPreference = 'Stop'

# Ensure TLS 1.2 is used for older PowerShell versions when calling GitHub API
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$LocalAppData = [Environment]::GetFolderPath('LocalApplicationData')
$InstallDir = Join-Path $LocalAppData $ApplicationName
$LogFile = Join-Path $InstallDir "install.log"
$VersionFile = Join-Path $InstallDir "version.txt"
$ExePath = Join-Path $InstallDir $ExeName

# ==============================================================================
# Functions
# ==============================================================================

function Write-Log {
    param (
        [string]$Message,
        [switch]$ToConsole,
        [string]$ForegroundColor = "White"
    )
    
    if ($ToConsole) {
        Write-Host $Message -ForegroundColor $ForegroundColor
    }

    if (Test-Path $InstallDir) {
        Add-Content -Path $LogFile -Value $Message -ErrorAction SilentlyContinue
    }
}

function Ensure-InstallationDirectory {
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir | Out-Null
    }
}

function Test-Internet {
    try {
        $request = [System.Net.WebRequest]::Create("https://github.com")
        $request.Timeout = 3000
        $response = $request.GetResponse()
        $response.Close()
        return $true
    } catch {
        return $false
    }
}

function Get-InstalledVersion {
    if (Test-Path $VersionFile) {
        return (Get-Content $VersionFile).Trim()
    }
    return $null
}

function Get-LatestRelease {
    $ApiUrl = "https://api.github.com/repos/$Owner/$Repository/releases/latest"
    try {
        $Response = Invoke-RestMethod -Uri $ApiUrl -Method Get -ErrorAction Stop
        return $Response
    } catch {
        Write-Log "Error: Failed to query GitHub API. Rate limiting or connectivity issue.`n$_" -ToConsole -ForegroundColor Red
        return $null
    }
}

function Download-Release {
    param (
        [Parameter(Mandatory=$true)]
        $Release
    )
    
    $Asset = $Release.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1
    if (-not $Asset) {
        Write-Log "Error: No executable asset found in release $($Release.tag_name)." -ToConsole -ForegroundColor Red
        return $false
    }

    $DownloadUrl = $Asset.browser_download_url
    if ($DownloadUrl -notmatch "^https://github\.com/") {
        Write-Log "Error: Invalid download URL. Security block - must originate from GitHub.`nURL: $DownloadUrl" -ToConsole -ForegroundColor Red
        return $false
    }

    $TempPath = Join-Path ([System.IO.Path]::GetTempPath()) ($ExeName + ".tmp")

    Write-Log "Downloading update..." -ToConsole -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempPath -ErrorAction Stop
        
        # Security & Integrity: Verify download is not empty
        if ((Get-Item $TempPath).length -eq 0) {
            throw "Downloaded file is empty or corrupted."
        }

        # Replace existing exe
        if (Test-Path $ExePath) {
            # Attempt to close running application gracefully
            $ProcessName = $ExeName -replace "\.exe$"
            $Process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            if ($Process) {
                Write-Log "Stopping running application..." -ToConsole -ForegroundColor Yellow
                Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
            Remove-Item $ExePath -Force -ErrorAction SilentlyContinue
        }
        
        Move-Item -Path $TempPath -Destination $ExePath -Force -ErrorAction Stop
        
        # Save version
        Set-Content -Path $VersionFile -Value $Release.tag_name -Force
        
        return $true
    } catch {
        Write-Log "Error during download/installation:`n$_" -ToConsole -ForegroundColor Red
        if (Test-Path $TempPath) { Remove-Item $TempPath -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

function Launch-Application {
    if (Test-Path $ExePath) {
        Write-Log "Launching..." -ToConsole -ForegroundColor Green
        try {
            Start-Process -FilePath $ExePath -ErrorAction Stop
            Write-Log "Launch:`nSUCCESS`n"
        } catch {
            Write-Log "Error: Failed to launch application:`n$_" -ToConsole -ForegroundColor Red
        }
    } else {
        Write-Log "Error: Executable not found at $ExePath" -ToConsole -ForegroundColor Red
    }
}

# ==============================================================================
# Main Logic
# ==============================================================================

function Main {
    Ensure-InstallationDirectory

    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    Write-Log "`n$Timestamp`n"

    Write-Log "Checking installation..." -ToConsole -ForegroundColor Cyan
    Write-Log "Checking for updates..." -ToConsole -ForegroundColor Cyan
    
    $InstalledVersion = Get-InstalledVersion
    if ($InstalledVersion) {
        Write-Log "Installed Version:`n$InstalledVersion`n"
    } else {
        Write-Log "Installed Version:`nNone`n"
    }

    if (-not (Test-Internet)) {
        if ($InstalledVersion) {
            Write-Log "No internet connection. Launching currently installed version." -ToConsole -ForegroundColor Yellow
            Launch-Application
        } else {
            Write-Log "Error: No internet connection. Cannot install application." -ToConsole -ForegroundColor Red
        }
        return
    }

    $LatestRelease = Get-LatestRelease
    if (-not $LatestRelease) {
        if ($InstalledVersion) {
            Write-Log "Could not verify updates. Launching currently installed version." -ToConsole -ForegroundColor Yellow
            Launch-Application
        }
        return
    }

    $LatestVersion = $LatestRelease.tag_name
    Write-Log "Latest Version:`n$LatestVersion`n"

    if ($InstalledVersion -eq $LatestVersion) {
        Write-Log "Already running latest version." -ToConsole -ForegroundColor Green
        Launch-Application
    } else {
        if ($InstalledVersion) {
            Write-Log "Latest version:`n$LatestVersion`n`nInstalled version:`n$InstalledVersion`n" -ToConsole
        }
        
        $UpdateSuccess = Download-Release -Release $LatestRelease
        if ($UpdateSuccess) {
            Write-Log "Installing..." -ToConsole -ForegroundColor Cyan
            Write-Log "Update:`nSUCCESS`n"
            Launch-Application
        } else {
            Write-Log "Update:`nFAILED`n"
            if ($InstalledVersion) {
                Write-Log "Falling back to previously installed version..." -ToConsole -ForegroundColor Yellow
                Launch-Application
            }
        }
    }
}

# Execute Main Function
try {
    Main
} catch {
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    $ErrorMessage = "[$Timestamp] FATAL ERROR: $_"
    Write-Host $ErrorMessage -ForegroundColor Red
    if (Test-Path $InstallDir) {
        Add-Content -Path $LogFile -Value "`n$ErrorMessage`n" -ErrorAction SilentlyContinue
    }
}
