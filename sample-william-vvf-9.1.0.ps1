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

# VCF Installer Domain Manager Workarounds
$VCFDomainManagerProperties = @{
    "validation.disable.network.connectivity.check" = "true"
    "nsxt.mtu.validation.skip" = "true"
    "vsan.esa.sddc.managed.disk.claim" = "true"
}

# VCF Version
$VCFInstallerProductVersion = "9.1.0.0"
$VCFInstallerProductSKU = "VVF"

# VCF Software Depot Configuration
$VCFInstallerSoftwareDepot = "offline" #online or offline
$VCFInstallerDepotToken = ""

# Offline Depot Configurations (optional)
$VCFInstallerDepotUrl = "http://172.16.1.54:8888"

# VCF Fleet Deployment Configuration
$DeploymentInstanceName = "William VVF 9.1 Instance"
$DeploymentId = "vcf-m01"
$CEIPEnabled = $true

# VCF Installer Configurations
$VCFInstallerVMName = "inst01"
$VCFInstallerFQDN = "inst01.vcf.lcm"
$VCFInstallerIP = "172.16.30.10"
$VCFInstallerAdminUsername = "admin@local" # do not change
$VCFInstallerAdminPassword = "VMware1!VMware1!"
$VCFInstallerRootPassword = "VMware1!VMware1!"

# Nested ESXi VMs for Management Domain
$NestedESXiHostnameToIPsForManagementDomain = @{
    "esx01"   = "172.16.30.1"
    "esx02"   = "172.16.30.2"
    "esx03"   = "172.16.30.3"
}

# Nested ESXi VM Resources for Management Domain
$NestedESXiMGMTvCPU = "32"
$NestedESXiMGMTvMEM = "112" #GB
$NestedESXiMGMTCachingvDisk = "32" #GB
$NestedESXiMGMTCapacityvDisk = "500" #GB
$NestedESXiMGMTBootDisk = "64" #GB

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

# VCF Management Services
$VCFManagementServicesSize = "small"
$VCFManagementServicesRuntimeHostname = "vcf-msr01"
$VCFManagementServicesSystemPassword = "VMware1!VMware1!"
$VCFManagementServicesFleetHostname = "vcf-flt01"
$VCFManagementServicesInstanceHostname = "vcf-int01"
$VCFManagementServicesIPStartRange = "172.16.1.65"
$VCFManagementServicesIPEndRange = "172.16.1.76"
$VCFManagementServicesInternalClusterCidrIpv4 = "198.18.0.0/15"

# License Server
$VCFLicenseServerHostname = "vcf-lic01"

# VCF Operations Configuration
$VCFOperationsSize = "small"
$VCFOperationsHostname = "vcf01"
$VCFOperationsIP = "172.16.30.13"
$VCFOperationsRootPassword = "VMware1!VMware1!"
$VCFOperationsAdminPassword = "VMware1!VMware1!"