# Parameters to pass to Get-AutopilotDiagnosticsCommunity.ps1
param(
    [Parameter(Mandatory = $False)] [String] $CABFile,
    [Parameter(Mandatory = $False)] [String] $ZIPFile,
    [Parameter(Mandatory = $False)] [Switch] $Online,
    [Parameter(Mandatory = $False)] [Switch] $AllSessions,
    [Parameter(Mandatory = $False)] [Switch] $ShowPolicies,
    [Parameter(Mandatory = $false)] [string] $Tenant,
    [Parameter(Mandatory = $false)] [string] $AppId,
    [Parameter(Mandatory = $false)] [string] $AppSecret
)

$LogFile = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AutoPilotDiagnostics.log"

#Start logging
Start-Transcript -Path "$LogFile" -Append
$dtFormat = 'dd-MMM-yyyy HH:mm:ss'
Write-Host "$(Get-Date -Format $dtFormat)"

# Get log file properties to use for measuring elapsed time
$fileStart = Get-ChildItem -Path "C:\OSDCloud\Logs" -Filter *Deploy-OSDCloud.log
$fileAP = Get-ChildItem -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"

# Autopilot registry key to monitor
# New keys are created when each application installation is complete
$RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows\Autopilot\EnrollmentStatusTracking\ESPTrackingInfo\Diagnostics\Sidecar"

# Check if the registry key exists
if (-not (Test-Path $RegistryKey)) {
    New-Item -Path $RegistryKey -Force
}

# Get initial snapshot of subkeys
$InitialSubkeys = Get-ChildItem $RegistryKey | Select-Object -ExpandProperty PSChildName

# Run script initially
Get-AutoPilotDiagnosticsCommunity.ps1 @PSBoundParameters

while ($true) {
    # Get current subkeys
    $CurrentSubkeys = Get-ChildItem $RegistryKey | Select-Object -ExpandProperty PSChildName

    # Compare and find new subkeys
    $NewSubkeys = Compare-Object -ReferenceObject $InitialSubkeys -DifferenceObject $CurrentSubkeys -PassThru

    # Registry keys are added after each application install completes
    if ($NewSubkeys) {
        Get-AutoPilotDiagnosticsCommunity.ps1 @PSBoundParameters

        # Compare creation time of AutoPilot Diagnostics log to current time
        $APTimeSpan = New-TimeSpan -Start $fileAP.CreationTime.ToUniversalTime() -End (Get-Date).ToUniversalTime()
        Write-Host "Time in Autopilot $($APTimeSpan.ToString("hh' hours 'mm' minutes 'ss' seconds'"))"
        
        # Compare creation time of OSD log to current time
        $FullTimeSpan = New-TimeSpan -Start $fileStart.CreationTime.ToUniversalTime() -End (Get-Date).ToUniversalTime()
        Write-Host "Total provisioning time $($FullTimeSpan.ToString("hh' hours 'mm' minutes 'ss' seconds'"))"
    }

    # Update initial snapshot
    $InitialSubkeys = $CurrentSubkeys

    # Sleep for a specified interval (in seconds)
    Start-Sleep -Seconds 5
}
