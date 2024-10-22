# Set OSDCloudGUI Defaults
$Global:OSDCloud_Defaults = [ordered]@{
    BrandName             = "Out of the Box Solutions"
    BrandColor            = "Blue"
    OSActivation          = "Retail"
    OSActivationValues    = "Retail"
    OSEdition             = "Pro"
    OSEditionValues       = "Pro"
    OSLanguageValues      = "en-us"
    captureScreenshots    = $false
    ClearDiskConfirm      = $false
    restartComputer       = $true
    updateDiskDrivers     = $false
    updateFirmware        = $false
    updateNetworkDrivers  = $false
    updateSCSIDrivers     = $false
    WindowsUpdateDrivers  = $false
    WindowsDefenderUpdate = $false
    SyncMSUpCatDriverUSB  = $true
}
#     WindowsUpdate         = $true

Write-Output $Global:OSDCloud_Defaults

# Create 'Start-OSDCloudGUI.json' - During WinPE SystemDrive will be 'X:'
$OSDCloudGUIjson = New-Item -Path "$($env:SystemDrive)\OSDCloud\Automate\Start-OSDCloudGUI.json" -Force

# Covert data to Json and export to the file created above
$Global:OSDCloud_Defaults | ConvertTo-Json -Depth 10 | Out-File -FilePath $($OSDCloudGUIjson.FullName) -Force

Write-Host -ForegroundColor Green “Starting OSDCloud”
Start-OSDCloudGUI
