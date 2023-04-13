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

#---------[Functions and modules]---------------------------------------------------------------------------------------------------------------------------#
. .\functions.ps1

#---------[Loading Config]----------------------------------------------------------------------------------------------------------------------------------#
try{
    Write-Log -Severity Information -Message "[AWX-API] Loading Config"
    $config = Get-Content "C:\Deploy-Hyper-V-Master\main\config\config.json"  | Out-String | ConvertFrom-Json
}
catch{
    Write-Log -Severity Error -Message "[AWX-API] Error Loading Config"
    Write-Log -Severity Error -Message ("[AWX-API]" +$Error)
}

#---------[Variables]---------------------------------------------------------------------------------------------------------------------------------------#
$AwxUrl = $config.awx.AwxUrl
$AwxUsername = $config.awx.AwxUsername
$AwxPassword = $config.awx.AwxPassword
$InventoryName1 = $config.awx.InventoryName1
$InventoryName2 = $config.awx.InventoryName2

#---------[Check AWX Connection]----------------------------------------------------------------------------------------------------------------------------#
try{
    Write-Log -Severity Information -Message "[AWX-API] Checking AWX Connection"    
    $check_awx_connection = Get-AWX-Connection -AwxUrl $AwxUrl -AwxUsername $AwxUsername -AwxPassword $AwxPassword

    if ($check_awx_connection -eq "true"){
        Write-Log -Severity Information -Message "[AWX-API] Connection to AWX succeded"
    }
    else {
        Write-Log -Severity Error -Message "[AWX-API] Connection to AWX error!"
    }
}
catch{
    Write-Log -Severity Error -Message "[AWX-API] Error Connection to AWX"
    Write-Log -Severity Error -Message ("[AWX-API]" +$Error)
}

#---------[Create Inventory1]-------------------------------------------------------------------------------------------------------------------------------#
try{
    Write-Log -Severity Information -Message "[AWX-API] Creating Inventory1"
    New-AWXInventory -AwxUrl $AwxUrl -AwxUsername $AwxUsername -AwxPassword $AwxPassword -InventoryName $InventoryName1
}
catch{
    Write-Log -Severity Error -Message "[AWX-API] Error Creating Inventory"
    Write-Log -Severity Error -Message ("[AWX-API]" +$Error)
}

#---------[Create Inventory2]-------------------------------------------------------------------------------------------------------------------------------#
try{
    Write-Log -Severity Information -Message "[AWX-API] Creating Inventory2"
    New-AWXInventory -AwxUrl $AwxUrl -AwxUsername $AwxUsername -AwxPassword $AwxPassword -InventoryName $InventoryName2
}
catch{
    Write-Log -Severity Error -Message "[AWX-API] Error Creating Inventory"
    Write-Log -Severity Error -Message ("[AWX-API]" +$Error)
}

#---------[Create Groups and add it to inventory]-----------------------------------------------------------------------------------------------------------#
try{
    Write-Log -Severity Information -Message "[AWX-API] Creating Groups (Controller and Worker)"
    New-AWXInventoryGroup -AwxUrl $AwxUrl -AwxUsername $AwxUsername -AwxPassword $AwxPassword -InventoryName $InventoryName1 -GroupName $config.awx.GroupName_1
    New-AWXInventoryGroup -AwxUrl $AwxUrl -AwxUsername $AwxUsername -AwxPassword $AwxPassword -InventoryName $InventoryName1 -GroupName $config.awx.GroupName_2
    New-AWXInventoryGroup -AwxUrl $AwxUrl -AwxUsername $AwxUsername -AwxPassword $AwxPassword -InventoryName $InventoryName2 -GroupName $config.awx.GroupName_3
}

catch{
    Write-Log -Severity Error -Message "[AWX-API] Error Creating Groups (Controller and Worker)"
    Write-Log -Severity Error -Message ("[AWX-API]" +$Error)
}

#---------[Create Hosts and add it to a group K8Cluster]----------------------------------------------------------------------------------------------------#
## Write Log
Write-Log -Severity Information -Message "[AWX-API] Creating Hosts and add it to the groups"

## Calculations for loop
$i = 0
$vm_count = $config.vms.vmname.count

## Loop
while ($i -ne $vm_count){
    try{
        ## Write Log
        Write-Log -Severity Information -Message ("[AWX-API] Adding"+ $config.vms.fqdn[$i])

        $hostname = $config.vms.ip_address[$i]
        $hostname = $hostname -replace ("/24","")

        if ($config.vms.role[$i] -contains "master"){
            $awxgroup = $config.awx.GroupName_1
        }

        if ($config.vms.role[$i] -contains "worker"){
            $awxgroup = $config.awx.GroupName_2
        }

        New-AWXHostAndAddToGroup -AwxUrl $AwxUrl -AwxUsername $AwxUsername -AwxPassword $AwxPassword -InventoryName $InventoryName1 -GroupName $awxgroup -HostName $hostname 
        
        $i = $i  + 1
    }
    catch{
        Write-Log -Severity Error -Message ("[AWX-API] Error Adding"+ $config.vms.fqdn[$i])
        Write-Log -Severity Error -Message ("[AWX-API]" +$Error)
    }
}

#---------[Create Hosts and add it to a group]--------------------------------------------------------------------------------------------------------------#
## Write Log
Write-Log -Severity Information -Message "[AWX-API] Creating Hosts and add it to the groups"

try{
    ## Write Log
    Write-Log -Severity Information -Message ("[AWX-API] Adding"+ $config.lb.fqdn)

    $hostname = $config.lb.ip_address
    $hostname = $hostname -replace ("/24","")
    New-AWXHostAndAddToGroup -AwxUrl $AwxUrl -AwxUsername $AwxUsername -AwxPassword $AwxPassword -InventoryName $InventoryName2 -GroupName $config.awx.GroupName_3 -HostName $hostname 
}
catch{
    Write-Log -Severity Error -Message ("[AWX-API] Error Adding"+ $config.lb.fqdn)
    Write-Log -Severity Error -Message ("[AWX-API]" +$Error)
}

## Calculations for loop
$i = 0
$template_count = $config.awx_jobtemplates.name.count

while ($i -ne $template_count){
    try{
        ## Format Input
        $jobtemplate = $config.awx_jobtemplates.name[$i]
        $inventoryname = $config.awx_jobtemplates.inventory[$i]

        Write-Log -Severity Information -Message "[AWX-API] Updating Job Template $jobtemplate with the new Inventory $inventoryname"
        Update-AWXInventoryOnJobTemplate -AwxUrl $AwxUrl -AwxUsername $AwxUsername -AwxPassword $AwxPassword -JobTemplateName $jobtemplate -InventoryName $inventoryname -CredentialName $config.awx.machine_creds

        $i = $i + 1
    }
    catch{
        Write-Log -Severity Error -Message ("[AWX-API] Error Updating Job Template $jobtemplate with the new Inventory $inventoryname")
        Write-Log -Severity Error -Message ("[AWX-API]" +$Error)

    }
}
