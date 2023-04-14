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

#----------------------------------------------------------------------------------------------------------------------------------------------#
# Function to create Log Files
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Error", "Warning", "Information")]
        [string]$Severity
    )
    $Path = "C:\Deploy-Hyper-V-Master\Logs\LogFile.log"

    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$date [$Severity] $Message"

    if ($Severity -eq "Error") {
        Write-Error $Message
    }
    elseif ($Severity -eq "Warning") {
        Write-Warning $Message
    }

    Add-Content -Path $Path -Value $logMessage -Force
}

#----------------------------------------------------------------------------------------------------------------------------------------------#
# Function to check AWX Connection
function Get-AWX-Connection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AwxUrl,
        [Parameter(Mandatory = $true)]
        [string]$AwxUsername,
        [Parameter(Mandatory = $true)]
        [string]$AwxPassword
    )

    $headers = @{
        'Content-Type' = 'application/json'
    }

    
    $uri = "$AwxUrl/api/v2/"
    try {
        Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -Credential (New-Object System.Management.Automation.PSCredential($AwxUsername, ($AwxPassword | ConvertTo-SecureString -AsPlainText -Force)))  -ErrorAction Stop
        return $true
    }
    catch {
        Write-Log -Severity Information -Message "[Function] "$_.Exception.Message""
        return $false
    }
}

#----------------------------------------------------------------------------------------------------------------------------------------------#
# Function to create AWX credentials
function New-AWX-Credentials {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AwxUrl,
        [Parameter(Mandatory = $true)]
        [string]$AwxUsername,
        [Parameter(Mandatory = $true)]
        [string]$AwxPassword,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Username,
        [Parameter(Mandatory = $true)]
        [string]$Password,
        [Parameter(Mandatory = $true)]
        [string]$Type,
        [Parameter(Mandatory = $false)]
        [string]$Description
    )

    $headers = @{
        'Content-Type' = 'application/json'
    }

    $body = @{
        'name' = $Name
        'username' = $Username
        'password' = $Password
        'credential_type' = $Type
        'description' = $Description
    } | ConvertTo-Json

    $uri = "$AwxUrl/api/v2/credentials/"

    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -Credential (New-Object System.Management.Automation.PSCredential($AwxUsername, ($AwxPassword | ConvertTo-SecureString -AsPlainText -Force))) -ErrorAction Stop

    return $response
}

#----------------------------------------------------------------------------------------------------------------------------------------------#
# Function to create an inventory
function New-AWXInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AwxUrl,
        [Parameter(Mandatory = $true)]
        [string]$AwxUsername,
        [Parameter(Mandatory = $true)]
        [string]$AwxPassword,
        [Parameter(Mandatory = $true)]
        [string]$InventoryName
    )
 
    $headers = @{
        'Authorization' = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($AwxUsername):$($AwxPassword)"))
        'Content-Type' = 'application/json'
    }
 
    $body = @{
        name = $InventoryName
        description = ""
        organization = 1
        kind = ""
        host_filter = ""
        variables = ""
        prevent_instance_group_fallback = "false"

    } | ConvertTo-Json
 
    $uri = "$AwxUrl/api/v2/inventories/"
 
    $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -ContentType 'application/json'
 
    return $response
}

#----------------------------------------------------------------------------------------------------------------------------------------------#
# Function to create a host and add it to a group
function New-AWXHostAndAddToGroup {
    param (
        [string]$AWXUrl,
        [string]$AWXUsername,
        [string]$AWXPassword,
        [string]$GroupName,
        [string]$HostName,
        [string]$InventoryName
    )

    $inventoryUrl = "$AWXUrl/api/v2/inventories/?name=$InventoryName"
    $inventory = Invoke-RestMethod -Uri $inventoryUrl -Method Get -Headers @{Authorization = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($AWXUsername+":"+$AWXPassword))}
    if ($inventory.count -eq 0) {
        throw "Inventory $InventoryName not found"
    }
    $inventoryId = $inventory.results.id

    $groupUrl = "$AWXUrl/api/v2/inventories/$($inventoryId)/groups/?name=$($GroupName)"
    $group = Invoke-RestMethod -Uri $groupUrl -Method Get -Headers @{Authorization = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($AWXUsername+":"+$AWXPassword))}
    if ($group.count -eq 0) {
        throw "Group $GroupName not found in inventory $InventoryName"
    }
    $groupId = $group.results.id

    $hostBody = @{
        "name" = $HostName
        "description" = "Host created by PowerShell script"
        "inventory" =  $inventoryId
        "enabled" = $true
        "variables" = "{ansible_host: $hostname}"
        "instance_id" = $null
    }

    $createHostUrl = "$AWXUrl/api/v2/hosts/"
    $createHostResponse = Invoke-RestMethod -Uri $createHostUrl -Method Post -Headers @{
        Authorization = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($AWXUsername+":"+$AWXPassword))
        'Content-Type' = 'application/json'
    } -Body (ConvertTo-Json $hostBody)

    $addHostToGroupUrl = "$AWXUrl/api/v2/groups/$($groupId)/hosts/"
    $addHostToGroupBody = @{
        "id" = $createHostResponse.id
    }

    Invoke-RestMethod -Uri $addHostToGroupUrl -Method Post -Headers @{
        Authorization = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($AWXUsername+":"+$AWXPassword))
        'Content-Type' = 'application/json'
    } -Body (ConvertTo-Json $addHostToGroupBody)
}

#----------------------------------------------------------------------------------------------------------------------------------------------#
# Function to create a group
function New-AWXInventoryGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AwxUrl,
        [Parameter(Mandatory = $true)]
        [string]$AwxUsername,
        [Parameter(Mandatory = $true)]
        [string]$AwxPassword,
        [Parameter(Mandatory = $true)]
        [string]$InventoryName,
        [Parameter(Mandatory = $true)]
        [string]$GroupName
    )
 
    $headers = @{
        'Authorization' = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($AwxUsername):$($AwxPassword)"))
        'Content-Type' = 'application/json'
    }
 
    $uri = "$AwxUrl/api/v2/inventories/?name=$InventoryName"
 
    $inventory = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType 'application/json'
    $inventory_id = $inventory.results.id

    $body = @{
        name = $GroupName
        description = ""
        inventory = $inventory_id
        variables = ""
    } | ConvertTo-Json
 
    $uri = "$AwxUrl/api/v2/inventories/$inventory_id/groups/"
 
    $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -ContentType 'application/json'
 
    return $response
}

#----------------------------------------------------------------------------------------------------------------------------------------------#
# Function to update inventory on a jobtemplate
function Update-AWXInventoryOnJobTemplate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AwxUrl,
        [Parameter(Mandatory=$true)]
        [string]$AwxUsername,
        [Parameter(Mandatory=$true)]
        [string]$AwxPassword,
        [Parameter(Mandatory=$true)]
        [string]$JobTemplateName,
        [Parameter(Mandatory=$true)]
        [string]$InventoryName,
        [Parameter(Mandatory=$true)]
        [string]$CredentialName
    )

    $authHeader = "Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($AwxUsername):$($AwxPassword)"))

    $jobTemplatesUrl = "$AwxUrl/api/v2/job_templates/?name=$JobTemplateName"
    $jobTemplateResponse = Invoke-RestMethod -Method Get -Uri $jobTemplatesUrl -Headers @{Authorization=$authHeader} -ContentType "application/json"
    if ($jobTemplateResponse.results.count -eq 0) {
        throw "Job template '$JobTemplateName' not found"
    }
    $jobTemplateId = $jobTemplateResponse.results[0].id

    $inventoriesUrl = "$AwxUrl/api/v2/inventories/?name=$InventoryName"
    $inventoryResponse = Invoke-RestMethod -Method Get -Uri $inventoriesUrl -Headers @{Authorization=$authHeader} -ContentType "application/json"
    if ($inventoryResponse.results.count -eq 0) {
        throw "Inventory '$InventoryName' not found"
    }
    $inventoryId = $inventoryResponse.results[0].id

    $credentialsUrl = "$AwxUrl/api/v2/credentials/?name=$CredentialName"
    $credentialResponse = Invoke-RestMethod -Method Get -Uri $credentialsUrl -Headers @{Authorization=$authHeader} -ContentType "application/json"
    if ($credentialResponse.results.count -eq 0) {
        throw "Credential '$CredentialName' not found"
    }
    $credentialId = $credentialResponse.results[0].id

    $jobTemplateUrl = "$AwxUrl/api/v2/job_templates/$jobTemplateId/"

    $jobTemplatePayload = @{
        "inventory" = $inventoryId
        "credentials" = @{
            "add" = @{
                "id" = $credentialId
                "name" = "Ubuntu Template User"
            }
        }
    } | ConvertTo-Json

    $headers = @{Authorization=$authHeader; ContentType='application/json'}
    Invoke-RestMethod -Method Patch -Uri $jobTemplateUrl -Headers @{Authorization=$authHeader; 'Content-Type'='application/json'} -Body $jobTemplatePayload
}

#----------------------------------------------------------------------------------------------------------------------------------------------#
# Function to format MacAddress
function Normalize-MacAddress ([string]$value) {
    $value.`
        Replace('-', '').`
        Replace(':', '').`
        Insert(2,':').Insert(5,':').Insert(8,':').Insert(11,':').Insert(14,':').`
        ToLowerInvariant()
}

#----------------------------------------------------------------------------------------------------------------------------------------------#
# Function to download Image from Ubuntu
function Get-UbuntuImage {
    [CmdletBinding()]
    param(
        [string]$OutputPath,
        [switch]$Previous
    )

    # Import functions.ps1
    . .\functions.ps1

    $ErrorActionPreference = 'Stop'

    # Enable TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    try {
        if ($Previous) {
            $urlRoot = 'https://cloud-images.ubuntu.com/releases/focal/release/'
            $urlFile = 'ubuntu-20.04-server-cloudimg-amd64.img'
        } else {
            $urlRoot = 'https://cloud-images.ubuntu.com/releases/jammy/release/'
            $urlFile = 'ubuntu-22.04-server-cloudimg-amd64.img'
        }

        $url = "$urlRoot/$urlFile"

        if (-not $OutputPath) {
            $OutputPath = Get-Item '.\'
        }

        $imgFile = Join-Path $OutputPath $urlFile

        ## Check if Image already exists
        if ([System.IO.File]::Exists($imgFile)) {
            Write-Log -Severity Information -Message "[Image-Download] File '$imgFile' already exists. Nothing to do."
        } else {
            ## Download Image
            Write-Log -Severity Information -Message "[Image-Download] Downloading Ubuntu Image $urlfile"

            $client = New-Object System.Net.WebClient
            $client.DownloadFile($url, $imgFile)

            ## Check Integrity
            Write-Verbose "Checking file integrity..."
            $sha1Hash = Get-FileHash $imgFile -Algorithm SHA256
            $allHashs = $client.DownloadString("$urlRoot/SHA256SUMS")
            $m = [regex]::Matches($allHashs, "(?<Hash>\w{64})\s\*$urlFile")
            if (-not $m[0]) { throw "Cannot get hash for $urlFile." }
            $expectedHash = $m[0].Groups['Hash'].Value
            if ($sha1Hash.Hash -ne $expectedHash) { 
                throw "Integrity check for '$imgFile' failed." 
                Write-Log -Severity Error -Message "[Image-Download] Integrity check for '$imgFile' failed."
            }
        }

        $imgFile
    }
    catch {
        Write-Log -Severity Error -Message "[Image-Download] Error Downloading Ubuntu Image"
        Write-Log -Severity Error -Message ("[Image-Download]" + $Error)
    }
}