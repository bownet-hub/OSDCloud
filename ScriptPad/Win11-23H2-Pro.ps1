#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$OSName = 'Windows 11 23H2 x64'
$OSEdition = 'Pro'
$OSActivation = 'Retail'
$OSLanguage = 'en-us'

#Set OSDCloud Vars
Write-Host -ForegroundColor Green “Starting OSDCloud ZTI”
$Global:StartOSDCloud = [ordered]@{
    Restart = [bool]$true
    RecoveryPartition = [bool]$true
    WindowsUpdate = [bool]$true
    WindowsUpdateDrivers = [bool]$true
    SetTimeZone = [bool]$true
    ClearDiskConfirm = [bool]$false
}

get-variable startosdcloud -valueonly

#Write-Host -ForegroundColor Green “Starting OSDCloud ZTI”
#Start-Sleep -Seconds 5

Write-Host -ForegroundColor Green “Importing OSD PowerShell Module”
#Import-Module OSD -Force

Write-Host -ForegroundColor Green “Start OSDCloud”
#Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage
