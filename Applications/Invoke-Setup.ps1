Function Invoke-Setup {
    Param(
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Application")]
        [ValidateNotNullOrEmpty()]
        [string]$AppName,

        [Parameter(Position = 2, HelpMessage = "Install or Uninstall")]
        [ValidateSet("Install", "Uninstall")]
        [string]$Invoke = 'Install')

    $DefaultPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
    $LogPath = "$DefaultPath\$AppName.txt"

    #Start logging
    Start-Transcript -Path "$LogPath" -Append
    $dtFormat = 'dd-MMM-yyyy HH:mm:ss'
    Write-Host "$(Get-Date -Format $dtFormat)"

    #Add other applications and install parameters
    #RingCentral
    if ($AppName -like "*RingCentral*") {
        if ($Invoke -eq "Install") {
            Write-Host "Installing $AppName"

            $InstallerPath = "$DefaultPath\$AppName.msi"
            $Installer = "C:\Windows\System32\msiexec.exe"

            $url = "https://downloads.ringcentral.com/sp/RingCentralForWindows"
            Write-Host "URL to download the installer: $url"

            $Arguments = @(
                "/i"
                "$InstallerPath"
                "ALLUSERS=1"
                "/qn"
            )

            Install
        }
        elseif ($Invoke -eq "Uninstall") {
            Write-Host "Uninstalling $AppName"
            Uninstall-Advanced
        }
    }

    #WatchGuard SSL VPN
    elseif ($AppName -like "*Watchguard*") {
        if ($Invoke -eq "Install") {
            Write-Host "Installing $AppName"

            $Installer = Get-ChildItem -Path ".\" -Recurse -File -Include "*.exe"
            Write-Host "Use included installer $Installer"

            $Arguments = @(
                "/SILENT"
                "/VERYSILENT"
                "/TASKS=DESKTOPICON"
            )

            $CertFile = Get-ChildItem -Path ".\" -Recurse -File -Include "*.cer"
            if ($null -ne $CertFile) {
                if (Test-Path "$CertFile") { 
                    Write-Host "Install included certificate"
                    Import-Certificate -FilePath $CertFile -CertStoreLocation Cert:\LocalMachine\TrustedPublisher

                    Install
                }
            }
            else {
                
                Write-Host "Certificate not present"
            }
        }
        elseif ($Invoke -eq "Uninstall") {
            Write-Host "Uninstalling $AppName"
            $Installer = "C:\Program Files (x86)\WatchGuard\WatchGuard Mobile VPN with SSL\unins000.EXE"

            $Arguments = @(
                "/VERYSILENT"
                "/NORESTART"
            )
            Uninstall
        }
    }

    else {
        Write-Host "$AppName is not a valid application"
    }
}

Function Install {
    #Run the Install if in Install Mode
    if ($url) {
        Write-Host "Downloading the installer to $InstallerPath"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile "$InstallerPath" -UseBasicParsing -Verbose
        if (!(Test-Path "$InstallerPath")) {
            Write-Host "Did not download, Exit Script"
            exit 1
        }
    }

    if ($null -ne $Installer) {
        if (Test-Path "$Installer") { 
            Write-Host "Starting install using $Installer $Arguments"
            Start-Process "$Installer" -ArgumentList $Arguments -Wait
            Write-Host "Software install finished"
        }
    }
    else {
        Write-Host "Installer not found"
    }

    #Remove the Installer
    if ($null -ne $InstallerPath) {
        if (Test-Path "$InstallerPath") {
            Start-Sleep -Seconds 2
            Write-Host "Delete installer"
            Remove-Item "$InstallerPath"
        }
    }
    Write-Host "$(Get-Date -Format $dtFormat)"
}

Function Uninstall {
    Write-Host "Uninstall using $Installer $Arguments"
    Write-Host "Stop any of the applications that may be running"
    Get-Process | Where-Object { $_.Company -like "*$AppName*" -or $_.Path -like "*$AppName*" } | Stop-Process -ErrorAction Ignore -Force
    if (!(Test-Path "$Installer")) {
        Write-Host "File does not exist"
    }
    elseif (Test-Path "$Installer") {
        Start-Process "$Installer" -ArgumentList $Arguments -Wait   
    }

    Write-Host "Uninstall complete" 
    Write-Host "$(Get-Date -Format $dtFormat)"
}

Function Uninstall-Advanced {
    Write-Host "Stop any of the applications that may be running"
    Get-Process | Where-Object { $_.Company -like "*$AppName*" -or $_.Path -like "*$AppName*" } | Stop-Process -ErrorAction Ignore -Force

    #Uninstall any installed applications that the administrator can remove
    foreach ($app in (Get-WmiObject -Class Win32_Product | Where-Object { $_.Vendor -like "*$AppName*" })) {
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
            $list = Get-ItemProperty "$path\*" | Where-Object { $_.DisplayName -like "*$AppName*" } | Select-Object -Property PSPath, UninstallString
            foreach ($regkey in $list) {
                Write-Host "Examining Registry Key $($regkey.PSpath)"
                Try {
                    $cmd = $regkey.UninstallString
                    if ($cmd -like "msiexec.exe*") {
                        Write-Host "Uninstall string is using msiexec.exe"
                        if ($cmd -notlike "*/X*") { 
                            Write-Host "No /X flag - this isn't for uninstalling"
                            $cmd = "" 
                        } #don't do anything if it's not an uninstall
                        elseif ($cmd -notlike "*/qn*") { 
                            Write-Host "Adding /qn flag to try and uninstall quietly"
                            $cmd = "$cmd /qn" 
                        } #don't display UI
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
            $list = Get-ItemProperty "$path\*" | Where-Object { $_.DisplayName -like "*$AppName*" } | Select-Object -Property PSPath
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
