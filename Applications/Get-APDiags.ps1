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

Get-AutopilotDiagnosticsCommunity.ps1 @PSBoundParameters
