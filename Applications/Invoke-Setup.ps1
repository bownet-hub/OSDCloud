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

    # Add other applications and install parameters
    # RingCentral
    if ($appName -like "*RingCentral*") {
        if ($invoke -eq "Install") {
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

            Install
        }
        elseif ($invoke -eq "Uninstall") {
            Write-Host "Uninstalling $appName"
            Uninstall-Advanced
        }
    }

    # WatchGuard SSL VPN
    elseif ($appName -like "*Watchguard*") {
        if ($invoke -eq "Install") {
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

                    Install
                }
            }
            else {
                Write-Host "Certificate not present"
            }
        }
        elseif ($invoke -eq "Uninstall") {
            Write-Host "Uninstalling $appName"
            $installer = "C:\Program Files (x86)\WatchGuard\WatchGuard Mobile VPN with SSL\unins000.EXE"

            $arguments = @(
                "/VERYSILENT"
                "/NORESTART"
            )
            Uninstall
        }
    }

    else {
        Write-Host "$appName is not a valid application"
    }
}

Function Install {
    # Run the Install if in Install Mode
    if ($url) {
        Write-Host "Downloading the installer to $installerPath"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile "$installerPath" -UseBasicParsing -Verbose
        if (!(Test-Path "$installerPath")) {
            Write-Host "Did not download, Exit Script"
            exit 1
        }
    }

    if ($null -ne $installer) {
        if (Test-Path "$installer") { 
            Write-Host "Starting install using $installer $arguments"
            Start-Process "$installer" -ArgumentList $arguments -Wait
            Write-Host "Software install finished"
        }
    }
    else {
        Write-Host "Installer not found"
    }

    # Remove the Installer
    if ($null -ne $installerPath) {
        if (Test-Path "$installerPath") {
            Start-Sleep -Seconds 2
            Write-Host "Delete installer"
            Remove-Item "$installerPath"
        }
    }
    Write-Host "$(Get-Date -Format $dtFormat)"
}

Function Uninstall {
    Write-Host "Uninstall using $installer $arguments"
    Write-Host "Stop any of the applications that may be running"
    Get-Process | Where-Object { $_.Company -like "*$appName*" -or $_.Path -like "*$appName*" } | Stop-Process -ErrorAction Ignore -Force
    if (!(Test-Path "$installer")) {
        Write-Host "File does not exist"
    }
    elseif (Test-Path "$installer") {
        Start-Process "$installer" -ArgumentList $arguments -Wait   
    }

    Write-Host "Uninstall complete" 
    Write-Host "$(Get-Date -Format $dtFormat)"
}

Function Uninstall-Advanced {
    Write-Host "Stop any of the applications that may be running"
    Get-Process | Where-Object { $_.Company -like "*$appName*" -or $_.Path -like "*$appName*" } | Stop-Process -ErrorAction Ignore -Force

    # Uninstall any installed applications that the administrator can remove
    foreach ($app in (Get-WmiObject -Class Win32_Product | Where-Object { $_.Vendor -like "*$appName*" })) {
        Write-Host "Attempting to uninstall $($app)"
        Try {
            $app.Uninstall() | Out-Null 
        } 
        Catch {
            Write-Host "$_"
        }
    }

    Write-Host "Remove any system uninstall keys after trying the uninstaller"
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
                        } # don't do anything if it's not an uninstall
                        elseif ($cmd -notlike "*/qn*") { 
                            Write-Host "Adding /qn flag to try and uninstall quietly"
                            $cmd = "$cmd /qn" 
                        } # don't display UI
                    }
                    if ($cmd) {
                        Write-Host "Executing $($cmd)"
                        cmd.exe /c "$($cmd)"
                        Write-Host "Done"
                    }
                }
                Catch {
                    Write-Host "$_"
                }
            }
            $list = Get-ItemProperty "$path\*" | Where-Object { $_.DisplayName -like "*$appName*" } | Select-Object -Property PSPath
            foreach ($regkey in $list) {
                Write-Host "Removing Registry Key $($regkey.PSpath)"
                Try {
                    Remove-Item $regkey.PSPath -recurse -force
                } 
                Catch {
                    Write-Host "$_"
                }
            }
        } 
        else { 
            Write-Host "Path $($path) not found" 
        }
    }
    Write-Host "Uninstall complete"
    Write-Host "$(Get-Date -Format $dtFormat)"
}
