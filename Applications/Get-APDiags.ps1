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

#Create file if doesn't exist
if (!(Test-Path $LogFile)) {
    New-Item -ItemType File -Path $LogFile -Force | Out-Null
}

# Autopilot registry key to monitor
# New keys are created when each application installation is complete
$RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows\Autopilot\EnrollmentStatusTracking\ESPTrackingInfo\Diagnostics\ExpectedMSIAppPackages"

# Get initial snapshot of subkeys
$InitialSubkeys = Get-ChildItem $RegistryKey | Select-Object -ExpandProperty PSChildName

# Run script initially
Get-AutoPilotDiagnosticsCommunity.ps1 @PSBoundParameters | Out-File -FilePath $LogFile -Append

while ($true) {
    # Get current subkeys
    $CurrentSubkeys = Get-ChildItem $RegistryKey | Select-Object -ExpandProperty PSChildName

    # Compare and find new subkeys
    $NewSubkeys = Compare-Object -ReferenceObject $InitialSubkeys -DifferenceObject $CurrentSubkeys -PassThru

    # Registry keys are added after each application install completes
    if ($NewSubkeys) {
        Get-AutoPilotDiagnosticsCommunity.ps1 @PSBoundParameters | Out-File -FilePath $LogFile -Append
    }

    # Update initial snapshot
    $InitialSubkeys = $CurrentSubkeys

    # Sleep for a specified interval (in seconds)
    Start-Sleep -Seconds 5
}
