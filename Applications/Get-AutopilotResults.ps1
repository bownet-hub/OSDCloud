function Send-Email {
    param(
        [Parameter(Mandatory = $true)] [string] $ClientId,
        [Parameter(Mandatory = $true)] [string] $ClientSecret,
        [Parameter(Mandatory = $true)] [string] $TenantID,
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
            client_id     = $ClientId
            scope         = "https://graph.microsoft.com/.default"
            client_secret = $ClientSecret
            grant_type    = "client_credentials"
        }
        
        $response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method Post -ContentType "application/x-www-form-urlencoded" -Body $body
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
                        Name          = "attachment.txt"
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
        [Parameter(Mandatory = $true)] [string] $ClientId,
        [Parameter(Mandatory = $true)] [string] $ClientSecret,
        [Parameter(Mandatory = $true)] [string] $TenantID,
        [Parameter(Mandatory = $true)] [string] $ToRecipient,
        [Parameter(Mandatory = $true)] [string] $From
    )

    # Get log files to use for measuring elapsed time
    # Total time - app install directory
    $lastModifiedFile = Get-ChildItem -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs" -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    # Total time - OS deployment directory
    $firstCreatedFile = Get-ChildItem -Path "C:\OSDCloud\Logs" -Recurse -File | Sort-Object CreationTime | Select-Object -First 1

    # Per app time - app install directory
    # Exclude Intune logs
    # Sort by creation time
    $filesLog = Get-ChildItem -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs" -Recurse -File | 
    Where-Object { 
        ($_.Name -like "*.log" -or $_.Name -like "*.txt") -and 
        ($_.Name -notmatch "AgentExecutor.log|.*IntuneManagement.*|.*Autopilot.*|.*app.*|ClientCertCheck.log|.*health.*|Sensor.log")
    } | Sort-Object { $_.CreationTime.ToUniversalTime() }

    # Per app time - OS deployment directory
    # Sorted by creation time
    $filesOSD = Get-ChildItem -Path "C:\OSDCloud\Logs" -Recurse -File | 
    Where-Object { ($_.Name -like "*OSDCloud.log") -OR ( $_.Name -like "SetupComplete.log") } | Sort-Object { $_.CreationTime.ToUniversalTime() }

    # Initialize a variable to hold the total time span
    $totalTimeSpan = [TimeSpan]::Zero

    $LogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AutopilotLog.log"

    # Start logging
    Start-Transcript -Path "$LogPath" -Append
    $dtFormat = 'dd-MMM-yyyy HH:mm:ss'
    Write-Host "$(Get-Date -Format $dtFormat)"

    Write-Host '========================================================================='
    Write-Host "OS Deployment"
    Write-Host '========================================================================='
    foreach ($file in $filesOSD) {
        # Time between start and end of log file
        $timeSpan = New-TimeSpan -Start $file.CreationTime.ToUniversalTime() -End $file.LastWriteTime.ToUniversalTime()
        # Remove extension for cleaner look
        $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        Write-Host "$($timeSpan.ToString("mm' minutes 'ss' seconds'"))     $fileNameWithoutExtension "
    }

    Write-Host '========================================================================='
    Write-Host "Application Installation"
    Write-Host '========================================================================='
    foreach ($file in $filesLog) {
        # Time between start and end of log file
        $timeSpan = New-TimeSpan -Start $file.CreationTime.ToUniversalTime() -End $file.LastWriteTime.ToUniversalTime()
        if ($file.Name -eq "install.log") {
            # Display only the directory name as file names are the same
            Write-Host "$($timeSpan.ToString("mm' minutes 'ss' seconds'"))     $($file.Directory.Name) "
        }
        else {
            # Remove extension for cleaner look
            $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            Write-Host "$($timeSpan.ToString("mm' minutes 'ss' seconds'"))     $fileNameWithoutExtension "
        }
    }

    Write-Host '========================================================================='
    Write-Host "Total"
    Write-Host '========================================================================='
    # Time between first and last log file
    $totalTimeSpan = New-TimeSpan -Start $firstCreatedFile.CreationTime.ToUniversalTime() -End $lastModifiedFile.LastWriteTime.ToUniversalTime()
    Write-Host "Total Elapsed Time: $($totalTimeSpan.ToString("hh' hours 'mm' minutes 'ss' seconds'"))"

    Stop-Transcript

    Send-Email -ClientId $ClientId -ClientSecret $ClientSecret -TenantID $TenantId -ToRecipient $ToRecipient -From $From -attachmentPath $LogPath
}