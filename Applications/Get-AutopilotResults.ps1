function Send-Email {
    param(
        [Parameter(Mandatory = $true)] [string] $AppId,
        [Parameter(Mandatory = $true)] [string] $AppSecret,
        [Parameter(Mandatory = $true)] [string] $Tenant,
        [Parameter(Mandatory = $true)] [string] $ToRecipient,
        [Parameter(Mandatory = $true)] [string] $From,
        [Parameter(Mandatory = $true)] [string] $attachmentPath
    )
    
    try {
        $ComputerName = (Get-ComputerInfo).csname
        $BiosSerialNumber = Get-MyBiosSerialNumber
        $ComputerManufacturer = Get-MyComputerManufacturer
        $ComputerModel = Get-MyComputerModel
        
        # Get the access token
        $body = @{
            client_id     = $AppId
            scope         = "https://graph.microsoft.com/.default"
            client_secret = $AppSecret
            grant_type    = "client_credentials"
        }
        
        $response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token" -Method Post -ContentType "application/x-www-form-urlencoded" -Body $body
        $accessToken = $response.access_token
        
        # Read the attachment as a byte array
        $attachmentBytes = [System.IO.File]::ReadAllBytes($attachmentPath)
        $attachmentEncoded = [System.Convert]::ToBase64String($attachmentBytes)
        
        # Create the message
        $message = @{
            message         = @{
                subject      = "Autopilot Completed for $ComputerName"
                body         = @{
                    contentType = "Text"
                    content     = "The following client has been successfully deployed:
                          Computer Name: $ComputerName
                          BIOS Serial Number: $BiosSerialNumber
                          Computer Manufacturer: $($ComputerManufacturer)
                          Computer Model: $($ComputerModel)"
                }
                attachments  = @(
                    @{
                        "@odata.type" = "#microsoft.graph.fileAttachment"
                        Name          = "Autopilot-$ComputerName.txt"
                        ContentBytes  = $attachmentEncoded
                    }
                )
                toRecipients = @(
                    @{
                        emailAddress = @{
                            address = $ToRecipient
                        }
                    }
                )
            }
            saveToSentItems = $false
        }
        
        # Send the email
        Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/$from/sendMail" -Method Post -Headers @{
            Authorization  = "Bearer $accessToken"
            "Content-Type" = "application/json"
        } -Body ($message | ConvertTo-Json -Depth 10)
    }
    catch {
        Write-Error "Failed to send email: $_"
    }
}

function Get-AutopilotResults {
    param(
        [Parameter(Mandatory = $true)] [string] $AppId,
        [Parameter(Mandatory = $true)] [string] $AppSecret,
        [Parameter(Mandatory = $true)] [string] $Tenant,
        [Parameter(Mandatory = $true)] [string] $ToRecipient,
        [Parameter(Mandatory = $true)] [string] $From
    )

    $LogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AutopilotLog.log"

    # Start logging
    Start-Transcript -Path $LogPath
    $dtFormat = 'dd-MMM-yyyy HH:mm:ss'
    Write-Host "$(Get-Date -Format $dtFormat)"

    Get-AutopilotDiagnosticInfo -Online -Tenant $Tenant -AppId $AppId -AppSecret $AppSecret

    Stop-Transcript

    # Remove the header containing sensitive information from the transcript file before emailing
    (Get-Content $LogPath | Select-Object -Skip 18) | Set-Content $LogPath

    Send-Email -AppId $AppId -AppSecret $AppSecret -Tenant $Tenant -ToRecipient $ToRecipient -From $From -attachmentPath $LogPath
}

function Get-AutopilotDiagnosticInfo {
    <#PSScriptInfo
 
.VERSION 5.7
.GUID b45605b6-65aa-45ec-a23c-f5291f9fb519
.AUTHOR AndrewTaylor, Michael Niehaus & Steven van Beek
.COMPANYNAME
.COPYRIGHT GPL
.TAGS
.LICENSEURI https://github.com/andrew-s-taylor/public/blob/main/LICENSE
.PROJECTURI https://github.com/andrew-s-taylor/public
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.RELEASENOTES
Version 5.7: Fixed LastLoggedState for Win32Apps and Added support for new Graph Module
Version 5.6: Fixed parameter handling
Version 5.5: Added support for a zip file
Version 5.4: Added additional ESP details
Version 5.3: Added hardware and OS version details
Version 5.2: Added device registration events
Version 5.1: Bug fixes
Version 5.0: Bug fixes
Version 4.9: Bug fixes
Version 4.8: Added Delivery Optimization results (but not when using a CAB file), ensured events are displayed even when no ESP
Version 4.7: Added ESP settings, fixed bugs
Version 4.6: Fixed typo
Version 4.5: Fixed but to properly reported Win32 app status when a Win32 app is installed during user ESP
Version 4.4: Added more ODJ info
Version 4.3: Added policy tracking
Version 4.2: Bug fixes for Windows 10 2004 (event ID changes)
Version 4.1: Renamed to Get-AutopilotDiagnostics
Version 4.0: Added sidecar installation info
Version 3.9: Bug fixes
Version 3.8: Bug fixes
Version 3.7: Modified Office logic to ensure it accurately reflected what ESP thinks the status is. Added ShowPolicies option.
Version 3.2: Fixed sidecar detection logic
Version 3.1: Fixed ODJ applied output
Version 3.0: Added the ability to process logs as well
Version 2.2: Added new IME MSI guid, new -AllSessions switch
Version 2.0: Added -online parameter to look up app and policy details
Version 1.0: Original published version
.PRIVATEDATA
#>

    <#
 
.DESCRIPTION
This script displays diagnostics information from the current PC or a captured set of logs. This includes details about the Autopilot profile settings; policies, apps, certificate profiles, etc. being tracked via the Enrollment Status Page; and additional information.
  
This should work with Windows 10 1903 and later (earlier versions have not been validated). This script will not work on ARM64 systems due to registry redirection from the use of x86 PowerShell.exe.
  
 
#> 
    <#
.SYNOPSIS
Displays Windows Autopilot diagnostics information from the current PC or a captured set of logs.
  
 
.PARAMETER Online
Look up the actual policy and app names via the Microsoft Graph API
  
.PARAMETER AllSessions
Show all ESP progress instead of just the final details.
  
.PARAMETER CABFile
Processes the information in the specified CAB file (captured by MDMDiagnosticsTool.exe -area Autopilot -cab filename.cab) instead of from the registry.
  
.PARAMETER ZIPFile
Processes the information in the specified ZIP file (captured by MDMDiagnosticsTool.exe -area Autopilot -zip filename.zip) instead of from the registry.
  
.PARAMETER ShowPolicies
Shows the policy details as recorded in the NodeCache registry keys, in the order that the policies were received by the client.
  
.EXAMPLE
.\Get-AutopilotDiagnostics.ps1
  
.EXAMPLE
.\Get-AutopilotDiagnostics.ps1 -Online
  
.EXAMPLE
.\Get-AutopilotESPStatus.ps1 -AllSessions
  
.EXAMPLE
.\Get-AutopilotDiagnostics.ps1 -CABFile C:\Autopilot.cab -Online -AllSessions
  
.EXAMPLE
.\Get-AutopilotDiagnostics.ps1 -ZIPFile C:\Autopilot.zip
  
.EXAMPLE
.\Get-AutopilotDiagnostics.ps1 -ShowPolicies
  
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)] [String] $CABFile = $null,
        [Parameter(Mandatory = $False)] [String] $ZIPFile = $null,
        [Parameter(Mandatory = $False)] [Switch] $Online = $false,
        [Parameter(Mandatory = $False)] [Switch] $AllSessions = $false,
        [Parameter(Mandatory = $False)] [Switch] $ShowPolicies = $false,
        [Parameter(Mandatory = $false)] [string] $Tenant,
        [Parameter(Mandatory = $false)] [string] $AppId,
        [Parameter(Mandatory = $false)] [string] $AppSecret
    )

    Begin {
        # Process log files if needed
        $script:useFile = $false
        if ($CABFile -or $ZIPFile) {

            if (-not (Test-Path "$($env:TEMP)\ESPStatus.tmp")) {
                New-Item -Path "$($env:TEMP)\ESPStatus.tmp" -ItemType "directory" | Out-Null
            }
            Remove-Item -Path "$($env:TEMP)\ESPStatus.tmp\*.*" -Force -Recurse        
            $script:useFile = $true

            # If using a CAB file, extract the needed files from it
            if ($CABFile) {
                $fileList = @("MdmDiagReport_RegistryDump.reg", "microsoft-windows-devicemanagement-enterprise-diagnostics-provider-admin.evtx",
                    "microsoft-windows-user device registration-admin.evtx", "AutopilotDDSZTDFile.json", "*.csv")

                $fileList | % {
                    $null = & expand.exe "$CABFile" -F:$_ "$($env:TEMP)\ESPStatus.tmp\" 
                    if (-not (Test-Path "$($env:TEMP)\ESPStatus.tmp\$_")) {
                        Write-Error "Unable to extract $_ from $CABFile"
                    }
                }
            }
            else {
                # If using a ZIP file, just extract the entire contents (not as easy to do selected files)
                Expand-Archive -Path $ZIPFile -DestinationPath "$($env:TEMP)\ESPStatus.tmp\"
            }

            # Get the hardware hash information
            $csvFile = (Get-ChildItem "$($env:TEMP)\ESPStatus.tmp\*.csv").FullName
            if ($csvFile) {
                $csv = Get-Content $csvFile | ConvertFrom-Csv
                $hash = $csv.'Hardware Hash'
            }

            # Edit the path in the .reg file
            $content = Get-Content -Path "$($env:TEMP)\ESPStatus.tmp\MdmDiagReport_RegistryDump.reg"
            $content = $content -replace "\[HKEY_CURRENT_USER\\", "[HKEY_CURRENT_USER\ESPStatus.tmp\USER\"
            $content = $content -replace "\[HKEY_LOCAL_MACHINE\\", "[HKEY_CURRENT_USER\ESPStatus.tmp\MACHINE\"
            $content = $content -replace '^ "', '"'
            $content = $content -replace '^ @', '@'
            $content = $content -replace 'DWORD:', 'dword:'
            "Windows Registry Editor Version 5.00`n" | Set-Content -Path "$($env:TEMP)\ESPStatus.tmp\MdmDiagReport_Edited.reg"
            $content | Add-Content -Path "$($env:TEMP)\ESPStatus.tmp\MdmDiagReport_Edited.reg"

            # Remove the registry info if it exists
            if (Test-Path "HKCU:\ESPStatus.tmp") {
                Remove-Item -Path "HKCU:\ESPStatus.tmp" -Recurse -Force
            }

            # Import the .reg file
            $null = & reg.exe IMPORT "$($env:TEMP)\ESPStatus.tmp\MdmDiagReport_Edited.reg" 2>&1

            # Configure the (not live) constants
            $script:provisioningPath = "HKCU:\ESPStatus.tmp\MACHINE\software\microsoft\provisioning"
            $script:autopilotDiagPath = "HKCU:\ESPStatus.tmp\MACHINE\software\microsoft\provisioning\Diagnostics\Autopilot"
            $script:omadmPath = "HKCU:\ESPStatus.tmp\MACHINE\software\microsoft\provisioning\OMADM"
            $script:path = "HKCU:\ESPStatus.tmp\MACHINE\Software\Microsoft\Windows\Autopilot\EnrollmentStatusTracking\ESPTrackingInfo\Diagnostics"
            $script:msiPath = "HKCU:\ESPStatus.tmp\MACHINE\Software\Microsoft\EnterpriseDesktopAppManagement"
            $script:officePath = "HKCU:\ESPStatus.tmp\MACHINE\Software\Microsoft\OfficeCSP"
            $script:sidecarPath = "HKCU:\ESPStatus.tmp\MACHINE\Software\Microsoft\IntuneManagementExtension\Win32Apps"
            $script:enrollmentsPath = "HKCU:\ESPStatus.tmp\MACHINE\software\microsoft\enrollments"
        }
        else {
            # Configure live constants
            $script:provisioningPath = "HKLM:\software\microsoft\provisioning"
            $script:autopilotDiagPath = "HKLM:\software\microsoft\provisioning\Diagnostics\Autopilot"
            $script:omadmPath = "HKLM:\software\microsoft\provisioning\OMADM"
            $script:path = "HKLM:\Software\Microsoft\Windows\Autopilot\EnrollmentStatusTracking\ESPTrackingInfo\Diagnostics"
            $script:msiPath = "HKLM:\Software\Microsoft\EnterpriseDesktopAppManagement"
            $script:officePath = "HKLM:\Software\Microsoft\OfficeCSP"
            $script:sidecarPath = "HKLM:\Software\Microsoft\IntuneManagementExtension\Win32Apps"
            $script:enrollmentsPath = "HKLM:\Software\Microsoft\enrollments"

            $hash = (Get-WmiObject -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'").DeviceHardwareData
        }

        # Configure other constants
        $script:officeStatus = @{"0" = "None"; "10" = "Initialized"; "20" = "Download In Progress"; "25" = "Pending Download Retry";
            "30" = "Download Failed"; "40" = "Download Completed"; "48" = "Pending User Session"; "50" = "Enforcement In Progress"; 
            "55" = "Pending Enforcement Retry"; "60" = "Enforcement Failed"; "70" = "Success / Enforcement Completed"
        }
        $script:espStatus = @{"1" = "Not Installed"; "2" = "Downloading / Installing"; "3" = "Success / Installed"; "4" = "Error / Failed" }
        $script:policyStatus = @{"0" = "Not Processed"; "1" = "Processed" }

        # Configure any other global variables
        $script:observedTimeline = @()
    }

    Process {
        #------------------------
        # Functions
        #------------------------

    
        Function Connect-ToGraph {
            <#
.SYNOPSIS
Authenticates to the Graph API via the Microsoft.Graph.Authentication module.
  
.DESCRIPTION
The Connect-ToGraph cmdlet is a wrapper cmdlet that helps authenticate to the Intune Graph API using the Microsoft.Graph.Authentication module. It leverages an Azure AD app ID and app secret for authentication or user-based auth.
  
.PARAMETER Tenant
Specifies the tenant (e.g. contoso.onmicrosoft.com) to which to authenticate.
  
.PARAMETER AppId
Specifies the Azure AD app ID (GUID) for the application that will be used to authenticate.
  
.PARAMETER AppSecret
Specifies the Azure AD app secret corresponding to the app ID that will be used to authenticate.
 
.PARAMETER Scopes
Specifies the user scopes for interactive authentication.
  
.EXAMPLE
Connect-ToGraph -TenantId $tenantID -AppId $app -AppSecret $secret
  
-#>
            [cmdletbinding()]
            param
            (
                [Parameter(Mandatory = $false)] [string]$Tenant,
                [Parameter(Mandatory = $false)] [string]$AppId,
                [Parameter(Mandatory = $false)] [string]$AppSecret,
                [Parameter(Mandatory = $false)] [string]$scopes
            )

            Process {
                Import-Module Microsoft.Graph.Authentication
                $version = (get-module microsoft.graph.authentication | Select-Object -expandproperty Version).major

                if ($AppId -ne "") {
                    $body = @{
                        grant_type    = "client_credentials";
                        client_id     = $AppId;
                        client_secret = $AppSecret;
                        scope         = "https://graph.microsoft.com/.default";
                    }
     
                    $response = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token -Body $body
                    $accessToken = $response.access_token
     
                    $accessToken
                    if ($version -eq 2) {
                        write-host "Version 2 module detected"
                        $accesstokenfinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
                    }
                    else {
                        write-host "Version 1 Module Detected"
                        Select-MgProfile -Name Beta
                        $accesstokenfinal = $accessToken
                    }
                    $graph = Connect-MgGraph  -AccessToken $accesstokenfinal 
                    Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
                }
                else {
                    if ($version -eq 2) {
                        write-host "Version 2 module detected"
                    }
                    else {
                        write-host "Version 1 Module Detected"
                        Select-MgProfile -Name Beta
                    }
                    $graph = Connect-MgGraph -scopes $scopes
                    Write-Host "Connected to Intune tenant $($graph.TenantId)"
                }
            }
        }    

        Function RecordStatus() {
            param
            (
                [Parameter(Mandatory = $true)] [String] $detail,
                [Parameter(Mandatory = $true)] [String] $status,
                [Parameter(Mandatory = $true)] [String] $color,
                [Parameter(Mandatory = $true)] [datetime] $date
            )

            # See if there is already an entry for this policy and status
            $found = $script:observedTimeline | ? { $_.Detail -eq $detail -and $_.Status -eq $status }
            if (-not $found) {
                $script:observedTimeline += New-Object PSObject -Property @{
                    "Date"   = $date
                    "Detail" = $detail
                    "Status" = $status
                    "Color"  = $color
                }
            }
        }

        Function AddDisplay() {
            param
            (
                [Parameter(Mandatory = $true)] [ref]$items
            )
            $items.Value | % {
                Add-Member -InputObject $_ -NotePropertyName display -NotePropertyValue $AllSessions
            }
            $items.Value[$items.Value.Count - 1].display = $true
        }
    
        Function ProcessApps() {
            param
            (
                [Parameter(Mandatory = $true, ValueFromPipeline = $True)] [Microsoft.Win32.RegistryKey] $currentKey,
                [Parameter(Mandatory = $true)] $currentUser,
                [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $True)] [bool] $display
            )

            Begin {
                if ($display) { Write-Host "Apps:" }
            }

            Process {
                if ($display) { Write-Host " $(([datetime]$currentKey.PSChildName).ToString('u'))" }
                $currentKey.Property | % {
                    if ($_.StartsWith("./Device/Vendor/MSFT/EnterpriseDesktopAppManagement/MSI/")) {
                        $msiKey = [URI]::UnescapeDataString(($_.Split("/"))[6])
                        $fullPath = "$msiPath\$currentUser\MSI\$msiKey"
                        if (Test-Path $fullPath) {
                            $status = (Get-ItemProperty -Path $fullPath).Status
                            $msiFile = (Get-ItemProperty -Path $fullPath).CurrentDownloadUrl
                        }
                        if ($status -eq "" -or $status -eq $null) {
                            $status = 0
                        } 
                        if ($msiFile -match "IntuneWindowsAgent.msi") {
                            $msiKey = "Intune Management Extensions ($($msiKey))"
                        }
                        elseif ($Online) {
                            $found = $apps | ? { $_.ProductCode -contains $msiKey }
                            $msiKey = "$($found.DisplayName) ($($msiKey))"
                        }
                        if ($status -eq 70) {
                            if ($display) { Write-Host " MSI $msiKey : $status ($($officeStatus[$status.ToString()]))" -ForegroundColor Green }
                            RecordStatus -detail "MSI $msiKey" -status $officeStatus[$status.ToString()] -color "Green" -date $currentKey.PSChildName
                        }
                        elseif ($status -eq 60) {
                            if ($display) { Write-Host " MSI $msiKey : $status ($($officeStatus[$status.ToString()]))" -ForegroundColor Red }
                            RecordStatus -detail "MSI $msiKey" -status $officeStatus[$status.ToString()] -color "Red" -date $currentKey.PSChildName
                        }
                        #else {
                        #    if ($display) { Write-Host " MSI $msiKey : $status ($($officeStatus[$status.ToString()]))" -ForegroundColor Yellow }
                        #    RecordStatus -detail "MSI $msiKey" -status $officeStatus[$status.ToString()] -color "Yellow" -date $currentKey.PSChildName
                        #}
                    }
                    elseif ($_.StartsWith("./Vendor/MSFT/Office/Installation/")) {
                        # Report the main status based on what ESP is tracking
                        $status = Get-ItemPropertyValue -Path $currentKey.PSPath -Name $_

                        # Then try to get the detailed Office status
                        $officeKey = [URI]::UnescapeDataString(($_.Split("/"))[5])
                        $fullPath = "$officepath\$officeKey"
                        if (Test-Path $fullPath) {
                            $oStatus = (Get-ItemProperty -Path $fullPath).FinalStatus

                            if ($oStatus -eq $null) {
                                $oStatus = (Get-ItemProperty -Path $fullPath).Status
                                if ($oStatus -eq $null) {
                                    $oStatus = "None"
                                }
                            }
                        }
                        else {
                            $oStatus = "None"
                        }
                        if ($officeStatus.Keys -contains $oStatus.ToString()) {
                            $officeStatusText = $officeStatus[$oStatus.ToString()]
                        }
                        else {
                            $officeStatusText = $oStatus
                        }
                        if ($status -eq 1) {
                            if ($display) { Write-Host " Office $officeKey : $status ($($policyStatus[$status.ToString()]) / $officeStatusText)" -ForegroundColor Green }
                            RecordStatus -detail "Office $officeKey" -status "$($policyStatus[$status.ToString()]) / $officeStatusText" -color "Green" -date $currentKey.PSChildName
                        }
                        else {
                            if ($display) { Write-Host " Office $officeKey : $status ($($policyStatus[$status.ToString()]) / $officeStatusText)" -ForegroundColor Yellow }
                            RecordStatus -detail "Office $officeKey" -status "$($policyStatus[$status.ToString()]) / $officeStatusText" -color "Yellow" -date $currentKey.PSChildName
                        }
                    }
                    else {
                        if ($display) { Write-Host " $_ : Unknown app" }
                    }
                }
            }

        }

        Function ProcessModernApps() {
            param
            (
                [Parameter(Mandatory = $true, ValueFromPipeline = $True)] [Microsoft.Win32.RegistryKey] $currentKey,
                [Parameter(Mandatory = $true)] $currentUser,
                [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $True)] [bool] $display
            )

            Begin {
                if ($display) { Write-Host "Modern Apps:" }
            }

            Process {
                if ($display) { Write-Host " $(([datetime]$currentKey.PSChildName).ToString('u'))" }
                $currentKey.Property | % {
                    $status = (Get-ItemPropertyValue -path $currentKey.PSPath -Name $_).ToString()
                    if ($_.StartsWith("./User/Vendor/MSFT/EnterpriseModernAppManagement/AppManagement/")) {
                        $appID = [URI]::UnescapeDataString(($_.Split("/"))[7])
                        $type = "User UWP"
                    }
                    elseif ($_.StartsWith("./Device/Vendor/MSFT/EnterpriseModernAppManagement/AppManagement/")) {
                        $appID = [URI]::UnescapeDataString(($_.Split("/"))[7])
                        $type = "Device UWP"
                    }
                    else {
                        $appID = $_
                        $type = "Unknown UWP"
                    }
                    if ($status -eq "1") {
                        if ($display) { Write-Host " $type $appID : $status ($($policyStatus[$status]))" -ForegroundColor Green }
                        RecordStatus -detail "UWP $appID" -status $policyStatus[$status] -color "Green" -date $currentKey.PSChildName
                    }
                    else {
                        if ($display) { Write-Host " $type $appID : $status ($($policyStatus[$status]))" -ForegroundColor Yellow }
                    }
                }
            }

        }

        Function ProcessSidecar() {
            param
            (
                [Parameter(Mandatory = $true, ValueFromPipeline = $True)] [Microsoft.Win32.RegistryKey] $currentKey,
                [Parameter(Mandatory = $true)] $currentUser,
                [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $True)] [bool] $display
            )

            Begin {
                if ($display) { Write-Host "Sidecar apps:" }
            }

            Process {
                if ($display) { Write-Host " $(([datetime]$currentKey.PSChildName).ToString('u'))" }
                $currentKey.Property | % {
                    $win32Key = [URI]::UnescapeDataString(($_.Split("/"))[9])
                    $status = Get-ItemPropertyValue -path $currentKey.PSPath -Name $_
                    if ($Online) {
                        $found = $apps | ? { $win32Key -match $_.Id }
                        $win32Key = "$($found.DisplayName) ($($win32Key))"
                    }
                    $appGuid = $win32Key.Substring(9)
                    $sidecarApp = "$sidecarPath\$currentUser\$appGuid"
                    $exitCode = $null
                    if (Test-Path $sidecarApp) {
                        $exitCode = (Get-ItemProperty -Path $sidecarApp).ExitCode
                    }
                    if ($status -eq "3") {
                        if ($exitCode -ne $null) {
                            if ($display) { Write-Host " Win32 $win32Key : $status ($($espStatus[$status.ToString()]), rc = $exitCode)" -ForegroundColor Green }
                        }
                        else {
                            if ($display) { Write-Host " Win32 $win32Key : $status ($($espStatus[$status.ToString()]))" -ForegroundColor Green }
                        }
                        RecordStatus -detail "$win32Key" -status $espStatus[$status.ToString()] -color "Green" -date $currentKey.PSChildName
                    }
                    elseif ($status -eq "4") {
                        if ($exitCode -ne $null) {
                            if ($display) { Write-Host " Win32 $win32Key : $status ($($espStatus[$status.ToString()]), rc = $exitCode)" -ForegroundColor Red }
                        }
                        else {
                            if ($display) { Write-Host " Win32 $win32Key : $status ($($espStatus[$status.ToString()]))" -ForegroundColor Red }
                        }
                        RecordStatus -detail "$win32Key" -status $espStatus[$status.ToString()] -color "Red" -date $currentKey.PSChildName
                    }
                    #else {
                    #    if ($exitCode -ne $null) {
                    #        if ($display) { Write-Host " Win32 $win32Key : $status ($($espStatus[$status.ToString()]), rc = $exitCode)" -ForegroundColor Yellow }
                    #    }
                    #    else {
                    #        if ($display) { Write-Host " Win32 $win32Key : $status ($($espStatus[$status.ToString()]))" -ForegroundColor Yellow }
                    #    }
                    #    if ($status -ne "1") {
                    #        RecordStatus -detail "Win32 $win32Key" -status $espStatus[$status.ToString()] -color "Yellow" -date $currentKey.PSChildName
                    #    }
                    #}
                }
            }

        }

        Function ProcessPolicies() {
            param
            (
                [Parameter(Mandatory = $true, ValueFromPipeline = $True)] [Microsoft.Win32.RegistryKey] $currentKey,
                [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $True)] [bool] $display
            )

            Begin {
                if ($display) { Write-Host "Policies:" }
            }

            Process {
                if ($display) { Write-Host " $(([datetime]$currentKey.PSChildName).ToString('u'))" }
                $currentKey.Property | % {
                    $status = Get-ItemPropertyValue -path $currentKey.PSPath -Name $_
                    if ($status -eq "1") {
                        if ($display) { Write-Host " Policy $_ : $status ($($policyStatus[$status.ToString()]))" -ForegroundColor Green }
                        RecordStatus -detail "Policy $_" -status $policyStatus[$status.ToString()] -color "Green" -date $currentKey.PSChildName
                    }
                    #else {
                    #    if ($display) { Write-Host " Policy $_ : $status ($($policyStatus[$status.ToString()]))" -ForegroundColor Yellow }
                    #}
                }
            }

        }

        Function ProcessCerts() {
            param
            (
                [Parameter(Mandatory = $true, ValueFromPipeline = $True)] [Microsoft.Win32.RegistryKey] $currentKey,
                [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $True)] [bool] $display
            )

            Begin {
                if ($display) { Write-Host "Certificates:" }
            }

            Process {
                if ($display) { Write-Host " $(([datetime]$currentKey.PSChildName).ToString('u'))" }
                $currentKey.Property | % {
                    $certKey = [URI]::UnescapeDataString(($_.Split("/"))[6])
                    $status = Get-ItemPropertyValue -path $currentKey.PSPath -Name $_
                    if ($Online) {
                        $found = $policies | ? { $certKey.Replace("_", "-") -match $_.Id }
                        $certKey = "$($found.DisplayName) ($($certKey))"
                    }
                    if ($status -eq "1") {
                        if ($display) { Write-Host " Cert $certKey : $status ($($policyStatus[$status.ToString()]))" -ForegroundColor Green }
                        RecordStatus -detail "Cert $certKey" -status $policyStatus[$status.ToString()] -color "Green" -date $currentKey.PSChildName
                    }
                    else {
                        if ($display) { Write-Host " Cert $certKey : $status ($($policyStatus[$status.ToString()]))" -ForegroundColor Yellow }
                    }
                }
            }

        }

        Function ProcessNodeCache() {

            Process {
                $nodeCount = 0
                while ($true) {
                    # Get the nodes in order. This won't work after a while because the older numbers are deleted as new ones are added
                    # but it will work out OK shortly after provisioning. The alternative would be to get all the subkeys and then sort
                    # them numerically instead of alphabetically, but that can be saved for later...
                    $node = Get-ItemProperty "$provisioningPath\NodeCache\CSP\Device\MS DM Server\Nodes\$nodeCount" -ErrorAction SilentlyContinue
                    if ($node -eq $null) {
                        break
                    }
                    $nodeCount += 1
                    $node | Select NodeUri, ExpectedValue
                }
            }

        }

        Function ProcessEvents() {

            Process {

                $productCode = 'IME-Not-Yet-Installed'
                if (Test-Path "$msiPath\S-0-0-00-0000000000-0000000000-000000000-000\MSI") {
                    Get-ChildItem -path "$msiPath\S-0-0-00-0000000000-0000000000-000000000-000\MSI" | % {
                        $file = (Get-ItemProperty -Path $_.PSPath).CurrentDownloadUrl
                        if ($file -match "IntuneWindowsAgent.msi") {
                            $productCode = Get-ItemPropertyValue -Path $_.PSPath -Name ProductCode
                        }
                    }
                }

                # Process device management events
                if ($script:useFile) {
                    $events = Get-WinEvent -Path "$($env:TEMP)\ESPStatus.tmp\microsoft-windows-devicemanagement-enterprise-diagnostics-provider-admin.evtx" -Oldest | ? { ($_.Message -match $productCode -and $_.Id -in 1905, 1906, 1920, 1922) -or $_.Id -in (72, 100, 107, 109, 110, 111) }
                }
                else {
                    $events = Get-WinEvent -LogName Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin -Oldest | ? { ($_.Message -match $productCode -and $_.Id -in 1905, 1906, 1920, 1922) -or $_.Id -in (72, 100, 107, 109, 110, 111) }
                }
                $events | % {
                    $message = $_.Message
                    $detail = "Sidecar"
                    $color = "Yellow"
                    $event = $_
                    switch ($_.id) {
                        { $_ -in (110, 109) } { 
                            $detail = "Offline Domain Join"
                            switch ($event.Properties[0].Value) {
                                0 { $message = "Offline domain join not configured" }
                                1 { $message = "Waiting for ODJ blob" }
                                2 { $message = "Processed ODJ blob" }
                                3 { $message = "Timed out waiting for ODJ blob or connectivity" }
                            }
                        }
                        111 { $detail = "Offline Domain Join"; $message = "Starting wait for ODJ blob" }
                        107 { $detail = "Offline Domain Join"; $message = "Successfully applied ODJ blob" }
                        100 { $detail = "Offline Domain Join"; $message = "Could not establish connectivity"; $color = "Red" }
                        72 { $detail = "MDM Enrollment" }
                        1905 { $message = "Download started" }
                        1906 { $message = "Download finished" }
                        1920 { $message = "Installation started" }
                        1922 { $message = "Installation finished" }
                        { $_ -in (1922, 72) } { $color = "Green" }
                    }
                    RecordStatus -detail $detail -date $_.TimeCreated -status $message -color $color
                }

                # Process device registration events
                if ($script:useFile) {
                    $events = Get-WinEvent -Path "$($env:TEMP)\ESPStatus.tmp\microsoft-windows-user device registration-admin.evtx" -Oldest | ? { $_.Id -in (306, 101) }
                }
                else {
                    $events = Get-WinEvent -LogName 'Microsoft-Windows-User Device Registration/Admin' -Oldest | ? { $_.Id -in (306, 101) }
                }
                $events | % {
                    $message = $_.Message
                    $detail = "Device Registration"
                    $color = "Yellow"
                    $event = $_
                    switch ($_.id) {
                        101 { $detail = "Device Registration"; $message = "SCP discovery successful." }
                        304 { $detail = "Device Registration"; $message = "Hybrid AADJ device registration failed." }
                        306 { $detail = "Device Registration"; $message = "Hybrid AADJ device registration succeeded."; $color = 'Green' }
                    }
                    RecordStatus -detail $detail -date $_.TimeCreated -status $message -color $color
                }

            }
    
        }
    
        #------------------------
        # Main code
        #------------------------

        # If online, make sure we are able to authenticate
        if ($Online) {

            #Check if modules are already imported
            $deviceManagementModule = Get-Module -ListAvailable -Name Microsoft.Graph.Beta.DeviceManagement
            $corporateManagementModule = Get-Module -ListAvailable -Name Microsoft.Graph.Beta.Devices.CorporateManagement

            if (-not $deviceManagementModule -or -not $corporateManagementModule) {
                #Try importing the modules and handle errors if they occur
                try {
                    $deviceManagementModule = Import-Module Microsoft.Graph.Beta.DeviceManagement -ErrorAction Stop
                    $corporateManagementModule = Import-Module Microsoft.Graph.Beta.Devices.CorporateManagement -ErrorAction Stop
                }
                catch {
                    Write-Host "Modules not found. Installing required modules..."
                    #Install the modules if import fails
                    Install-Module Microsoft.Graph.Beta.DeviceManagement -Force -AllowClobber
                    Install-Module Microsoft.Graph.Beta.Devices.CorporateManagement -Force -AllowClobber
                    Write-Host "Modules installed successfully."
                }
            }

            #Import the modules again to make them available in the current session
            Import-Module Microsoft.Graph.Beta.DeviceManagement
            Import-Module Microsoft.Graph.Beta.Devices.CorporateManagement

            Write-Host "Connect to Graph!"
            #Connect to Graph
            if ($AppId -and $AppSecret -and $tenant) {

                $graph = Connect-ToGraph -Tenant $Tenant -AppId $AppId -AppSecret $AppSecret
                write-output "Graph Connection Established"
            }
            else {
                ##Connect to Graph
            
                $graph = Connect-ToGraph -Scopes "DeviceManagementApps.Read.All, DeviceManagementConfiguration.Read.All"
            }
            Write-Host "Connected to tenant $($graph.TenantId)"

            # Get a list of apps
            Write-Host "Getting list of apps"
            $script:apps = Get-MgBetaDeviceAppManagementMobileApp -All

            # Get a list of policies (for certs)
            Write-Host "Getting list of policies"
            $script:policies = Get-MgBetaDeviceManagementConfigurationPolicy -All
        }


    
        # Process event log info
        ProcessEvents

        # Display the list of policies
        if ($ShowPolicies) {
            Write-Host " "
            Write-Host "POLICIES PROCESSED" -ForegroundColor Magenta   
            ProcessNodeCache | Format-Table -Wrap
        }
    
        # Make sure the tracking path exists
        if (Test-Path $path) {

            # Process device ESP sessions
            Write-Host " "
            Write-Host "DEVICE ESP:" -ForegroundColor Magenta
            Write-Host " "

            if (Test-Path "$path\ExpectedPolicies") {
                [array]$items = Get-ChildItem "$path\ExpectedPolicies"
                AddDisplay ([ref]$items)
                $items | ProcessPolicies
            }
            if (Test-Path "$path\ExpectedMSIAppPackages") {
                [array]$items = Get-ChildItem "$path\ExpectedMSIAppPackages"
                AddDisplay ([ref]$items)
                $items | ProcessApps -currentUser "S-0-0-00-0000000000-0000000000-000000000-000" 
            }
            if (Test-Path "$path\ExpectedModernAppPackages") {
                [array]$items = Get-ChildItem "$path\ExpectedModernAppPackages"
                AddDisplay ([ref]$items)
                $items | ProcessModernApps -currentUser "S-0-0-00-0000000000-0000000000-000000000-000"
            }
            if (Test-Path "$path\Sidecar") {
                [array]$items = Get-ChildItem "$path\Sidecar" | ? { $_.Property -match "./Device" -and $_.Name -notmatch "LastLoggedState" }
                AddDisplay ([ref]$items)
                $items | ProcessSidecar -currentUser "00000000-0000-0000-0000-000000000000"
            }
            if (Test-Path "$path\ExpectedSCEPCerts") {
                [array]$items = Get-ChildItem "$path\ExpectedSCEPCerts"
                AddDisplay ([ref]$items)
                $items | ProcessCerts
            }

            # Process user ESP sessions
            Get-ChildItem "$path" | ? { $_.PSChildName.StartsWith("S-") } | % {
                $userPath = $_.PSPath
                $userSid = $_.PSChildName
                Write-Host " "
                Write-Host "USER ESP for $($userSid):" -ForegroundColor Magenta
                Write-Host " "
                if (Test-Path "$userPath\ExpectedPolicies") {
                    [array]$items = Get-ChildItem "$userPath\ExpectedPolicies"
                    AddDisplay ([ref]$items)
                    $items | ProcessPolicies
                }
                if (Test-Path "$userPath\ExpectedMSIAppPackages") {
                    [array]$items = Get-ChildItem "$userPath\ExpectedMSIAppPackages" 
                    AddDisplay ([ref]$items)
                    $items | ProcessApps -currentUser $userSid
                }
                if (Test-Path "$userPath\ExpectedModernAppPackages") {
                    [array]$items = Get-ChildItem "$userPath\ExpectedModernAppPackages"
                    AddDisplay ([ref]$items)
                    $items | ProcessModernApps -currentUser $userSid
                }
                if (Test-Path "$userPath\Sidecar") {
                    [array]$items = Get-ChildItem "$path\Sidecar" | ? { $_.Property -match "./User" }
                    AddDisplay ([ref]$items)
                    $items | ProcessSidecar -currentUser $userSid
                }
                if (Test-Path "$userPath\ExpectedSCEPCerts") {
                    [array]$items = Get-ChildItem "$userPath\ExpectedSCEPCerts"
                    AddDisplay ([ref]$items)
                    $items | ProcessCerts
                }
            }
        }
        else {
            Write-Host "ESP diagnostics info does not (yet) exist."
        }


        # Display timeline
        Write-Host ""
        Write-Host "OBSERVED TIMELINE:" -ForegroundColor Magenta
        Write-Host ""

        # Get OSDCloud log files to use for measuring elapsed time, sorted by CreationTime
        $filesOSD = Get-ChildItem -Path "C:\OSDCloud\Logs" -Recurse -File | 
        Where-Object { $_.Name -like "*OSDCloud.log" -or $_.Name -like "SetupComplete.log" } | 
        Sort-Object CreationTimeUtc

        # Adjust times for DST in WinPE if the first file is SetupComplete.log
        if ($filesOSD[0].Name -eq "SetupComplete.log") {
            $filesOSD[1..$filesOSD.Count] | ForEach-Object {
                $_.CreationTimeUtc = $_.CreationTimeUtc.AddHours(-1)
                $_.LastWriteTimeUtc = $_.LastWriteTimeUtc.AddHours(-1)
            }
            $filesOSD = $filesOSD | Sort-Object CreationTimeUtc
        }

        # Create starting point in the timeline
        $script:observedTimeline += New-Object PSObject -Property @{
            "Date"     = $filesOSD[0].CreationTimeUtc
            "Detail"   = "Start Deployment"
            "Duration" = [TimeSpan]::Zero
        }

        # Process each log file and add to the timeline
        foreach ($file in $filesOSD) {
            $script:observedTimeline += New-Object PSObject -Property @{
                Date     = $file.LastWriteTimeUtc
                Detail   = "OSDCloud $($file.BaseName)"
                Duration = [TimeSpan]::Zero
                Status   = "Completed"
            }
        }

        # Convert dates to UTC and sort
        foreach ($item in $observedTimeline) {
            $item.Date = $item.Date.ToUniversalTime()
        }
        $observedTimeline = $observedTimeline | Sort-Object -Property Date

        # Calculate durations between events
        for ($i = 1; $i -lt $observedTimeline.Count; $i++) {
            if (-not $observedTimeline[$i].PSObject.Properties['Duration']) {
                $observedTimeline[$i] | Add-Member -MemberType NoteProperty -Name Duration -Value $null
            }
            $observedTimeline[$i].Duration = $observedTimeline[$i].Date - $observedTimeline[$i - 1].Date
        }

        # Calculate total elapsed time
        $totalTimeSpan = $observedTimeline[-1].Date - $observedTimeline[0].Date

        # Display the timeline
        $observedTimeline | Format-Table @{
            Label      = "Date"
            Expression = { $_.Date.ToUniversalTime().ToString("G") }
        }, @{
            Label      = "Duration"
            Expression = { $_.Duration.ToString("mm' minutes 'ss' seconds'") }
        }, @{
            Label      = "Status"
            Expression = { $_.Status }
        }, Detail

        Write-Host "Total Elapsed Time: $($totalTimeSpan.ToString("h' hours 'mm' minutes 'ss' seconds'"))"
    }

    End {

        # Remove the registry info if it exists
        if (Test-Path "HKCU:\ESPStatus.tmp") {
            Remove-Item -Path "HKCU:\ESPStatus.tmp" -Recurse -Force
        }
    }
}
