# Import common functions
. ./coreFunctions.ps1

# Main script execution
$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$envFilePath = Join-Path -Path $scriptRoot -ChildPath ".env"
Set-EnvironmentVariables -envFilePath $envFilePath
$clientName = [System.Environment]::GetEnvironmentVariable('CLIENTNAME')
$logPath = [System.Environment]::GetEnvironmentVariable('LOGPATH')
$tokenPath = [System.Environment]::GetEnvironmentVariable('TOKENPATH')
$jsonOutputPath = [System.Environment]::GetEnvironmentVariable('JSONOUTPUTPATH')
$accessToken = Get-Content -Path (Join-Path -Path $tokenPath -ChildPath "token.txt")
$uriGroups = "https://graph.microsoft.com/v1.0/groups"
$headers = @{
    Authorization = "Bearer $accessToken"
}

$jsonOutputDir = Split-Path -Path $jsonOutputPath -Parent
$errorLogDir = Split-Path -Path $logPath -Parent

if (-not (Test-Path -Path $jsonOutputDir)) {
    New-Item -Path $jsonOutputDir -ItemType Directory
}

if (-not (Test-Path -Path $errorLogDir)) {
    New-Item -Path $errorLogDir -ItemType Directory
}

try {
    $groups = Invoke-RestMethod -Method Get -Uri $uriGroups -Headers $headers
    foreach ($group in $groups.value) {
        $groupId = $group.id
        $uriUsers = "https://graph.microsoft.com/v1.0/groups/$groupId/members"
        $groupUsers = Invoke-RestMethod -Method Get -Uri $uriUsers -Headers $headers
        $group | Add-Member -MemberType NoteProperty -Name "Users" -Value $groupUsers.value
    }

    # Output the list of groups and their users to a JSON file
    $jsonFilePath = Join-Path -Path $jsonOutputPath -ChildPath "${clientName}_groups_users.json"
    $groups | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonFilePath

    # Inform the user that the operation was successful
    Write-Host "The list of groups and their users has been successfully written to $jsonFilePath."
}
catch {
    # Log any errors to an errors.log file
    $errorLogFilePath = Join-Path -Path $logPath -ChildPath "errors.log"
    $_ | Out-File -FilePath $errorLogFilePath -Append
    Write-Host "An error occurred. Check the errors.log file for details at $errorLogFilePath."
}