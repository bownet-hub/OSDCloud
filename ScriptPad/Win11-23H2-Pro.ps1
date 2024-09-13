#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$OSName = 'Windows 11 23H2 x64'
$OSEdition = 'Pro'
$OSActivation = 'Retail'
$OSLanguage = 'en-us'

#Set OSDCloud Vars
Write-Host -ForegroundColor Green “Setting variables”
$Global:MyOSDCloud = [ordered]@{
    Restart = [bool]$true
    ZTI = [bool]$true
}

Get-Variable MyOSDCloud -ValueOnly
Start-Sleep -Seconds 5

Write-Host -ForegroundColor Green “Starting OSDCloud”
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage
