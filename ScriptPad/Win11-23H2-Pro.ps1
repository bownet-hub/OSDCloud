#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$OSName = 'Windows 11 23H2 x64'
$OSEdition = 'Pro'
$OSActivation = 'Retail'
$OSLanguage = 'en-us'

#Set OSDCloud Vars
$Global:MyOSDCloud = [ordered]@{
    #Restart = [bool]$False
    RecoveryPartition = [bool]$true
    #OEMActivation = [bool]$True
    WindowsUpdate = [bool]$true
    WindowsUpdateDrivers = [bool]$true
    #WindowsDefenderUpdate = [bool]$true
    SetTimeZone = [bool]$true
    ClearDiskConfirm = [bool]$false
    #ShutdownSetupComplete = [bool]$false
    #SyncMSUpCatDriverUSB = [bool]$true
    #CheckSHA1 = [bool]$true
}

Write-Host -ForegroundColor Green “Starting OSDCloud ZTI”
Start-Sleep -Seconds 5

#Make sure I have the latest OSD Content
Write-Host -ForegroundColor Green “Updating OSD PowerShell Module”
Install-Module OSD -Force -SkipPublisherCheck

Write-Host -ForegroundColor Green “Importing OSD PowerShell Module”
Import-Module OSD -Force

#Start OSDCloud ZTI the RIGHT way
Write-Host -ForegroundColor Green “Start OSDCloud”
#Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage
Start-OSDCloudGUI

#Restart from WinPE
Write-Host -ForegroundColor Green “Restarting in 20 seconds!”
Start-Sleep -Seconds 20
wpeutil reboot
