# Define the folder name and the task names, descriptions, and PowerShell script paths as arrays
$folderName = "K8s-Deployment"
$taskNames = @("UPG-K8s-Deployment-Sync-GitHub-Repo", "UPG-K8s-Deployment-Deploy-VMs", "UPG-K8s-Deployment-Update-AWX-API")
$taskDescriptions = @("This task runs PowerShell script sync_git_repo_prod.ps1", "This task runs PowerShell script deploy-vm-hyper-v.ps1", "This task runs PowerShell script New-AWX-Host.ps1")
$scriptPaths = @("C:\Deploy-Hyper-V-Master\sync_git_repo\sync_git_repo_prod.ps1", "C:\Deploy-Hyper-V-Master\main\scripts\powershell\hyper-v\deploy-vm-hyper-v.ps1", "C:\Deploy-Hyper-V-Master\main\scripts\powershell\hyper-v\New-AWX-Host.ps1")

# Create the folder for the scheduled tasks
New-ScheduledTaskFolder -Path "\" -FolderName $folderName

# Loop through the arrays and create a new scheduled task for each
for ($i = 0; $i -lt $taskNames.Length; $i++) {
    # Create a new scheduled task
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$($scriptPaths[$i])`""
    Register-ScheduledTask -TaskName $taskNames[$i] -Description $taskDescriptions[$i] -Trigger $task -Action $action -TaskPath "\$folderName"
}