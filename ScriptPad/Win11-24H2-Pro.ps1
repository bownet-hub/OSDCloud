#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$OSName = 'Windows 11 24H2 x64'
$OSEdition = 'Pro'
$OSActivation = 'Retail'
$OSLanguage = 'en-us'

#Set OSDCloud Vars
Write-Host -ForegroundColor Green “Setting variables”
$Global:MyOSDCloud = [ordered]@{
    OSName = 'Windows 11 24H2 x64'
    OSEdition = 'Pro'
    OEMActivation = 'Retail'
    OSLanguage = 'en-us'
    WindowsUpdate = [bool]$true
    WindowsDefenderUpdate = [bool]$false
    ClearDiskConfirm = [bool]$false
    Restart = [bool]$true
    }

Get-Variable MyOSDCloud -ValueOnly
Start-Sleep -Seconds 5

Write-Host -ForegroundColor Green “Starting OSDCloud”
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage
#Start-OSDCloud -ZTI
