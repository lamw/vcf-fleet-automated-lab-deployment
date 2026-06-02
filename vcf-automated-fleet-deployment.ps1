# Author: William Lam
# Website: https://williamlam.com

param (
    [string]$EnvConfigFile
)

# Validate that the file exists
if ($EnvConfigFile -and (Test-Path $EnvConfigFile)) {
    . $EnvConfigFile  # Dot-sourcing the config file
} else {
    Write-Host -ForegroundColor Red "`nNo valid deployment configuration file was provided or file was not found.`n"
    exit
}

#### DO NOT EDIT BEYOND HERE ####

# VCF Instance Deployment JSON
$random_string = -join ((48..57) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})

$VAppName = "Nested-${VCFInstallerProductSKU}-9-Lab-${VAppLabel}-${random_string}"
$VCFManagementDomainJSONFile = "$(${VCFInstallerProductSKU}.toLower())-mgmt-${random_string}.json"
$verboseLogFile = "vcf-9-lab-deployment-${random_string}.log"

$preCheck = 1
$confirmDeployment = 1
$deployVCFInstaller = 1
$updateVCFInstallerConfig = 1
$configureVCFInstallerConfig = 1
$deployNestedESXiVMsForMgmt = 1
$deployNestedESXiVMsForWLD = 0
$moveVMsIntovApp = 1
$generateMgmtJson = 1
$startVCFBringup = 1
$uploadVCFNotifyScript = 0

$srcNotificationScript = "vcf-bringup-notification.sh"
$dstNotificationScript = "/root/vcf-bringup-notification.sh"

$StartTime = Get-Date

Function My-Logger {
    param(
        [Parameter(Mandatory=$true)][String]$message,
        [Parameter(Mandatory=$false)][String]$color="green"
    )

    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"

    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor $color " $message"
    $logMessage = "[$timeStamp] $message"
    $logMessage | Out-File -Append -LiteralPath $verboseLogFile
}

Function Get-VCFInstallerToken {
    $payload = @{
        "username" = $VCFInstallerAdminUsername
        "password" = $VCFInstallerAdminPassword
    }

    $body = $payload | ConvertTo-Json

    try {
        $requests = Invoke-WebRequest -Uri "https://${VCFInstallerFQDN}/v1/tokens" -Method POST -SkipCertificateCheck -TimeoutSec 30 -Headers @{"Content-Type"="application/json";"Accept"="application/json"} -Body $body
        if($requests.StatusCode -eq 200) {
            $accessToken = ($requests.Content | ConvertFrom-Json).accessToken
        }
    } catch {
        My-Logger "Unable to retrieve VCF Installer Token ..."
        exit
    }

    $headers = @{
        "Content-Type"="application/json"
        "Accept"="application/json"
        "Authorization"="Bearer ${accessToken}"
    }

    return $headers
}

Function Download-VCFBundle {
    param(
        [Parameter(Mandatory=$true)][String]$BundleId
    )

    $headers = Get-VCFInstallerToken

    try {
        $payload = @{
            "bundleDownloadSpec" = @{
                "downloadNow" = $true
            }
        }

        $uri = "https://${VCFInstallerFQDN}/v1/bundles/$bundleId"
        $method = "PATCH"
        $body = $payload | ConvertTo-Json

        if($Debug) {
            My-Logger "DEBUG: Method: $method"
            My-Logger "DEBUG: Uri: $uri"
            My-Logger "DEBUG: Body: $body"
        }

        $requests = Invoke-WebRequest -Uri $uri -Method $method -SkipCertificateCheck -TimeoutSec 5 -Headers $headers -Body $body
    } catch {
        $error = ($_ | ConvertFrom-Json)
        if($error.errorCode -eq "BUNDLE_DOWNLOAD_ALREADY_DOWNLOADED") {
            continue
        } else {
            $_.Exception

            My-Logger "Failed to start VCF download for bundle ${bundleId}" "red"
            Write-Error "`n($_.Exception.Message)`n"
            break
        }
    }
}

Function Delete-VCFBundle {
    param(
        [Parameter(Mandatory=$true)][String]$BundleId
    )

    $headers = Get-VCFInstallerToken

    try {
        $uri = "https://${VCFInstallerFQDN}/v1/bundles/$bundleId"
        $method = "DELETE"
        $body = $null

        if($Debug) {
            My-Logger "DEBUG: Method: $method"
            My-Logger "DEBUG: Uri: $uri"
            My-Logger "DEBUG: Body: $body"
        }

        $requests = Invoke-WebRequest -Uri $uri -Method $method -SkipCertificateCheck -TimeoutSec 5 -Headers $headers
    } catch {
        My-Logger "Failed to delete VCF bundle ${bundleId}" "red"
        Write-Error "`n($_.Exception.Message)`n"
        break
    }
}

Function Verify-VCFAPIEndpoint {
    param(
        [Parameter(Mandatory=$true)][String]$EndpointIp
    )

    while(1) {
    try {
        $requests = Invoke-WebRequest -Uri "https://${EndpointIp}/vcf-installer-ui/login" -Method GET -SkipCertificateCheck -TimeoutSec 5
        if($requests.StatusCode -eq 200) {
            My-Logger "`tVCF Installer UI https://${EndpointIp}/vcf-installer-ui/login is now ready!"
            break
        }
    }
    catch {
        My-Logger "VCF Installer UI is not ready yet, sleeping for 120 seconds ..."
        Start-Sleep 120
    }
}
}

Function Connect-VCFDepot {
    param(
        [Parameter(Mandatory=$true)][String]$EndpointIp
    )

    $headers = Get-VCFInstallerToken

    try {
        if($VCFInstallerSoftwareDepot -eq "offline") {
            $payload = @{
                "depotConfiguration" = @{
                    "isOfflineDepot" = $true
                    "url" = $VCFInstallerDepotUrl
                }
            }
        } else {
            $payload = @{
                "vmwareAccount" = [Ordered]@{
                    "downloadToken" = $VCFInstallerDepotToken
                }
            }
        }

        $uri = "https://${EndpointIp}/v1/system/settings/depot"
        $method = "PUT"
        $body = $payload | ConvertTo-Json

        if($Debug) {
            My-Logger "DEBUG: Method: $method"
            My-Logger "DEBUG: Uri: $uri"
            My-Logger "DEBUG: Body: $body"
        }
	$requests = Invoke-WebRequest -Uri $uri -Method $method -SkipCertificateCheck -TimeoutSec 30 -Headers $headers -Body $body -ErrorAction Stop
    } catch {
	My-Logger "Failed to connect to VCF Software Depot" "red"
	$requests
        Write-Error "`n($_.Exception.Message)`n"
        break
    }

    if($requests.Statuscode -eq 202) {
        My-Logger "Successfully connected to VCF Software Depot ..."
    } else {
        My-Logger "Something went wrong updating connecting to VCF Software Depot" "yellow"
        $requests
        break
    }
}

Function Sync-VCFDepot {
    param(
        [Parameter(Mandatory=$true)][String]$EndpointIp
    )

    $headers = Get-VCFInstallerToken

    try {
        $uri = "https://${EndpointIp}/v1/system/settings/depot/depot-sync-info"
        $method = "PATCH"
        $body = $null

        if($Debug) {
            My-Logger "DEBUG: Method: $method"
            My-Logger "DEBUG: Uri: $uri"
            My-Logger "DEBUG: Body: $body"
        }

        $requests = Invoke-WebRequest -Uri $uri -Method $method -SkipCertificateCheck -TimeoutSec 5 -Headers $headers
    } catch {
        My-Logger "Failed to sync VCF Software Depot" "red"
        Write-Error "`n($_.Exception.Message)`n"
        break
    }

    if($requests.Statuscode -eq 202) {
        My-Logger "Successfully started VCF Software Depot sync ..."
    } else {
        My-Logger "Something went wrong starting VCF Software Depot sync" "yellow"
        $requests
        break
    }

    while(1) {
        try {
            $uri = "https://${EndpointIp}/v1/system/settings/depot/depot-sync-info"
            $method = "GET"
            $body = $null

            if($Debug) {
                My-Logger "DEBUG: Method: $method"
                My-Logger "DEBUG: Uri: $uri"
                My-Logger "DEBUG: Body: $body"
            }

            $requests = Invoke-WebRequest -Uri $uri -Method $method -SkipCertificateCheck -TimeoutSec 5 -Headers $headers
            if($requests.StatusCode -eq 200) {
                if(($requests.Content | ConvertFrom-Json).syncStatus -ne "SYNCED") {
                    My-Logger "VCF Software Depot Sync not ready yet, sleeping for 60 seconds ..."
                    Start-Sleep 60
                } else {
                    My-Logger "Successfully synced VCF Software Depot ..."
                    break
                }
            }
        }
        catch {
            My-Logger "Failed to sync VCF Software Depot ..."
            $requests
            exit
        }
    }
}

Function Download-VCFRelease {
    param(
        [Parameter(Mandatory=$true)][String]$EndpointIp
    )

    $headers = Get-VCFInstallerToken

    try {
        $uri = "https://${EndpointIp}/v1/releases/${VCFInstallerProductSKU}/release-components?releaseVersion=${VCFInstallerProductVersion}&automatedInstall=true&imageType=INSTALL"
        $method = "GET"
        $body = $null

        if($Debug) {
            My-Logger "DEBUG: Method: $method"
            My-Logger "DEBUG: Uri: $uri"
            My-Logger "DEBUG: Body: $body"
        }

        $requests = Invoke-WebRequest -Uri $uri -Method GET -SkipCertificateCheck -TimeoutSec 5 -Headers $headers
    } catch {
        My-Logger "Failed to retrieve $VCFInstallerProductSKU release" "red"
        Write-Error "`n($_.Exception.Message)`n"
        break
    }

    if($requests.Statuscode -eq 200) {
        My-Logger "Successfully retrieved $VCFInstallerProductSKU release ..."
    } else {
        My-Logger "Something went wrong retreiving $VCFInstallerProductSKU release" "yellow"
        $requests
        break
    }

    # Retreive the components for a given SKU
    $bundle = @{}
    $components = (($requests.Content | ConvertFrom-Json).elements | Where-Object {$_.releaseVersion -eq $VCFInstallerProductVersion}).components
    foreach ($component in $components) {
        $bundle[$component.name]=$component.versions.artifacts.bundles.id
    }

    # Download Bundle
    $bundle.GetEnumerator() | ForEach-Object {
        # SDDDCm is NOT required for VVF SKU
        if($VCFInstallerProductSKU -ne "VVF" -or $_.key -ne "SDDC_MANAGER") {
            My-Logger "Starting download for $($_.key) component ..."
            Download-VCFBundle -BundleId $_.value
        }
    }

    while(1) {
        try {
            $uri = "https://${EndpointIp}/v1/bundles/download-status?releaseVersion=${VCFInstallerProductVersion}&imageType=INSTALL"
            $method = "GET"
            $body = $null

            if($Debug) {
                My-Logger "DEBUG: Method: $method"
                My-Logger "DEBUG: Uri: $uri"
                My-Logger "DEBUG: Body: $body"
            }

            $requests = Invoke-WebRequest -Uri $uri -Method $method -SkipCertificateCheck -TimeoutSec 5 -Headers $headers
            if($requests.StatusCode -eq 200) {
                $downloadStatus = ($requests.Content | ConvertFrom-Json).elements.downloadStatus

                if($downloadStatus-contains "INPROGRESS" -or $downloadStatus -contains "SCHEDULED" -or $downloadStatus -contains "VALIDATING" -or $downloadStatus-contains "FAILED") {
                    if($downloadStatus -contains "FAILED") {
                        $failedBundles = (($requests.Content | ConvertFrom-Json).elements | Where-Object {$_.downloadStatus -eq "FAILED"})

                        foreach ($failedBundle in $failedBundles) {
                            My-Logger "Re-attempting to download $(${failedBundle}.componentType) component"
                            Delete-VCFBundle -BundleId $(${failedBundle}.bundleId)
                            Download-VCFBundle -BundleId $(${failedBundle}.bundleId)
                        }
                    }
                    My-Logger "$VCFInstallerProductSKU bundle download has not completed or has not been validated yet, sleeping for 5min ..."
                    Start-Sleep 300
                } else {
                    My-Logger "Successfully downloaded $VCFInstallerProductSKU ${VCFInstallerProductVersion} bundle ..."
                    break
                }
            }
        }
        catch {
            My-Logger "Failed to wait for $VCFInstallerProductSKU bundle download ..."
            $requests
            exit
        }
    }
}

if($preCheck -eq 1) {
    if($PSVersionTable.PSEdition -ne "Core") {
        Write-Host -ForegroundColor Red "`tPowerShell Core was not detected, please install that before continuing ... `n"
        exit
    }

    if(!(Test-Path $NestedESXiApplianceOVA)) {
        Write-Host -ForegroundColor Red "`nUnable to find $NestedESXiApplianceOVA ...`n"
        exit
    }

    if(!(Test-Path $VCFInstallerOVA)) {
        Write-Host -ForegroundColor Red "`nUnable to find $VCFInstallerOVA ...`n"
        exit
    }

    if($VCFInstallerSoftwareDepot -eq "offline") {
        $uri = [System.Uri]${VCFInstallerDepotUrl}
        $hostName = $uri.Host
        $port = if ($uri.Port -ne -1) { $uri.Port } else { 80 } # Default to 80 if no port in URL

        $socket = New-Object System.Net.Sockets.Socket([System.Net.Sockets.AddressFamily]::InterNetwork, [System.Net.Sockets.SocketType]::Stream, [System.Net.Sockets.ProtocolType]::Tcp)
        $connection = $socket.BeginConnect($hostName, $port, $null, $null)

        # Wait 2 seconds for a response
        $success = $connection.AsyncWaitHandle.WaitOne(2000, $true)

        if (-not $success) {
            Write-Host -ForegroundColor Red "`nUnable to reach endpoint ${hostName}:${port} (Timeout or Refused)`n"
            $socket.Close()
            exit
        } else {
            $socket.EndConnect($connection)
            $socket.Close()
            # Reachable! We don't care about Auth because we never sent an HTTP request.
        }
    }
}

if($confirmDeployment -eq 1) {
    Write-Host -ForegroundColor Magenta "`nPlease confirm the following configuration will be deployed:`n"

    Write-Host -ForegroundColor Yellow "---- VCF Automated 9.1 Lab Deployment Configuration ---- "
    Write-Host -NoNewline -ForegroundColor Green "Generated Deployment ID: "
    Write-Host -ForegroundColor White $random_string
    Write-Host -NoNewline -ForegroundColor Green "Configuration Variables File: "
    Write-Host -ForegroundColor White $EnvConfigFile
    Write-Host -NoNewline -ForegroundColor Green "Nested ESXi Image Path: "
    Write-Host -ForegroundColor White $NestedESXiApplianceOVA
    Write-Host -NoNewline -ForegroundColor Green "VCF Installer Image Path: "
    Write-Host -ForegroundColor White $VCFInstallerOVA

    Write-Host -ForegroundColor Yellow "`n---- vCenter Server Deployment Target Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "vCenter Server Address: "
    Write-Host -ForegroundColor White $VIServer
    Write-Host -NoNewline -ForegroundColor Green "VM Network: "
    Write-Host -ForegroundColor White $VMNetwork

    Write-Host -NoNewline -ForegroundColor Green "VM Storage: "
    Write-Host -ForegroundColor White $VMDatastore
    Write-Host -NoNewline -ForegroundColor Green "VM Cluster: "
    Write-Host -ForegroundColor White $VMCluster
    Write-Host -NoNewline -ForegroundColor Green "VM vApp: "
    Write-Host -ForegroundColor White $VAppName

    Write-Host -ForegroundColor Yellow "`n---- VCF Installer Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "Software SKU: "
    Write-Host -ForegroundColor White $VCFInstallerProductSKU
    Write-Host -NoNewline -ForegroundColor Green "Software Version: "
    Write-Host -ForegroundColor White $VCFInstallerProductVersion
    Write-Host -NoNewline -ForegroundColor Green "Hostname: "
    Write-Host -ForegroundColor White $VCFInstallerVMName
    Write-Host -NoNewline -ForegroundColor Green "IP Address: "
    Write-Host -ForegroundColor White $VCFInstallerIP

    if($deployNestedESXiVMsForMgmt -eq 1) {
        Write-Host -ForegroundColor Yellow "`n---- vESXi Configuration for $VCFInstallerProductSKU Management Domain ----"
        Write-Host -NoNewline -ForegroundColor Green "# of Nested ESXi VMs: "
        Write-Host -ForegroundColor White $NestedESXiHostnameToIPsForManagementDomain.count
        Write-Host -NoNewline -ForegroundColor Green "IP Address(s): "
        Write-Host -ForegroundColor White $NestedESXiHostnameToIPsForManagementDomain.Values
        Write-Host -NoNewline -ForegroundColor Green "vCPU: "
        Write-Host -ForegroundColor White $NestedESXiMGMTvCPU
        Write-Host -NoNewline -ForegroundColor Green "vMEM: "
        Write-Host -ForegroundColor White "$NestedESXiMGMTvMEM GB"
        Write-Host -NoNewline -ForegroundColor Green "Caching VMDK: "
        Write-Host -ForegroundColor White "$NestedESXiMGMTCachingvDisk GB"
        Write-Host -NoNewline -ForegroundColor Green "Capacity VMDK: "
        Write-Host -ForegroundColor White "$NestedESXiMGMTCapacityvDisk GB"
    }

    if($deployNestedESXiVMsForWLD -eq 1) {
        Write-Host -ForegroundColor Yellow "`n---- vESXi Configuration for $VCFInstallerProductSKU Workload Domain ----"
        Write-Host -NoNewline -ForegroundColor Green "# of Nested ESXi VMs: "
        Write-Host -ForegroundColor White $NestedESXiHostnameToIPsForWorkloadDomain.count
        Write-Host -NoNewline -ForegroundColor Green "IP Address(s): "
        Write-Host -ForegroundColor White $NestedESXiHostnameToIPsForWorkloadDomain.Values
        Write-Host -NoNewline -ForegroundColor Green "vCPU: "
        Write-Host -ForegroundColor White $NestedESXiWLDvCPU
        Write-Host -NoNewline -ForegroundColor Green "vMEM: "
        Write-Host -ForegroundColor White "$NestedESXiWLDvMEM GB"
        Write-Host -NoNewline -ForegroundColor Green "Caching VMDK: "
        Write-Host -ForegroundColor White "$NestedESXiWLDCachingvDisk GB"
        Write-Host -NoNewline -ForegroundColor Green "Capacity VMDK: "
        Write-Host -ForegroundColor White "$NestedESXiWLDCapacityvDisk GB"
    }

    Write-Host -NoNewline -ForegroundColor Green "`nNetmask "
    Write-Host -ForegroundColor White $VMNetmask
    Write-Host -NoNewline -ForegroundColor Green "Gateway: "
    Write-Host -ForegroundColor White $VMGateway
    Write-Host -NoNewline -ForegroundColor Green "DNS: "
    Write-Host -ForegroundColor White $VMDNS
    Write-Host -NoNewline -ForegroundColor Green "NTP: "
    Write-Host -ForegroundColor White $VMNTP
    Write-Host -NoNewline -ForegroundColor Green "Syslog: "
    Write-Host -ForegroundColor White $VMSyslog

    Write-Host -ForegroundColor Magenta "`nWould you like to proceed with this deployment?`n"
    $answer = Read-Host -Prompt "Do you accept (Y or N)"
    if($answer -ne "Y" -and $answer -ne "y") {
        exit
    }
    Clear-Host
}

if($deployNestedESXiVMsForMgmt -eq 1 -or $deployNestedESXiVMsForWLD -eq 1 -or $updateVCFInstallerConfig -eq 1 -or $deployVCFInstaller -eq 1 -or $moveVMsIntovApp -eq 1) {
    My-Logger "Connecting to Management vCenter Server $VIServer ..."
    $viConnection = Connect-VIServer $VIServer -User $VIUsername -Password $VIPassword -WarningAction SilentlyContinue

    $datastore = Get-Datastore -Server $viConnection -Name $VMDatastore | Select-Object -First 1
    $cluster = Get-Cluster -Server $viConnection -Name $VMCluster
    $vmhost = $cluster | Get-VMHost | Get-Random -Count 1
}

if($deployVCFInstaller -eq 1) {
    $ovfconfig = Get-OvfConfiguration $VCFInstallerOVA

    $networkMapLabel = ($ovfconfig.ToHashTable().keys | Where-Object {$_ -Match "NetworkMapping"}).replace("NetworkMapping.","").replace("-","_").replace(" ","_")
    $ovfconfig.NetworkMapping.$networkMapLabel.value = $VMNetwork
    $ovfconfig.Common.vami.hostname.value = $VCFInstallerFQDN
    $ovfconfig.vami.SDDC_Manager.ip0.value = $VCFInstallerIP
    $ovfconfig.vami.SDDC_Manager.netmask0.value = $VMNetmask
    $ovfconfig.vami.SDDC_Manager.gateway.value = $VMGateway
    $ovfconfig.vami.SDDC_Manager.DNS.value = $VMDNS
    $ovfconfig.vami.SDDC_Manager.domain.value = $VMDomain
    $ovfconfig.vami.SDDC_Manager.searchpath.value = $VMDomain
    $ovfconfig.common.guestinfo.ntp.value = $VMNTP
    $ovfconfig.Common.LOCAL_USER_PASSWORD.value = $VCFInstallerAdminPassword
    $ovfconfig.Common.ROOT_PASSWORD.value = $VCFInstallerRootPassword

    My-Logger "Deploying VCF Installer VM $VCFInstallerVMName ..."
    try {
        $vm = Import-VApp -Server $viConnection -Source $VCFInstallerOVA -OvfConfiguration $ovfconfig -Name $VCFInstallerVMName -Location $VMCluster -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin | Out-Null
        $vm = Get-VM -Server $viConnection -Name $VCFInstallerVMName
    } catch {
        My-Logger "Failed to deploy $VCFInstallerVMName ..."
        Disconnect-VIServer -Server $viConnection -Confirm:$false
        exit
    }

    My-Logger "Powering On $VCFInstallerVMName ..."
    $vm | Start-Vm -RunAsync | Out-Null
}

if($updateVCFInstallerConfig -eq 1) {
    My-Logger "Waiting for VCF Installer UI to be ready ..."
    while(1) {
        try {
            $requests = Invoke-WebRequest -Uri "https://${VCFInstallerFQDN}/vcf-installer-ui/login" -Method GET -SkipCertificateCheck -TimeoutSec 5
            if($requests.StatusCode -eq 200) {
                My-Logger "`tVCF Installer UI https://${VCFInstallerFQDN}/vcf-installer-ui/login is now ready!"
                break
            }
        }
        catch {
            My-Logger "VCF Installer UI is not ready yet, sleeping for 120 seconds ..."
            Start-Sleep 120
        }
    }

    $vcfVM = Get-VM -Server $viConnection $vcfInstallerVMName

    $scriptName = "vcfIntScript.sh"
    $script = @"
#!/bin/bash
# Generated by William Lam's VCF 9.1 Automated Deployment Lab Script


"@

    if($VCFDomainManagerProperties -ne $null) {
        $vcfDomainConfigFile = "/etc/vmware/vcf/domainmanager/application.properties"
        $VCFDomainManagerProperties.GetEnumerator() | Foreach-Object {
            $script += "echo $($_.key)=$($_.value) >> ${vcfDomainConfigFile}`n"
        }
    }

    if($VCFFeatureProperties -ne $null) {
        $vcfFeatureConfigFile = "/home/vcf/feature.properties"
        $VCFFeatureProperties.GetEnumerator() | Foreach-Object {
            $script += "echo $($_.key)=$($_.value) >> ${vcfFeatureConfigFile}`n"
        }
        $script += "chmod 755 ${vcfFeatureConfigFile}`n"
    }

    $script += "echo 'y' | /opt/vmware/vcf/operationsmanager/scripts/cli/sddcmanager_restart_services.sh"
    $script | Out-File $scriptName

    My-Logger "Transfering configuration shell script ($scriptName) to VCF Installer VM ..."
    Copy-VMGuestFile -Server $viConnection -VM $vcfVM -GuestUser "root" -GuestPassword $VCFInstallerRootPassword -LocalToGuest -Source ${scriptName} -Destination /tmp/${scriptName} -Force | Out-Null
    My-Logger "Running configuration shell script on VCF Installer VM ..."
    Invoke-VMScript -ScriptText "bash /tmp/${scriptName}" -VM $vcfVM -GuestUser "root" -GuestPassword $VCFInstallerRootPassword  | Out-Null

    Start-Sleep -Seconds 120
}

if($deployNestedESXiVMsForMgmt -eq 1) {
    $NestedESXiHostnameToIPsForManagementDomain.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
        $VMName = $_.Key
        $VMIPAddress = $_.Value

        $ovfconfig = Get-OvfConfiguration $NestedESXiApplianceOVA
        $networkMapLabel = ($ovfconfig.ToHashTable().keys | Where-Object {$_ -Match "NetworkMapping"}).replace("NetworkMapping.","").replace("-","_").replace(" ","_")
        $ovfconfig.NetworkMapping.$networkMapLabel.value = $VMNetwork
        $ovfconfig.common.guestinfo.hostname.value = "${VMName}.${VMDomain}"
        $ovfconfig.common.guestinfo.ipaddress.value = $VMIPAddress
        $ovfconfig.common.guestinfo.netmask.value = $VMNetmask
        $ovfconfig.common.guestinfo.gateway.value = $VMGateway
        $ovfconfig.common.guestinfo.dns.value = $VMDNS
        $ovfconfig.common.guestinfo.domain.value = $VMDomain
        $ovfconfig.common.guestinfo.ntp.value = $VMNTP
        $ovfconfig.common.guestinfo.syslog.value = $VMSyslog
        $ovfconfig.common.guestinfo.password.value = $VMPassword
        $ovfconfig.common.guestinfo.ssh.value = $true

        My-Logger "Deploying Nested ESXi VM $VMName ..."
        try {
            Import-VApp -Server $viConnection -Source $NestedESXiApplianceOVA -OvfConfiguration $ovfconfig -Name $VMName -Location $VMCluster -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin  | Out-Null
            $vm = Get-VM -Server $viConnection -Name $VMName
        } catch {
            My-Logger "Failed to deploy $VMName ..."
            Disconnect-VIServer -Server $viConnection -Confirm:$false
            exit
        }

        My-Logger "Updating Virtual Hardware compute for Nested ESXi VMs (vCPU=${NestedESXiMGMTvCPU} vMEM=${NestedESXiMGMTvMEM}GB) ..."
        Set-VM -Server $viConnection -VM $vm -NumCpu $NestedESXiMGMTvCPU -CoresPerSocket $NestedESXiMGMTvCPU -MemoryGB $NestedESXiMGMTvMEM -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Updating Virtual Hardware storage for Nested ESXi VMs (Boot Disk=${NestedESXiMGMTBootDisk}GB vSAN Cache=${NestedESXiMGMTCachingvDisk}GB vSAN Capacity=${NestedESXiMGMTCapacityvDisk}GB) ..."
        Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 1" | Set-HardDisk -CapacityGB $NestedESXiMGMTBootDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 2" | Set-HardDisk -CapacityGB $NestedESXiMGMTCachingvDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 3" | Set-HardDisk -CapacityGB $NestedESXiMGMTCapacityvDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Updating Virtual Hardware networking for Nested ESXi VMs (Adding vmnic2/vmnic3) ..."
        $vmPortGroup = Get-VirtualNetwork -Name $VMNetwork -Location ($cluster | Get-Datacenter)
        if($vmPortGroup.NetworkType -eq "Distributed") {
            $vmPortGroup = Get-VDPortgroup -Name $VMNetwork
            New-NetworkAdapter -VM $vm -Type Vmxnet3 -Portgroup $vmPortGroup -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
            New-NetworkAdapter -VM $vm -Type Vmxnet3 -Portgroup $vmPortGroup -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        } else {
            New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $vmPortGroup -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
            New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $vmPortGroup -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }

        $vm | New-AdvancedSetting -name "ethernet2.filter4.name" -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet2.filter4.onFailure" -value "failOpen" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        $vm | New-AdvancedSetting -name "ethernet3.filter4.name" -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet3.filter4.onFailure" -value "failOpen" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Powering On $vmname ..."
        $vm | Start-Vm -RunAsync | Out-Null
    }
}

if($deployNestedESXiVMsForWLD -eq 1) {
    $NestedESXiHostnameToIPsForWorkloadDomain.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
        $VMName = $_.Key
        $VMIPAddress = $_.Value

        $ovfconfig = Get-OvfConfiguration $NestedESXiApplianceOVA
        $networkMapLabel = ($ovfconfig.ToHashTable().keys | Where-Object {$_ -Match "NetworkMapping"}).replace("NetworkMapping.","").replace("-","_").replace(" ","_")
        $ovfconfig.NetworkMapping.$networkMapLabel.value = $VMNetwork
        $ovfconfig.common.guestinfo.hostname.value = "${VMName}.${VMDomain}"
        $ovfconfig.common.guestinfo.ipaddress.value = $VMIPAddress
        $ovfconfig.common.guestinfo.netmask.value = $VMNetmask
        $ovfconfig.common.guestinfo.gateway.value = $VMGateway
        $ovfconfig.common.guestinfo.dns.value = $VMDNS
        $ovfconfig.common.guestinfo.domain.value = $VMDomain
        $ovfconfig.common.guestinfo.ntp.value = $VMNTP
        $ovfconfig.common.guestinfo.syslog.value = $VMSyslog
        $ovfconfig.common.guestinfo.password.value = $VMPassword
        $ovfconfig.common.guestinfo.ssh.value = $true

        My-Logger "Deploying Nested ESXi VM $VMName ..."
        try {
            Import-VApp -Server $viConnection -Source $NestedESXiApplianceOVA -OvfConfiguration $ovfconfig -Name $VMName -Location $VMCluster -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin | Out-Null
            $vm = Get-VM -Server $viConnection -Name $VMName
        } catch {
            My-Logger "Failed to deploy $VMName ..."
            Disconnect-VIServer -Server $viConnection -Confirm:$false
            exit
        }

        My-Logger "Updating Virtual Hardware compute for Nested ESXi VMs (vCPU=${NestedESXiWLDvCPU} vMEM=${NestedESXiWLDvMEM}GB) ..."
        Set-VM -Server $viConnection -VM $vm -NumCpu $NestedESXiWLDvCPU -CoresPerSocket $NestedESXiWLDvCPU -MemoryGB $NestedESXiWLDvMEM -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Updating Virtual Hardware storage for Nested ESXi VMs (Boot Disk=${NestedESXiWLDBootDisk}GB vSAN Cache=${NestedESXiWLDCachingvDisk}GB vSAN Capacity=${NestedESXiWLDCapacityvDisk}GB) ..."
        Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 1" | Set-HardDisk -CapacityGB $NestedESXiWLDBootDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 2" | Set-HardDisk -CapacityGB $NestedESXiWLDCachingvDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 3" | Set-HardDisk -CapacityGB $NestedESXiWLDCapacityvDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Updating Virtual Hardware networking for Nested ESXi VMs (Adding vmnic2/vmnic3) ..."
        $vmPortGroup = Get-VirtualNetwork -Name $VMNetwork -Location ($cluster | Get-Datacenter)
        if($vmPortGroup.NetworkType -eq "Distributed") {
            $vmPortGroup = Get-VDPortgroup -Name $VMNetwork
            New-NetworkAdapter -VM $vm -Type Vmxnet3 -Portgroup $vmPortGroup -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
            New-NetworkAdapter -VM $vm -Type Vmxnet3 -Portgroup $vmPortGroup -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        } else {
            New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $vmPortGroup -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
            New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $vmPortGroup -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }

        $vm | New-AdvancedSetting -name "ethernet2.filter4.name" -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet2.filter4.onFailure" -value "failOpen" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        $vm | New-AdvancedSetting -name "ethernet3.filter4.name" -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet3.filter4.onFailure" -value "failOpen" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Powering On $vmname ..."
        $vm | Start-Vm -RunAsync | Out-Null
    }
}

if($moveVMsIntovApp -eq 1) {
    # Check whether DRS is enabled as that is required to create vApp
    if((Get-Cluster -Server $viConnection $cluster).DrsEnabled) {
        My-Logger "Creating vApp $VAppName ..."
        $rp = Get-ResourcePool -Name Resources -Location $cluster
        $VApp = New-VApp -Name $VAppName -Server $viConnection -Location $cluster

        if(-Not (Get-Folder $VMFolder -ErrorAction Ignore)) {
            My-Logger "Creating VM Folder $VMFolder ..."
            $folder = New-Folder -Name $VMFolder -Server $viConnection -Location (Get-Datacenter $VMDatacenter | Get-Folder vm)
        }

        if($deployNestedESXiVMsForMgmt -eq 1) {
            My-Logger "Moving Nested Managenment ESXi VMs into $VAppName vApp ..."
            $NestedESXiHostnameToIPsForManagementDomain.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
                $vm = Get-VM -Name $_.Key -Server $viConnection -Location $cluster | Where-Object{$_.ResourcePool.Id -eq $rp.Id}
                Move-VM -VM $vm -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
            }
        }

        if($deployNestedESXiVMsForWLD -eq 1) {
            My-Logger "Moving Nested Workload ESXi VMs into $VAppName vApp ..."
            $NestedESXiHostnameToIPsForWorkloadDomain.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
                $vm = Get-VM -Name $_.Key -Server $viConnection -Location $cluster | Where-Object{$_.ResourcePool.Id -eq $rp.Id}
                Move-VM -VM $vm -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
            }
        }

        if($deployVCFInstaller -eq 1) {
            $vcfInstallerVM = Get-VM -Name $VCFInstallerVMName -Server $viConnection -Location $cluster | Where-Object{$_.ResourcePool.Id -eq $rp.Id}
            My-Logger "Moving $VCFInstallerVMName into $VAppName vApp ..."
            Move-VM -VM $vcfInstallerVM -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }

        My-Logger "Moving $VAppName to VM Folder $VMFolder ..."
        Move-VApp -Server $viConnection $VAppName -Destination (Get-Folder -Server $viConnection $VMFolder) | Out-File -Append -LiteralPath $verboseLogFile
    } else {
        My-Logger "vApp $VAppName will NOT be created as DRS is NOT enabled on vSphere Cluster ${cluster} ..."
    }
}

if($generateMgmtJson -eq 1) {
    $esxivMotionNetwork = $NestedESXivMotionNetworkCidr.split("/")[0]
    $esxivMotionNetworkOctects = $esxivMotionNetwork.split(".")
    $esxivMotionGateway = ($esxivMotionNetworkOctects[0..2] -join '.') + ".1"
    $esxivMotionStart = ($esxivMotionNetworkOctects[0..2] -join '.') + ".101"
    $esxivMotionEnd = ($esxivMotionNetworkOctects[0..2] -join '.') + ".118"

    $esxivSANNetwork = $NestedESXivSANNetworkCidr.split("/")[0]
    $esxivSANNetworkOctects = $esxivSANNetwork.split(".")
    $esxivSANGateway = ($esxivSANNetworkOctects[0..2] -join '.') + ".1"
    $esxivSANStart = ($esxivSANNetworkOctects[0..2] -join '.') + ".101"
    $esxivSANEnd = ($esxivSANNetworkOctects[0..2] -join '.') + ".118"

    $esxiNSXTepNetwork = $NestedESXiNSXTepNetworkCidr.split("/")[0]
    $esxiNSXTepNetworkOctects = $esxiNSXTepNetwork.split(".")
    $esxiNSXTepGateway = ($esxiNSXTepNetworkOctects[0..2] -join '.') + ".1"
    $esxiNSXTepStart = ($esxiNSXTepNetworkOctects[0..2] -join '.') + ".101"
    $esxiNSXTepEnd = ($esxiNSXTepNetworkOctects[0..2] -join '.') + ".118"

    $hostSpecs = @()
    $count = 1
    $NestedESXiHostnameToIPsForManagementDomain.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
        $VMName = "$VMName = "$($_.Key)." + $VMDomain"

        $hostSpec = [ordered]@{
            "hostname" = $VMName
            "credentials" = [ordered]@{
                "username" = "root"
                "password" = $VMPassword
            }
        }
        $hostSpecs+=$hostSpec
        $count++
    }

    $vcfConfig = [ordered]@{
        "sddcId" = $DeploymentId
        "vcfInstanceName" = $DeploymentInstanceName
        "workflowType" = $VCFInstallerProductSKU
        "version" = $VCFInstallerProductVersion
        "ceipEnabled" = $CEIPEnabled
        "fipsEnabled" = $true
        "skipEsxThumbprintValidation" = $true
        "skipGatewayPingValidation" = $true
    }

    if($VCFInstallerProductSKU -eq "VCF"){
        $sddcmSpec = [ordered]@{
            "rootUserCredentials" = [ordered]@{
                "username" = "root"
                "password" = $SddcManagerRootPassword
            }
            "secondUserCredentials" = [ordered]@{
                "username" = "vcf"
                "password" = $SddcManagerVcfPassword
            }
            "hostname" = $SddcManagerHostname
            "useExistingDeployment" = $false
            "rootPassword" = $SddcManagerRootPassword
            "sshPassword" = $SddcManagerSSHPassword
            "localUserPassword" = $SddcManagerLocalPassword
        }
        $vcfConfig.Add("sddcManagerSpec",$sddcmSpec)
    }

        $dnsSpec = [ordered]@{
            "nameservers" = @($VMDNS)
            "subdomain" = $VMDomain
        }
        $ntpSpec = @($VMNTP)
        $vcSpec = [ordered]@{
            "vcenterHostname" = $VCSAName
            "rootVcenterPassword" = $VCSARootPassword
            "vmSize" = $VCSASize
            "storageSize" = "lstorage"
            "adminUserSsoPassword" = $VCSASSOPassword
            "ssoDomain" = "vsphere.local"
            "useExistingDeployment" = $false
        }
        $hostSpec = $hostSpecs
        $clusterSpec = [ordered]@{
            "clusterName" = $VCSAClusterName
            "datacenterName" = $VCSADatacenterName
        }
        $dsSpec = [ordered]@{
            "vsanSpec" = [ordered] @{
                "failuresToTolerate" = $VSANFTT
                "vsanDedup" = $VSANDedupe
                "esaConfig" = @{
                    "enabled" = $VSANESAEnabled
                }
                "datastoreName" = $VSANDatastoreName
            }
        }
        $vcfConfig.Add("dnsSpec",$dnsSpec)
        $vcfConfig.Add("ntpServers",$ntpSpec)
        $vcfConfig.Add("vcenterSpec",$vcSpec)
        $vcfConfig.Add("hostSpecs",$hostSpec)
        $vcfConfig.Add("clusterSpec",$clusterSpec)
        $vcfConfig.Add("datastoreSpec",$dsSpec)

    if($VCFInstallerProductSKU -eq "VCF"){
        $nsxSpec = [ordered]@{
            "nsxtManagerSize" = $NSXManagerSize
            "nsxtManagers" = @(
                @{"hostname" = $NSXManagerNodeHostname}
            )
            "vipFqdn" = $NSXManagerVIPHostname
            "useExistingDeployment" = $false
            "nsxtAdminPassword" = $NSXAdminPassword
            "nsxtAuditPassword" = $NSXAuditPassword
            "rootNsxtManagerPassword" = $NSXRootPassword
            "skipNsxOverlayOverManagementNetwork" = $true
            "ipAddressPoolSpec" = [ordered]@{
                "name" = "tep01"
                "description" = "ESXi Host Overlay TEP IP Pool"
                "subnets" = @(
                    @{
                        "cidr" = $NestedESXiNSXTepNetworkCidr
                        "gateway" = $esxiNSXTepGateway
                        "ipAddressPoolRanges" = @(@{"start" = $esxiNSXTepStart;"end" = $esxiNSXTepEnd})
                    }
                )
            }
            "transportVlanId" = "2005"
        }

        $vcfConfig.Add("nsxtSpec",$nsxSpec)
    }

        $opsSpec = [ordered]@{
            "nodes" = @(
                @{
                    "hostname" = $VCFOperationsHostname
                    "rootUserPassword" = $VCFOperationsRootPassword
                    "type" = "master"
                }
            )
            "adminUserPassword" = $VCFOperationsAdminPassword
            "applianceSize" = $VCFOperationsSize
            "useExistingDeployment" = $false
            "loadBalancerFqdn" = ""
        }
        $vcfConfig.Add("vcfOperationsSpec",$opsSpec)

        $vspClusterSpec = [ordered]@{
            "platformFqdn" = $VCFManagementServicesRuntimeHostname
            "instanceFqdn" = $VCFManagementServicesInstanceHostname
            "fleetFqdn" = $VCFManagementServicesFleetHostname
            "systemUserPassword" = $VCFManagementServicesSystemPassword
            "size" = $VCFManagementServicesSize
            "internalClusterCidrIpv4" = $VCFManagementServicesInternalClusterCidrIpv4
            "ipv4Pool" = @{
                "ipRange" = @{
                    "startIpAddress" = $VCFManagementServicesIPStartRange
                    "endIpAddress" = $VCFManagementServicesIPEndRange
                }
            }
        }
        $sddcLcmSpec = [ordered]@{
            "hostname" = $VCFManagementServicesInstanceHostname
        }
        $fleetLcmSpec = [ordered]@{
            "hostname" = $VCFManagementServicesFleetHostname
        }
        $licenseServerSpec = [ordered]@{
            "hostname" = $VCFLicenseServerHostname
        }

    if($VCFInstallerProductSKU -eq "VCF") {
        $vidbSpec = [ordered]@{
            "hostname" = $VCFManagementServicesIdentityHostname
        }
        $vcfOperationsLogsSpec = [ordered]@{
            "hostname" = $VCFManagementLogsHostname
            "password" = $VCFManagementLogsPassword
        }
        $opsCollectorSpec = [ordered]@{
            "hostname" = $VCFOperationsCollectorHostname
            "applicationSize" = $VCFOperationsCollectorSize
            "rootUserPassword" = $VCFOperationsCollectorRootPassword
            "useExistingDeployment" = $false
        }
        $autoSpec = [ordered]@{
            "platformFqdn" = $VCFAutomationServicesRuntimeHostname
            "hostname" = $VCFAutomationHostname
            "adminUserPassword" = $VCFAutomationAdminPassword
            "ipPool" = $VCFAutomationIPPool
            "nodePrefix" = $VCFAutomationNodePrefix
            "internalClusterCidr" = $VCFAutomationClusterCIDR
            "useExistingDeployment" = $false
            "size" = $VCFAutomationSize
        }
    }
        $netSpec = @(
            [ordered]@{
                "networkType" = "MANAGEMENT"
                "subnet" = $NestedESXiManagementNetworkCidr
                "gateway" = $VMGateway
                "subnetMask" = $null
                "includeIpAddress" = $null
                "includeIpAddressRanges" = $null
                "vlanId" = "0"
                "mtu" = "1500"
                "teamingPolicy" = "loadbalance_loadbased"
                "activeUplinks" = @("uplink1","uplink2")
                "standbyUplinks" = @()
                "portGroupKey" = "DVPG_FOR_MANAGEMENT"
            }
            [ordered]@{
                "networkType" = "VM_MANAGEMENT"
                "subnet" = $NestedESXiManagementNetworkCidr
                "gateway" = $VMGateway
                "subnetMask" = $null
                "includeIpAddress" = $null
                "includeIpAddressRanges" = $null
                "vlanId" = "0"
                "mtu" = "1500"
                "teamingPolicy" = "loadbalance_loadbased"
                "activeUplinks" = @("uplink1","uplink2")
                "standbyUplinks" = @()
                "portGroupKey" = "DVPG_FOR_VM_MANAGEMENT"
            }
            [ordered]@{
                "networkType" = "VMOTION"
                "subnet" = $NestedESXivMotionNetworkCidr
                "gateway" = $esxivMotionGateway
                "subnetMask" = $null
                "includeIpAddress" = $null
                "includeIpAddressRanges" = @(@{"startIpAddress" = $esxivMotionStart;"endIpAddress" = $esxivMotionEnd})
                "vlanId" = "0"
                "mtu" = "8940"
                "teamingPolicy" = "loadbalance_loadbased"
                "activeUplinks" = @("uplink1","uplink2")
                "standbyUplinks" = @()
                "portGroupKey" = "DVPG_FOR_VMOTION"
            }
            [ordered]@{
                "networkType" = "VSAN"
                "subnet" = $NestedESXivSANNetworkCidr
                "gateway"= $esxivSANGateway
                "subnetMask" = $null
                "includeIpAddress" = $null
                "teamingPolicy" = "loadbalance_loadbased"
                "includeIpAddressRanges" = @(@{"startIpAddress" = $esxivSANStart;"endIpAddress" = $esxivSANEnd})
                "vlanId" = "0"
                "mtu" = "8940"
                "activeUplinks" = @("uplink1","uplink2")
                "standbyUplinks" = @()
                "portGroupKey" = "DVPG_FOR_VSAN"
            }
        )
        $vdsSpec = @(
            [ordered]@{
                "dvsName" = "sddc1-cl01-vds01"
                "networks" = @(
                    "MANAGEMENT",
                    "VM_MANAGEMENT",
                    "VMOTION",
                    "VSAN"
                )
                "mtu" = "8940"
                "nsxtSwitchConfig" = [ordered]@{
                    "transportZones" = @(
                        @{
                            "transportType" = "OVERLAY"
                            "name" = "VCF-Created-Overlay-Zone"
                        }
                    )
                    "hostSwitchOperationalMode" = "ENS"
                }
                "vmnicsToUplinks" = @(
                    @{
                        "id" = "vmnic0"
                        "uplink" = "uplink1"
                    }
                    @{
                        "id" = "vmnic1"
                        "uplink" = "uplink2"
                    }
                )
                "nsxTeamings" = @(
                    @{
                        "policy" = "LOADBALANCE_SRCID"
                        "activeUplinks" = @("uplink1","uplink2")
                        "standByUplinks" = @()
                    }
                )
                "lagSpecs" = $null
                "vmnics" = @("vmnic0","vmnic1")
            }
        )

    if($VCFInstallerProductSKU -eq "VCF") {
        $vcfConfig.Add("vcfOperationsCollectorSpec",$opsCollectorSpec)
        $vcfConfig.Add("vcfAutomationSpec",$autoSpec)
        $vcfConfig.Add("saltSpec",@{})
        $vcfConfig.Add("vidbSpec",$vidbSpec)
        $vcfConfig.Add("vcfOperationsLogsSpec",$vcfOperationsLogsSpec)
        $vcfConfig.Add("saltRaasSpec",@{})
    }

    $vcfConfig.Add("vspClusterSpec",$vspClusterSpec)
    $vcfConfig.Add("telemetryAcceptorSpec",@{})
    $vcfConfig.Add("licenseServerSpec",$licenseServerSpec)
    $vcfConfig.Add("sddcLcmSpec",$sddcLcmSpec)
    $vcfConfig.Add("fleetLcmSpec",$fleetLcmSpec)
    $vcfConfig.Add("fleetDepotSpec",@{})
    $vcfConfig.Add("networkSpecs",$netSpec)
    $vcfConfig.Add("dvsSpecs",$vdsSpec)

    My-Logger "Generating $VCFInstallerProductSKU Management Domain deployment JSON file $VCFManagementDomainJSONFile"
    $vcfConfig | ConvertTo-Json -Depth 20 | Out-File -LiteralPath $VCFManagementDomainJSONFile
}

if($configureVCFInstallerConfig -eq 1) {
    My-Logger "Updating VCF Installer Software Depot ..."

    Verify-VCFAPIEndpoint -EndpointIp $VCFInstallerFQDN

    $connectDepot = 1
    $syncDepot = 1
    $downloadReleases = 1

    if($connectDepot -eq 1) {
        Connect-VCFDepot -EndpointIp $VCFInstallerFQDN
    }

    if($syncDepot -eq 1) {
        Sync-VCFDepot -EndpointIp $VCFInstallerFQDN
    }

    if($downloadReleases -eq 1) {
        Download-VCFRelease -EndpointIp $VCFInstallerFQDN
    }
}

if($startVCFBringup -eq 1) {
    My-Logger "Starting $VCFInstallerProductSKU Deployment Bringup ..."

    $headers = Get-VCFInstallerToken

    $printSuccess = 1
    try {
        $uri = "https://${VCFInstallerFQDN}/v1/sddcs"
        $method = "POST"
        $body = Get-Content -Raw $VCFManagementDomainJSONFile

        if($Debug) {
            My-Logger "DEBUG: Method: $method"
            My-Logger "DEBUG: Uri: $uri"
            My-Logger "DEBUG: Body: $body"
        }

        $requests = Invoke-WebRequest -Uri $uri -Method $method -SkipCertificateCheck -TimeoutSec 5 -Headers $headers -Body $body
    }
    catch {
        if($requests.StatusCode -eq 200 -or $requests.StatusCode -eq 202) {
            $printSuccess = 0
            My-Logger "Open browser to the VMware VCF Installer UI (https://${VCFInstallerFQDN}/vcf-installer-ui/portal/progress-viewer) to monitor deployment progress ..."
        } else {
            My-Logger "Failed to submit $VCFInstallerProductSKU Deployment request ..."
            $requests
            exit
        }
    }
    if($printSuccess -eq 1) {
        My-Logger "Open browser to the VMware VCF Installer UI (https://${VCFInstallerFQDN}/vcf-installer-ui/portal/progress-viewer) to monitor deployment progress ..."
    }
}

if($startVCFBringup -eq 1 -and $uploadVCFNotifyScript -eq 1) {
    if(Test-Path $srcNotificationScript) {
        $vcfVM = Get-VM -Server $viConnection $vcfInstallerVMName

        My-Logger "Uploading VCF notification script $srcNotificationScript to $dstNotificationScript on VCF Installer appliance ..."
        Copy-VMGuestFile -Server $viConnection -VM $vcfVM -Source $srcNotificationScript -Destination $dstNotificationScript -LocalToGuest -GuestUser "root" -GuestPassword $VCFInstallerRootPassword | Out-Null
        Invoke-VMScript -Server $viConnection -VM $vcfVM -ScriptText "chmod +x $dstNotificationScript" -GuestUser "root" -GuestPassword $VCFInstallerRootPassword | Out-Null

        My-Logger "Configuring crontab to run notification check script every 15 minutes ..."
        Invoke-VMScript -Server $viConnection -VM $vcfVM -ScriptText "echo '*/15 * * * * $dstNotificationScript' > /var/spool/cron/root" -GuestUser "root" -GuestPassword $VCFInstallerRootPassword | Out-Null
    }
}

if($deployNestedESXiVMsForMgmt -eq 1 -or $deployNestedESXiVMsForWLD -eq 1 -or $updateVCFInstallerConfig -eq 1 -or $deployVCFInstaller -eq 1) {
    My-Logger "Disconnecting from Management vCenter Server $VIServer ..."
    Disconnect-VIServer -Server $viConnection -Confirm:$false
}

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

My-Logger "$VCFInstallerProductSKU 9.1 Lab Deployment Complete!"
My-Logger "`tStartTime: $StartTime" -color cyan
My-Logger "`tEndTime: $EndTime" -color cyan
My-Logger "`tDuration: $duration minutes to deploy VCF Installer, Nested ESX VMs & start $VCFInstallerProductSKU Deployment" -color cyan
