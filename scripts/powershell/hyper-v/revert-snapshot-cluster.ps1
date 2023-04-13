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

$vmNames = @("k8s-master-01","k8s-master-02","k8s-master-03","k8s-worker-01", "k8s-worker-02", "k8s-worker-03")

# Loop through the VM names and revert to the last snapshot
foreach ($vmName in $vmNames) {
    $vm = Get-VM -Name $vmName
    Restore-VMSnapshot -VM $vm -Name "bevor_setup_$vmname"
}