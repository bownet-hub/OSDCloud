# Include RDP file downloaded from RDWeb, and optional icon file
# If icon is not included, system icon will be used
# Files need to be in root of IntuneWin
# If RDPName parameter is not specified, "RemoteApp" will be used
# Ability to install or uninstall with Invoke parameter

Function Invoke-RDP {
    Param(
        [Parameter(Position = 1, HelpMessage = "RemoteApp Name")]
        [string]$RDPName = 'RemoteApp',

        [Parameter(Position = 2, HelpMessage = "Install or Uninstall")]
        [ValidateSet("Install", "Uninstall")]
        [string]$Invoke = 'Install')

    $TargetDir = "C:\Program Files (x86)\RemoteApp"
    $ShortcutPath = "C:\Users\Public\Desktop\$RDPName.lnk"
    $TargetPath = "$TargetDir\$RDPName.rdp"

    Start-Transcript -Path "C:\ProgramData\Intune\$RDPName.txt" -Append
    $dtFormat = 'dd-MMM-yyyy HH:mm:ss'
    Write-Host "$(Get-Date -Format $dtFormat)"

    If ($Invoke -eq "Install") {
        Install-RDP
    }
    Elseif ($Invoke -eq "Uninstall") {
        Write-Host "Uninstalling $RDPName"
        Uninstall-RDP
    }

    Write-Host "$(Get-Date -Format $dtFormat)"
    Stop-Transcript
}


Function Install-RDP {
    If (!(Test-Path "$TargetDir")) {
        Write-Host "Create directory if it doesn't exist $TargetDir"
        New-Item -ItemType Directory -Path $TargetDir -Force
    }

    If (!(Test-Path ".\*.rdp")) {
        Write-Host "No RDP file present. Exiting"
        Exit
    }
    Else {
        Write-Host "Create RemoteApp from included RDP file $TargetDir\$RDPName.rdp"
        $RDPFile = Get-Content ".\*.rdp" -Raw | Out-File "$TargetDir\$RDPName.rdp"
    }

    If (!(Test-Path ".\*.ico")) {
        Write-Host "No icon file present. Using system default"
        $IconFile = "%systemroot%\system32\mstscax.dll, 0"
    }
    Else {
        $IconFile = "$TargetDir\$RDPName.ico"
        Write-Host "Copy icon $RDPName.ico to $IconFile"
        Copy-Item ".\*.ico" "$IconFile"
    }

    Write-Host "Create Desktop shortcut" 
    $Shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.IconLocation = $IconFile
    $Shortcut.Save()
}


Function Uninstall-RDP {
    Write-Host "Removing $ShortcutPath and $TargetDir"
    Remove-Item "$ShortcutPath"
    Remove-Item "$TargetDir" -Recurse -Force
}
