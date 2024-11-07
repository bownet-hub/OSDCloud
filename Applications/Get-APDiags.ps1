param(
    [Parameter(Mandatory = $False)] [String] $CABFile,
    [Parameter(Mandatory = $False)] [String] $ZIPFile,
    [Parameter(Mandatory = $False)] [Switch] $Online,
    [Parameter(Mandatory = $False)] [Switch] $AllSessions,
    [Parameter(Mandatory = $False)] [Switch] $ShowPolicies,
    [Parameter(Mandatory = $false)] [string]$Tenant,
    [Parameter(Mandatory = $false)] [string]$AppId,
    [Parameter(Mandatory = $false)] [string]$AppSecret
)
$RegistryKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Autopilot\EnrollmentStatusTracking"
$RegistryWatcher = New-Object System.Management.ManagementEventWatcher
$RegistryWatcher.Query = New-Object System.Management.WqlEventQuery("__InstanceModificationEvent", "TargetInstance isa 'RegistryKey' and TargetInstance.Name = '$RegistryKey'")

Register-ObjectEvent $RegistryWatcher -Action {
    Write-Host "Registry change detected at $(Get-Date)"
    Write-Host "Key Path: $($Event.SourceEventArgs.NewEvent.TargetInstance.Name)"
    Get-AutopilotDiagnosticsCommunity.ps1 @PSBoundParameters
}

# Keep the script running to monitor changes
while ($true) {
    Start-Sleep -Seconds 1
}
