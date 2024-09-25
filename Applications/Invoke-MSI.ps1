
Function Invoke-MSI
{
Param(
[Parameter(Mandatory=$true,Position=1,HelpMessage="Application")]
[ValidateNotNullOrEmpty()]
[string]$AppName,

[Parameter(Mandatory=$true,Position=2,HelpMessage="Install or Uninstall")]
[ValidateNotNullOrEmpty()]
[ValidateSet("Install", "Uninstall")]
[string]$Invoke)

$DefaultPath = "C:\ProgramData\Intune"
$installerPath = "$($DefaultPath)\$($AppName)"

#Start logging
Start-Transcript -Path "$($installerPath).txt" -Append
$dtFormat = 'dd-MMM-yyyy HH:mm:ss'
Write-Host "$(Get-Date -Format $dtFormat)"

Write-Host "Defining variables for $AppName"

#Add other applications and install parameters
If ($AppName = "RingCentral") {
    If ($Invoke -eq "Install") {
        Write-Host "Installing $AppName"
        $url = "https://downloads.ringcentral.com/sp/RingCentralForWindows"
        Write-Host "URL to download the installer: $url"
        $MSIArguments = @(
        "/i"
        "$($installerPath).msi"
        "ALLUSERS=1"
        "/qn"
        )
        Install-MSI
        }
    
    Elseif ($Invoke -eq "Uninstall") {
        Write-Host "Uninstalling $AppName"
        Uninstall-MSI
        }
    }
}


Function Install-MSI
{
#Run the Install if in Install Mode
Write-Host "Downloading the installer to $installerPath.msi"
Invoke-WebRequest -Uri $url -OutFile "$($installerPath).msi" -UseBasicParsing -Verbose

If (!(test-path "$($installerPath).msi")) {
    Write-Host "Did not download, Exit Script"
    exit
    }

Write-Host "Starting Install with Arguments:$MSIArguments"
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait
Write-Host "Software Install Finished" 

#Remove the Installer
If (test-path "$($installerPath).msi") {
    Start-Sleep -Seconds 2
    Write-Host "Delete Installer"
    Remove-Item "$($installerPath).msi"
    }
Write-Host "$(Get-Date -Format $dtFormat)"
}


Function Uninstall-MSI
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
