Function Invoke-Setup {
    Param(
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Application")]
        [ValidateNotNullOrEmpty()]
        [string]$appName,

        [Parameter(Position = 2, HelpMessage = "Install or Uninstall")]
        [ValidateSet("Install", "Uninstall")]
        [string]$invoke = 'Install'
    )

    $defaultPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
    $logPath = "$defaultPath\$appName.txt"

    # Start logging
    Start-Transcript -Path "$logPath" -Append
    $dtFormat = 'dd-MMM-yyyy HH:mm:ss'
    Write-Host "$(Get-Date -Format $dtFormat)"

    # Determine the application and action to perform
    switch -Wildcard ($appName) {
        "*RingCentral*" {
            if ($invoke -eq "Install") {
                Install-RingCentral
            } elseif ($invoke -eq "Uninstall") {
                Uninstall-Advanced
            }
        }
        "*Watchguard*" {
            if ($invoke -eq "Install") {
                Install-WatchGuard
            } elseif ($invoke -eq "Uninstall") {
                Uninstall-WatchGuard
            }
        }
        default {
            Write-Host "$appName is not a valid application"
        }
    }
}

# Function to install RingCentral application
Function Install-RingCentral {
    Write-Host "Installing $appName"
    $installerPath = "$defaultPath\$appName.msi"
    $installer = "C:\Windows\System32\msiexec.exe"
    $url = "https://downloads.ringcentral.com/sp/RingCentralForWindows"
    Write-Host "URL to download the installer: $url"

    $arguments = @(
        "/i"
        "$installerPath"
        "ALLUSERS=1"
        "/qn"
    )

    Install-Application -url $url -installerPath $installerPath -installer $installer -arguments $arguments
}

# Function to install WatchGuard SSL VPN application
Function Install-WatchGuard {
    Write-Host "Installing $appName"
    $installer = Get-ChildItem -Path ".\" -Recurse -File -Include "*.exe"
    Write-Host "Use included installer $installer"

    $arguments = @(
        "/SILENT"
        "/VERYSILENT"
        "/TASKS=desktopicon"
    )

    $certFile = Get-ChildItem -Path ".\" -Recurse -File -Include "*.cer"
    if ($null -ne $certFile) {
        if (Test-Path "$certFile") {
            Write-Host "Install included certificate"
            Import-Certificate -FilePath $certFile -CertStoreLocation Cert:\LocalMachine\TrustedPublisher
            Install-Application -installer $installer -arguments $arguments
        }
    } else {
        Write-Host "Certificate not present"
    }
}

# Function to handle the installation process
Function Install-Application {
    Param(
        [string]$url,
        [string]$installerPath,
        [string]$installer,
        [array]$arguments
    )

    try {
        if ($url) {
            Write-Host "Downloading the installer to $installerPath"
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $url -OutFile "$installerPath" -UseBasicParsing -Verbose
            if (!(Test-Path "$installerPath")) {
                throw "Download failed, exiting script"
            }
        }

        if ($null -ne $installer) {
            if (Test-Path "$installer") {
                Write-Host "Starting install using $installer $arguments"
                Start-Process "$installer" -ArgumentList $arguments -Wait
                Write-Host "Software install finished"
            } else {
                throw "Installer not found"
            }
        }

        if ($null -ne $installerPath) {
            if (Test-Path "$installerPath") {
                Start-Sleep -Seconds 2
                Write-Host "Deleting installer"
                Remove-Item "$installerPath"
            }
        }
    } catch {
        Write-Host "Error: $_"
    } finally {
        Write-Host "$(Get-Date -Format $dtFormat)"
    }
}

# Function to uninstall WatchGuard SSL VPN application
Function Uninstall-WatchGuard {
    Write-Host "Uninstalling $appName"
    $installer = "C:\Program Files (x86)\WatchGuard\WatchGuard Mobile VPN with SSL\unins000.EXE"
    $arguments = @(
        "/VERYSILENT"
        "/NORESTART"
    )
    Uninstall-Application -installer $installer -arguments $arguments
}

# Function to handle the uninstallation process
Function Uninstall-Application {
    Param(
        [string]$installer,
        [array]$arguments
    )

    try {
        Write-Host "Uninstall using $installer $arguments"
        Write-Host "Stopping any running applications"
        Get-Process | Where-Object { $_.Company -like "*$appName*" -or $_.Path -like "*$appName*" } | Stop-Process -ErrorAction Ignore -Force
        if (!(Test-Path "$installer")) {
            throw "Installer file does not exist"
        } elseif (Test-Path "$installer") {
            Start-Process "$installer" -ArgumentList $arguments -Wait
        }
        Write-Host "Uninstall complete"
    } catch {
        Write-Host "Error: $_"
    } finally {
        Write-Host "$(Get-Date -Format $dtFormat)"
    }
}

# Function to handle advanced uninstallation process
Function Uninstall-Advanced {
    try {
        Write-Host "Stopping any running applications"
        Get-Process | Where-Object { $_.Company -like "*$appName*" -or $_.Path -like "*$appName*" } | Stop-Process -ErrorAction Ignore -Force

        foreach ($app in (Get-WmiObject -Class Win32_Product | Where-Object { $_.Vendor -like "*$appName*" })) {
            Write-Host "Attempting to uninstall $($app)"
            Try {
                $app.Uninstall() | Out-Null
            } Catch {
                Write-Host "Error: $_"
            }
        }

        $paths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
        foreach ($path in $paths) {
            if (Test-Path($path)) {
                $list = Get-ItemProperty "$path\*" | Where-Object { $_.DisplayName -like "*$appName*" } | Select-Object -Property PSPath, UninstallString
                foreach ($regkey in $list) {
                    Write-Host "Examining Registry Key $($regkey.PSpath)"
                    Try {
                        $cmd = $regkey.UninstallString
                        if ($cmd -like "msiexec.exe*") {
                            Write-Host "Uninstall string is using msiexec.exe"
                            if ($cmd -notlike "*/X*") {
                                Write-Host "No /X flag - this isn't for uninstalling"
                                $cmd = ""
                            } elseif ($cmd -notlike "*/qn*") {
                                Write-Host "Adding /qn flag to try and uninstall quietly"
                                $cmd = "$cmd /qn"
                            }
                        }
                        if ($cmd) {
                            Write-Host "Executing $($cmd)"
                            cmd.exe /c "$($cmd)"
                            Write-Host "Done"
                        }
                    } Catch {
                        Write-Host "Error: $_"
                    }
                }
                $list = Get-ItemProperty "$path\*" | Where-Object { $_.DisplayName -like "*$appName*" } | Select-Object -Property PSPath
                foreach ($regkey in $list) {
                    Write-Host "Removing Registry Key $($regkey.PSpath)"
                    Try {
                        Remove-Item $regkey.PSPath -recurse -force
                    } Catch {
                        Write-Host "Error: $_"
                    }
                }
            } else {
                Write-Host "Path $($path) not found"
            }
        }
        Write-Host "Uninstall complete"
    } catch {
        Write-Host "Error: $_"
    } finally {
        Write-Host "$(Get-Date -Format $dtFormat)"
    }
}
