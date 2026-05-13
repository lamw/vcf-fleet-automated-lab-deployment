# Physical vCenter Server environment
$VIServer = ""
$VIUsername = ""
$VIPassword = ""

# General Deployment Configuration
$VAppLabel = "WilliamLam-VCF9"
$VMDatacenter = "Datacenter"
$VMCluster = "MyCluster"
$VMNetwork = "MyNetwork"
$VMDatastore = "MyDatastore"
$VMNetmask = "255.255.0.0"
$VMGateway = "172.16.1.53"
$VMDNS = "172.16.1.3"
$VMNTP = "172.16.1.53"
$VMPassword = "VMware1!"
$VMDomain = "vcf.lcm"
$VMSyslog = "172.16.1.250"
$VMFolder = "wlam"

# Enable Debugging
$Debug = $false

# Full Path to both the Nested ESXi & VCF Installer OVA
$NestedESXiApplianceOVA = "/data/images/Nested_ESXi9.1.0.0_Appliance_Template_v1.0.ova"
$VCFInstallerOVA = "/data/images/VCF-SDDC-Manager-Appliance-9.1.0.0.25371088.ova"

# VCF Installer Workarounds in /etc/vmware/vcf/domainmanager/application.properties
$VCFDomainManagerProperties = @{
    "validation.disable.network.connectivity.check" = "true"
    "nsxt.mtu.validation.skip" = "true"
    "vsan.esa.sddc.managed.disk.claim" = "true"
}

# VCF Version
$VCFInstallerProductVersion = "9.1.0.0"
$VCFInstallerProductSKU = "VCF"

# VCF Software Depot Configuration
$VCFInstallerSoftwareDepot = "offline" #online or offline
$VCFInstallerDepotToken = ""

# Offline Depot Configurations (optional)
$VCFInstallerDepotUrl = "http://172.16.1.54:8888"

# VCF Fleet Deployment Configuration
$DeploymentInstanceName = "William VCF 9.1 Instance"
$DeploymentId = "vcf-m01"
$CEIPEnabled = $true

# VCF Installer Configurations
$VCFInstallerVMName = "inst01"
$VCFInstallerFQDN = "inst01.vcf.lcm"
$VCFInstallerIP = "172.16.30.10"
$VCFInstallerAdminUsername = "admin@local" # do not change
$VCFInstallerAdminPassword = "VMware1!VMware1!"
$VCFInstallerRootPassword = "VMware1!VMware1!"

# SDDC Manager Configuration
$SddcManagerHostname  = "sddcm01"
$SddcManagerIP = "172.16.30.11"
$SddcManagerRootPassword = "VMware1!VMware1!"
$SddcManagerVcfPassword = "VMware1!VMware1!"
$SddcManagerSSHPassword = "VMware1!VMware1!"
$SddcManagerLocalPassword = "VMware1!VMware1!"

# Nested ESXi VMs for Management Domain
$NestedESXiHostnameToIPsForManagementDomain = @{
    "esx01"   = "172.16.30.1"
    "esx02"   = "172.16.30.2"
    "esx03"   = "172.16.30.3"
}

# Nested ESXi VMs for Workload Domain
$NestedESXiHostnameToIPsForWorkloadDomain = @{
    "esx04"   = "172.16.30.4"
    "esx05"   = "172.16.30.5"
    "esx06"   = "172.16.30.6"
}

# Nested ESXi VM Resources for Management Domain
$NestedESXiMGMTvCPU = "32"
$NestedESXiMGMTvMEM = "112" #GB
$NestedESXiMGMTCachingvDisk = "32" #GB
$NestedESXiMGMTCapacityvDisk = "500" #GB
$NestedESXiMGMTBootDisk = "64" #GB

# Nested ESXi VM Resources for Workload Domain
$NestedESXiWLDvCPU = "16"
$NestedESXiWLDvMEM = "32" #GB
$NestedESXiWLDCachingvDisk = "32" #GB
$NestedESXiWLDCapacityvDisk = "250" #GB
$NestedESXiWLDBootDisk = "64" #GB

# ESXi Network Configuration
$NestedESXiManagementNetworkCidr = "172.16.0.0/16" # should match $VMNetwork configuration
$NestedESXivMotionNetworkCidr = "10.1.32.0/24"
$NestedESXivSANNetworkCidr = "10.1.33.0/24"
$NestedESXiNSXTepNetworkCidr = "10.1.34.0/24"

# vCenter Configuration
$VCSAName = "vc01"
$VCSAIP = "172.16.30.12"
$VCSARootPassword = "VMware1!VMware1!"
$VCSASSOPassword = "VMware1!VMware1!"
$VCSASize = "medium"
$VCSADatacenterName = "vcf-mgmt-dc"
$VCSAClusterName = "vcf-mgmt-cl01"

#vSAN Configuration
$VSANFTT = 0
$VSANDedupe = $false
$VSANESAEnabled = $true
$VSANDatastoreName = "vsanDatastore"

# NSX Configuration
$NSXManagerSize = "medium"
$NSXManagerVIPHostname = "nsx01"
$NSXManagerVIPIP = "172.16.30.20"
$NSXManagerNodeHostname = "nsx01a"
$NSXRootPassword = "VMware1!VMware1!"
$NSXAdminPassword = "VMware1!VMware1!"
$NSXAuditPassword = "VMware1!VMware1!"

# VCF Management Services
$VCFManagementServicesSize = "small"
$VCFManagementServicesRuntimeHostname = "vcf-msr01"
$VCFManagementServicesSystemPassword = "VMware1!VMware1!"
$VCFManagementServicesFleetHostname = "vcf-flt01"
$VCFManagementServicesInstanceHostname = "vcf-int01"
$VCFManagementServicesIPStartRange = "172.16.1.65"
$VCFManagementServicesIPEndRange = "172.16.1.76"
$VCFManagementServicesInternalClusterCidrIpv4 = "198.18.0.0/15"

# Identity Management
$VCFManagementServicesIdentityHostname = "vcf-idb01"

# Logs Management
$VCFManagementLogsHostname = "vcf-logs01"
$VCFManagementLogsPassword = "VMware1!VMware1!"

# License Server
$VCFLicenseServerHostname = "vcf-lic01"

# VCF Operations Configuration
$VCFOperationsSize = "small"
$VCFOperationsHostname = "vcf01"
$VCFOperationsIP = "172.16.30.13"
$VCFOperationsRootPassword = "VMware1!VMware1!"
$VCFOperationsAdminPassword = "VMware1!VMware1!"

# VCF Operations Collector
$VCFOperationsCollectorSize = "small"
$VCFOperationsCollectorHostname = "vcf-proxy01"
$VCFOperationsCollectorRootPassword = "VMware1!VMware1!"

# VCF Automation
$VCFAutomationSize = "small"
$VCFAutomationHostname = "auto01"
$VCFAutomationServicesRuntimeHostname = "vcf-asr01"
$VCFAutomationAdminPassword = "VMware1!VMware1!"
$VCFAutomationIPPool = @("172.16.1.77","172.16.1.78","172.16.1.79","172.16.1.80","172.16.1.81")
$VCFAutomationNodePrefix = "vcf-lamw-auto"
$VCFAutomationClusterCIDR = "198.18.0.0/15"

# VCF Workload Domain Configurations
$VCFWorkloadDomainName = "vcf-w01"
$VCFWorkloadDomainOrgName = "vcf-w01"
$VCFWorkloadDomainEnableVSANESA = $false

# WLD vCenter Configuration
$VCFWorkloadDomainVCSAHostname = "vc02"
$VCFWorkloadDomainVCSAIP = "172.16.30.100"
$VCFWorkloadDomainVCSARootPassword = "VMware1!VMware1!"
$VCFWorkloadDomainVCSASSOPassword = "VMware1!VMware1!"
$VCFWorkloadDomainVCSADatacenterName = "vcf-wld-dc"
$VCFWorkloadDomainVCSAClusterName = "vcf-wld-cl01"

# WLD NSX Configuration
$VCFWorkloadDomainNSXManagerVIPHostname = "nsx02"
$VCFWorkloadDomainNSXManagerNode1Hostname = "nsx02a"
$VCFWorkloadDomainNSXManagerNode1IP = "172.16.30.102"
$VCFWorkloadDomainNSXAdminPassword = "VMware1!VMware1!"
$VCFWorkloadDomainSeparateNSXSwitch = $false
