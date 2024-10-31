. "$PSScriptRoot\coreFunctions.ps1"

if (Check-GitInstalled) {
    Update-Script
} else {
    Write-Host "Git not installed. Skipping update check."
}

# Function to get the access token from the SQLite database
function Get-AccessTokenFromDB {
    param (
        [string]$dbPath,
        [string]$clientName
    )

    $connection = New-SQLiteConnection -DataSource $dbPath

    $query = "SELECT accessToken FROM tokens WHERE clientName = @clientName"
    $accessToken = Invoke-SqliteQuery -Connection $connection -Query $query -SqlParameters @{ "clientName" = $clientName } | Select-Object -ExpandProperty accessToken

    $connection.Close()
    return $accessToken
}

# Function to get all clients from the SQLite database
function Get-AllClients {
    param (
        [string]$dbPath
    )

    $connection = New-SQLiteConnection -DataSource $dbPath

    $query = "SELECT name FROM clients"
    $clients = Invoke-SqliteQuery -Connection $connection -Query $query | Select-Object -ExpandProperty name

    $connection.Close()
    return $clients
}

# Main script execution
$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$envFilePath = Join-Path -Path $scriptRoot -ChildPath ".env"
Set-EnvironmentVariables -envFilePath $envFilePath

$dbDirectory = [System.Environment]::GetEnvironmentVariable('SQLITEPATH')
if (-not $dbDirectory) {
    throw "Database directory path cannot be null or empty."
}

$dbPath = Join-Path -Path $dbDirectory -ChildPath "db.sqlite3"
$logPath = [System.Environment]::GetEnvironmentVariable('LOGPATH')
$jsonOutputPath = [System.Environment]::GetEnvironmentVariable('JSONOUTPUTPATH')

New-Directories -jsonOutputPath $jsonOutputPath -errorLogPath $logPath

$clients = Get-AllClients -dbPath $dbPath

foreach ($clientName in $clients) {
    $accessToken = Get-AccessTokenFromDB -dbPath $dbPath -clientName $clientName

    if (-not $accessToken) {
        Write-Host "Access token for $clientName is null or empty. Please check the database entry." -ForegroundColor Red
        continue
    }

    $uriGroups = "https://graph.microsoft.com/v1.0/groups"
    $headers = @{
        Authorization = "Bearer $accessToken"
    }

    try {
        $groups = Invoke-RestMethod -Method Get -Uri $uriGroups -Headers $headers
        foreach ($group in $groups.value) {
            $groupId = $group.id
            $uriUsers = "https://graph.microsoft.com/v1.0/groups/$groupId/members"
            $groupUsers = Invoke-RestMethod -Method Get -Uri $uriUsers -Headers $headers
            $group | Add-Member -MemberType NoteProperty -Name "Users" -Value $groupUsers.value
            $group | Add-Member -MemberType NoteProperty -Name "Client" -Value $clientName
        }

        # Output the list of groups and their users to a JSON file
        $jsonFilePath = Join-Path -Path $jsonOutputPath -ChildPath "${clientName}_groups_users.json"
        $groups | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonFilePath

        Write-Host "The list of groups and their users for $clientName has been successfully written to $jsonFilePath."
    }
    catch {
        $errorLogFilePath = Join-Path -Path $logPath -ChildPath "${clientName}_errors.log"
        $_ | Out-File -FilePath $errorLogFilePath -Append
        Write-Host "An error occurred for $clientName. Check the errors.log file for details at $errorLogFilePath."
    }
}