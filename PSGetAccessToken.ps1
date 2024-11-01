param (
    [string]$ClientName
)
. "$PSScriptRoot\coreFunctions.ps1"

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

Initialize-TokensTable -dbPath $dbPath

if ($ClientName) {
    $clientsAndSecrets = Get-ClientsAndSecrets -dbPath $dbPath | Where-Object { $_.clientName -eq $ClientName }
} else {
    $clientsAndSecrets = Get-ClientsAndSecrets -dbPath $dbPath
}

foreach ($client in $clientsAndSecrets) {
    $tenantId = $client.tenantId
    $clientId = $client.clientId
    $clientName = $client.clientName
    $clientSecret = $client.clientSecret

    $resource = "https://graph.microsoft.com"
    $authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/token"
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $clientId
        client_secret = $clientSecret
        resource      = $resource
    }

    Get-AccessToken -authUrl $authUrl -body $body -dbPath $dbPath -logPath $logPath -clientName $clientName
}
