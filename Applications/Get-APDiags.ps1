param(
    [Parameter(Mandatory = $False)] [String] $CABFile,
    [Parameter(Mandatory = $False)] [String] $ZIPFile,
    [Parameter(Mandatory = $False)] [Switch] $Online,
    [Parameter(Mandatory = $False)] [Switch] $AllSessions,
    [Parameter(Mandatory = $False)] [Switch] $ShowPolicies,
    [Parameter(Mandatory = $False)] [String] $Tenant,
    [Parameter(Mandatory = $False)] [String] $AppId,
    [Parameter(Mandatory = $False)] [String] $AppSecret
)

Get-AutopilotDiagnosticsCommunity.ps1 @PSBoundParameters

# Define the registry path to monitor
$registryPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Autopilot\EnrollmentStatusTracking\ESPTrackingInfo\Diagnostics\ExpectedMSIAppPackages"

# Define the action to take when a change occurs
$action = {
    param($event)
    # Run the script with the provided parameters
    Get-AutopilotDiagnosticsCommunity.ps1 @PSBoundParameters
}

# Register the event to monitor the registry key
Register-WmiEvent -Query "SELECT * FROM RegistryKeyChangeEvent WHERE Hive='HKEY_LOCAL_MACHINE' AND KeyPath='SOFTWARE\\Microsoft\\Windows\\Autopilot\\EnrollmentStatusTracking\\ESPTrackingInfo\\Diagnostics\\ExpectedMSIAppPackages'" -Action $action

# Keep the script running to monitor changes
while ($true) {
    Start-Sleep -Seconds 1
}

