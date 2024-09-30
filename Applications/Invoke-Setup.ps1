Function Invoke-Setup
{
Param(
[Parameter(Mandatory=$true,Position=1,HelpMessage="Application")]
[ValidateNotNullOrEmpty()]
[string]$AppName,

[Parameter(Position=2,HelpMessage="Install or Uninstall")]
[ValidateSet("Install", "Uninstall")]
[string]$Invoke = 'Install')

$DefaultPath = "C:\ProgramData\Intune"
$LogPath = "$DefaultPath\$AppName.txt"

#Start logging
Start-Transcript -Path "$LogPath" -Append
$dtFormat = 'dd-MMM-yyyy HH:mm:ss'
Write-Host "$(Get-Date -Format $dtFormat)"

Write-Host "Defining variables for $AppName"

#Add other applications and install parameters
#RingCentral
If ($AppName -eq "RingCentral") {
    If ($Invoke -eq "Install") {
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
    
    Elseif ($Invoke -eq "Uninstall") {
        Write-Host "Uninstalling $AppName"
        Uninstall-Advanced
    }
}

#WatchGuard SSL VPN
Elseif ($AppName -eq "Watchguard") {
    If ($Invoke -eq "Install") {
        Write-Host "Installing $AppName"

        $Installer = ".\WG-MVPN-SSL.exe"
        Write-Host "Use included installer $Installer"

        $Arguments = @(
        "/SILENT"
       "/VERYSILENT"
        )

        $CertFile = ".\OpenVPN.cer"
        If (!(Test-Path "$CertFile")) { 
            Write-Host "Certificate not present"
        } else {
        Write-Host "Install included certificate"
        Import-Certificate -FilePath $CertFile -CertStoreLocation Cert:\LocalMachine\TrustedPublisher

        Install
        }
    }
    
    Elseif ($Invoke -eq "Uninstall") {
        Write-Host "Uninstalling $AppName"
        $Installer = "C:\Program Files (x86)\WatchGuard\WatchGuard Mobile VPN with SSL\unins000.EXE"

        $Arguments = @(
        "/VERYSILENT"
        "/NORESTART"
        )
        Uninstall
    }
}

Else {
    Write-Host "$AppName is not a valid application"
}
}

Function Install
{
#Run the Install if in Install Mode
If ($url) {
    Write-Host "Downloading the installer to $InstallerPath"
    Invoke-WebRequest -Uri $url -OutFile "$InstallerPath" -UseBasicParsing -Verbose
    If (!(Test-Path "$InstallerPath")) {
        Write-Host "Did not download, Exit Script"
        exit
    }
}

If (!(Test-Path "$Installer")) { 
    Write-Host "Installer not present"
} else {
    Write-Host "Starting install using $Installer $Arguments"
    Start-Process "$Installer" -ArgumentList $Arguments -Wait
    Write-Host "Software install finished" 
}

#Remove the Installer

If ($null -ne $InstallerPath -and ($null -ne $InstallerPath)) {
    If (Test-Path "$InstallerPath") {
        Start-Sleep -Seconds 2
        Write-Host "Delete installer"
        Remove-Item "$InstallerPath"
    }
}
Write-Host "$(Get-Date -Format $dtFormat)"
}

Function Uninstall
{
Write-Host "Uninstall using $Installer $Arguments"
If (!(Test-Path "$Installer")) {
    Write-Host "File does not exist"
} elseif (Test-Path "$Installer") {
    Start-Process "$Installer" -ArgumentList $Arguments -Wait   
}

Write-Host "Software uninstall finished" 

Write-Host "$(Get-Date -Format $dtFormat)"
}

Function Uninstall-Advanced
{
Write-Host "Stop any of the applications that may be running"
Get-Process | Where-Object {$_.Company -like "*$AppName*" -or $_.Path -like "*$AppName*"} | Stop-Process -ErrorAction Ignore -Force

#Uninstall any installed applications that the administrator can remove
Foreach ($app in (Get-WmiObject -Class Win32_Product | Where-Object{$_.Vendor -like "*$AppName*"})) {
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
Foreach($path in $paths) {
    If (Test-Path($path)) {
        $list = Get-ItemProperty "$path\*" | Where-Object {$_.DisplayName -like "*$AppName*"} | Select-Object -Property PSPath, UninstallString
        Foreach($regkey in $list) {
            Write-Host "Examining Registry Key $($regkey.PSpath)"
            Try {
                $cmd = $regkey.UninstallString
                If ($cmd -like "msiexec.exe*") {
                    Write-Host "Uninstall string is using msiexec.exe"
                    If ($cmd -notlike "*/X*") { 
                        Write-Host "No /X flag - this isn't for uninstalling"
                        $cmd = "" 
                    } #don't do anything if it's not an uninstall
                    Elseif ($cmd -notlike "*/qn*") { 
                        Write-Host "Adding /qn flag to try and uninstall quietly"
                        $cmd = "$cmd /qn" 
                    } #don't display UI
                }
                If ($cmd) {
                    Write-Host "Executing $($cmd)"
                    cmd.exe /c "$($cmd)"
                    Write-Host "Done"
                }
            }
            Catch {
                Write-Host "$_"
            }
        }
        $list = Get-ItemProperty "$path\*" | Where-Object {$_.DisplayName -like "*$AppName*"} | Select-Object -Property PSPath
        Foreach($regkey in $list) {
            Write-Host "Removing Registry Key $($regkey.PSpath)"
            Try {
                Remove-Item $regkey.PSPath -recurse -force
            } 
            Catch {
                Write-Host "$_"
            }
        }
    } 
    Else { 
    Write-Host "Path $($path) not found" 
    }
}
Write-Host "Uninstall complete"
Write-Host "$(Get-Date -Format $dtFormat)"
}
