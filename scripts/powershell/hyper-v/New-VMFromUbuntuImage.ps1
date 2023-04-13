#===========================================================================================================================================================# 
#                 █████  █████ ███████████    █████████  ███████████   ██████████   █████████   ███████████      █████████     █████████                    # 
#                ░░███  ░░███ ░░███░░░░░███  ███░░░░░███░░███░░░░░███ ░░███░░░░░█  ███░░░░░███ ░█░░░███░░░█     ███░░░░░███   ███░░░░░███                   #
#                 ░███   ░███  ░███    ░███ ███     ░░░  ░███    ░███  ░███  █ ░  ░███    ░███ ░   ░███  ░     ░███    ░███  ███     ░░░                    #
#                 ░███   ░███  ░██████████ ░███          ░██████████   ░██████    ░███████████     ░███        ░███████████ ░███                            #
#                 ░███   ░███  ░███░░░░░░  ░███    █████ ░███░░░░░███  ░███░░█    ░███░░░░░███     ░███        ░███░░░░░███ ░███    █████                   #
#                 ░███   ░███  ░███        ░░███  ░░███  ░███    ░███  ░███ ░   █ ░███    ░███     ░███        ░███    ░███ ░░███  ░░███                    #
#                 ░░████████   █████        ░░█████████  █████   █████ ██████████ █████   █████    █████       █████   █████ ░░█████████                    #
#                   ░░░░░░░░   ░░░░░          ░░░░░░░░░  ░░░░░   ░░░░░ ░░░░░░░░░░ ░░░░░   ░░░░░    ░░░░░       ░░░░░   ░░░░░   ░░░░░░░░░                    #
#===========================================================================================================================================================# 
# Created by Mathis Okle                                                                                                                                    #
# Version 1.0                                                                                                                                               #
#===========================================================================================================================================================# 

#Requires -RunAsAdministrator


#-------------[Variables]--------------------------------------------------------------------------------------------------------------------------------------
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,

    [ValidateScript({
        $existingVm = Get-VM -Name $_ -ErrorAction SilentlyContinue
        if (-not $existingVm) {
            return $True
        }
        throw "There is already a VM named '$VMName' in this server."
        
    })]
    [Parameter(Mandatory=$true)]
    [string]$VMName,
    [string]$FQDN = $VMName,
    [Parameter(Mandatory=$true, ParameterSetName='RootPassword')]
    [string]$RootPassword = $rootpassword,
    [Parameter(Mandatory=$true, ParameterSetName='RootPublicKey')]
    [string]$RootPublicKey,
    [uint64]$VHDXSizeBytes = 20GB,
    [int64]$MemoryStartupBytes = 8GB,
    [switch]$EnableDynamicMemory,
    [int64]$ProcessorCount = 2,
    [string]$SwitchName = $vSwitch,
    [ValidateScript({
        if ($_ -match '^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$') {
            return $True
        }
        throw "-MacAddress must be in format 'xx:xx:xx:xx:xx:xx'."
    })]
    [string]$MacAddress,
    [ValidateScript({
        $sIp, $suffix = $_.Split('/')
        if ($ip = $sIp -as [ipaddress]) {
            $maxSuffix = if ($ip.AddressFamily -eq 'InterNetworkV6') { 128 } else { 32 }
            if ($suffix -in 1..$maxSuffix) {
                return $True
            }
            throw "Invalid -IPAddress suffix ($suffix)."
        }
        throw "Invalid -IPAddress ($sIp)."
    })]
    [string]$IPAddress,
    [string]$Gateway,
    [string[]]$DnsAddresses = @('1.1.1.1','1.0.0.1'),
    [string]$InterfaceName = 'eth0',
    [string]$VlanId
)

$ErrorActionPreference = 'Stop'

#-------------[Functions]-------------------------------------------------------------------------------------------------------------------------------------- 
. .\functions.ps1

Write-log -Severity Information -Message "[Deploy-$VMName] Starting Deployment"

try{
#-------------[Get-Default VHD Storage]----------------------------------------------------------------------------------------------------------------------
    $vmms = gwmi -namespace root\virtualization\v2 Msvm_VirtualSystemManagementService
    $vmmsSettings = gwmi -namespace root\virtualization\v2 Msvm_VirtualSystemManagementServiceSettingData
    $vhdxPath = Join-Path $vmmsSettings.DefaultVirtualHardDiskPath "$VMName.vhdx"
    $metadataIso = Join-Path $vmmsSettings.DefaultVirtualHardDiskPath "$VMName-metadata.iso"

#-------------[Convert VHD to VHDX]----------------------------------------------------------------------------------------------------------------------------
    Write-log -Severity Information -Message "[Deploy-$VMName]Creating VHDX from cloud image..."
    $ErrorActionPreference = 'Continue'
    & {
        & .\tools\hyper-v-disk\qemu-img.exe convert -f qcow2 $SourcePath -O vhdx -o subformat=dynamic $vhdxPath
        if ($LASTEXITCODE -ne 0) {
            throw "qemu-img returned $LASTEXITCODE. Aborting."
        }
    }
    $ErrorActionPreference = 'Stop'

    Resize-VHD -Path $vhdxPath -SizeBytes 20GB
    
    Write-log -Severity Information -Message "[Deploy-$VMName] Adding VM to Hyper-v"
#-------------[Create VM]--------------------------------------------------------------------------------------------------------------------------------------
    Write-log -Severity Information -Message "[Deploy-$VMName] Creating VM..."
    $vm = New-VM -Name $VMName -Generation 2 -MemoryStartupBytes $MemoryStartupBytes -VHDPath $vhdxPath -SwitchName $SwitchName
    $vm | Set-VMProcessor -Count $ProcessorCount
    $vm | Get-VMIntegrationService -Name "Guest Service Interface" | Enable-VMIntegrationService
    $vm | Set-VMMemory -DynamicMemoryEnabled:$EnableDynamicMemory.IsPresent

#-------------[Set Secure Boot Template]-----------------------------------------------------------------------------------------------------------------------
    $vm | Set-VMFirmware -SecureBootTemplateId ([guid]'272e7447-90a4-4563-a4b9-8e4ab00526ce')

#-------------[Configure networking]---------------------------------------------------------------------------------------------------------------------------
    if ($MacAddress) {
        $MacAddress = Normalize-MacAddress $MacAddress
        $vm | Set-VMNetworkAdapter -StaticMacAddress $MacAddress.Replace(':', '')
    }
    $eth0 = Get-VMNetworkAdapter -VMName $VMName 
    $eth0 | Rename-VMNetworkAdapter -NewName $InterfaceName
    if ($VlanId) {
        $eth0 | Set-VMNetworkAdapterVlan -Access -VlanId $VlanId
    }    

#-------------[Create MAC address]-----------------------------------------------------------------------------------------------------------------------------
    $vm | Start-VM
    Start-Sleep -Seconds 1
    $vm | Stop-VM -Force

    # Wait for Mac Addresses
    Write-log -Severity Information -Message "[Deploy-$VMName] Waiting for MAC addresses..."
    do {
        $eth0 = Get-VMNetworkAdapter -VMName $VMName -Name $InterfaceName
        $MacAddress = Normalize-MacAddress $eth0.MacAddress
        Start-Sleep -Seconds 1
    } while ($MacAddress -eq '00:00:00:00:00:00')

#-------------[Create Meta Data Iso]---------------------------------------------------------------------------------------------------------------------------
#   Creates a NoCloud data source for cloud-init.
#   More info: http://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html
Write-log -Severity Information -Message "[Deploy-$VMName] Creating metadata ISO image..."
$instanceId = [Guid]::NewGuid().ToString()
 
$metadata = @"
instance-id: $instanceId
local-hostname: $VMName
"@

$displayInterface = "     $($InterfaceName): \4{$InterfaceName}    \6{$InterfaceName}"
$displaySecondaryInterface = ''

$sectionWriteFiles = @"
write_files:
 - content: |
     \S{PRETTY_NAME}    \n    \l

$displayInterface
$displaySecondaryInterface
   path: /etc/issue
   owner: root:root
   permissions: '0644'

"@

$sectionRunCmd = @'
runcmd:
 - 'apt-get update'
 - 'grep -o "^[^#]*" /etc/netplan/50-cloud-init.yaml > /etc/netplan/80-static.yaml'    
 - 'rm /etc/netplan/50-cloud-init.yaml'
 - 'touch /etc/cloud/cloud-init.disabled'
 - 'update-grub'     
 - 'sudo sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config'
 - 'sudo service ssh restart'
'@

$userdata = @"
#cloud-config
hostname: $FQDN
fqdn: $FQDN

ssh_pwauth: true
ssh_authorized_keys:
- ssh-rsassh-rsa $sshkey
chpasswd:
  list: |
     root:IbgiG2003
     ubuntu:IbgiG2003
  expire: False
$sectionWriteFiles
$sectionRunCmd

power_state:
  mode: reboot
  timeout: 300
"@

# Uses netplan to setup network.
if ($IPAddress) {
    $NetworkConfig = @"
version: 2
ethernets:
  $($InterfaceName):
    match:
      macaddress: $MacAddress
    set-name: $($InterfaceName)
    addresses: [$IPAddress]
    nameservers:
      addresses: [$($DnsAddresses -join ', ')]
    routes:
      - to: 0.0.0.0/0
        via: $Gateway
        on-link: true

"@
} else {
    $NetworkConfig = @"
version: 2
ethernets:
  $($InterfaceName):
    match:
      macaddress: $MacAddress
    set-name: $($InterfaceName)
    dhcp4: true
    dhcp-identifier: mac

"@
}



# Save all files in temp folder and create metadata .iso from it
$temp_root = ".\"
[STRING]$genisoimg_root = ".\tools\genisoimg\*"
[STRING]$tempPath = New-Item -ItemType Directory -Path $temp_root  -Name "temp_$vmname" -Force
Copy-Item -Recurse -Verbose -Path $genisoimg_root -Destination $tempPath | Out-Null

# Create Folder for Cloud-Init Files
$cloudinit_root = ".\cloud-init"
$cloudinit_path = New-Item -Path $cloudinit_root -Name $vmname  -ItemType Directory -Force


try {
    $metadata | Out-File "$cloudinit_path\meta-data" -Encoding ascii
    $userdata | Out-File "$cloudinit_path\user-data" -Encoding ascii
    $NetworkConfig | Out-File "$cloudinit_path\network-config" -Encoding ascii
    
    Copy-Item -Recurse -Verbose -Path "$cloudinit_path\*" -Destination $tempPath
    cd ".\temp_$vmname\"
    & {
        $ErrorActionPreference = 'Continue'
        & .\genisoimage.exe -output "C:\Deploy-Hyper-V-Master\main\scripts\powershell\hyper-v\custom_isos\$vmname.iso" -volid cidata -joliet-long -rock user-data meta-data network-config
        if ($LASTEXITCODE -gt 0) {
            throw "oscdimg.exe returned $LASTEXITCODE."
        }
    }
}
catch{}

cd ..
rmdir -Path $tempPath -Recurse -Force
# Adds DVD with metadata.iso
$dvd = $vm | Add-VMDvdDrive -Path (".\custom_isos\"+$VMName+".iso") -Passthru

# Disable Automatic Checkpoints. Check if command is available since it doesn't exist in Server 2016.
$command = Get-Command Set-VM
if ($command.Parameters.AutomaticCheckpointsEnabled) {
    $vm | Set-VM -AutomaticCheckpointsEnabled $false
}

# Wait for VM
$vm | Start-VM
Write-log -Severity Information -Message "[Deploy-$VMName] Waiting for VM integration services (1)..."
Wait-VM -Name $VMName -For Heartbeat

# Cloud-init will reboot after initial machine setup. Wait for it...
Write-log -Severity Information -Message "[Deploy-$VMName] Waiting for VM initial setup..."
try {
    Wait-VM -Name $VMName -For Reboot
} catch {
    # Win 2016 RTM doesn't have "Reboot" in WaitForVMTypes type. 
    #   Wait until heartbeat service stops responding.
    $heartbeatService = ($vm | Get-VMIntegrationService -Name 'Heartbeat')
    while ($heartbeatService.PrimaryStatusDescription -eq 'OK') { Start-Sleep  1 }
}

Write-Verbose 'Waiting for VM integration services (2)...'
Wait-VM -Name $VMName -For Heartbeat

# Removes DVD and metadata.iso
$dvd | Remove-VMDvdDrive

}catch{
    Write-log -Severity Error -Message "[Deploy-$VMName] Error!"
    Write-log -Severity Error -Message "[Deploy-$VMName] + $Error"
}