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

#---------[Functions and modules]--------------------------------------------------------------------------------------------------------------#
. .\functions.ps1

#---------[Variables]--------------------------------------------------------------------------------------------------------------------------#
## General
[STRING]$Script_Version = "1.03a Beta"

## Script Path
$scriptPath = $MyInvocation.MyCommand.Path
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$scriptPath = $scriptPath+"\"

## SSH Key Location
$rootPublicKey = "C:\Deploy-Hyper-V-Master\main\ssh_keys\id_rsa.pub"
 
#---------[Script Start]-----------------------------------------------------------------------------------------------------------------------#
Write-log -Severity Information -Message "-----------------[START]------------------"
Write-log -Severity Information -Message "[MASTER-Control] Starting master control"
Write-log -Severity Information -Message "[MASTER-Control] Running Version: $Script_Version"

#---------[Checking Requirements]--------------------------------------------------------------------------------------------------------------#
Write-Log -Severity Information -Message "[MASTER-Control] Checking requirements"

## Check if ssh key exists
$check_ssh_keys = Test-Path -PathType Leaf $rootPublicKey
if ($check_ssh_keys -eq $false){
    Write-Log -Severity Warning -Message "[MASTER-Control] SSH Keys are missing"

}
if  ($check_ssh_keys -eq $true){
    Write-Log -Severity Information -Message "[MASTER-Control] SSH Keys are existing"
}

#---------[Loading Config]------------------------------------------------------------------------------------------------------------------#
try{
    Write-Log -Severity Information -Message "[MASTER-Control] Loading Config"
    $config = Get-Content "C:\Deploy-Hyper-V-Master\main\config\config.json"  | Out-String | ConvertFrom-Json
}
catch{
    Write-Log -Severity Error -Message "[MASTER-Control] Error Loading Config"
    Write-Log -Severity Error -Message ("[MASTER-Control]" +$Error)
}

#---------[Downloading Cloud Image]-----------------------------------------------------------------------------------------------------------------#
try{
    Write-Log -Severity Information -Message "[Master-Control] Downloading Cloud Image"
    $imgFile = Get-UbuntuImage
}
catch{
    Write-Log -Severity Error -Message "[MASTER-Control] Error Downloading Cloud Image"
    Write-Log -Severity Error -Message ("[MASTER-Control]" +$Error)
}
#---------[Deployment process K8s]----------------------------------------------------------------------------------------------------------------------#
Write-Log -Severity Information -Message "[Master-Control] Deploing K8s LB and NFS now"

## Deployment Options
$gateway_deploy = $config.gateway
$dns_deploy = $config.dns
$vSwitch_deploy = $config.vSwitch

try{
    ## Format Config
    $vmname_deploy = $config.lb.vmname
    $fqdn_deploy = $config.lb.fqdn
    $vcpu_deploy = $config.lb.cpu_cores
    $ipv4_deploy = $config.lb.ip_address
    $vhdx_size_deploy = [Convert]::ToUInt64($config.lb.vhdx_size + '000' + '000' + '000')

    ## Write Log
    Write-Log -Severity Information -Message "[Master-Control] initiate deployment for $fqdn_deploy"

    ## Start Deployment Script in new Session
    Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "-File C:\Deploy-Hyper-V-Master\main\scripts\powershell\hyper-v\New-VMFromUbuntuImage.ps1 -VMName $vmname_deploy -SourcePath $imgFile -RootPublicKey $rootPublicKey -fqdn $fqdn_deploy -VHDXSizeBytes $vhdx_size_deploy -ProcessorCount $vcpu_deploy  -IPAddress $ipv4_deploy  -gateway $gateway_deploy -dnsaddresses $dns_deploy -SwitchName $vSwitch_deploy " -NoNewWindow

    ## Wait (Hyper-V Powershell Issue)
    Start-Sleep -Seconds 10
}
catch{
    Write-Log -Severity Error -Message "[MASTER-Control] Error initiate deployment for $fqdn_deploy"
    Write-Log -Severity Error -Message ("[MASTER-Control]" +$Error)
}

## Wait
Start-Sleep -Seconds 20

#---------[Deployment process K8s]----------------------------------------------------------------------------------------------------------------------#
Write-Log -Severity Information -Message "[Master-Control] Deploing K8s VMs now"

## Deployment Options
$gateway_deploy = $config.gateway
$dns_deploy = $config.dns
$vSwitch_deploy = $config.vSwitch

## Calculations for loop
$i = 0
$vm_count = $config.vms.vmname.count

while ($i -ne $vm_count){
    try{
        ## Format Config
        $vmname_deploy = $config.vms.vmname[$i]
        $fqdn_deploy = $config.vms.fqdn[$i]
        $vcpu_deploy = $config.vms.cpu_cores[$i]
        $ipv4_deploy = $config.vms.ip_address[$i]

        ## Write Log
        Write-Log -Severity Information -Message "[Master-Control] initiate deployment for $fqdn_deploy"

        ## Start Deployment Script in new Session
        Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "-File C:\Deploy-Hyper-V-Master\main\scripts\powershell\hyper-v\New-VMFromUbuntuImage.ps1 -VMName $vmname_deploy -SourcePath $imgFile -RootPublicKey $rootPublicKey -fqdn $fqdn_deploy -VHDXSizeBytes $vhdx_size_deploy -ProcessorCount $vcpu_deploy  -IPAddress $ipv4_deploy  -gateway $gateway_deploy -dnsaddresses $dns_deploy -SwitchName $vSwitch_deploy " -NoNewWindow

        $i = $i + 1

        ## Wait (Hyper-V Powershell Issue)
        Start-Sleep -Seconds 10
    }
    catch{
        Write-Log -Severity Error -Message "[MASTER-Control] Error initiate deployment for $fqdn_deploy"
        Write-Log -Severity Error -Message ("[MASTER-Control]" +$Error)
    }
}

## Wait
Start-Sleep -Seconds 150



