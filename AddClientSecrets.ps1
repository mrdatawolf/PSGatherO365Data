. "$PSScriptRoot\coreFunctions.ps1"
$envFilePath = Join-Path -Path $PSScriptRoot -ChildPath ".env"
Set-EnvironmentVariables -envFilePath $envFilePath
$modules = @("PSSQLite")
foreach ($module in $modules) {
    $result = Test-ModuleInstallation -ModuleName $module
    if (-not $result) {
        Write-Host "Please restart the script now that ${$module} is installed." -ForegroundColor Red
        exit
    }
}

function Initialize-Database {
    param (
        [string]$dbPath
    )

    if (-not $dbPath) {
        throw "Database path cannot be null or empty."
    }

    # Ensure the database file exists
    if (-not (Test-Path $dbPath)) {
        New-Item -ItemType File -Path $dbPath | Out-Null
    }

    $connection = New-SQLiteConnection -DataSource $dbPath

    $createClientsTable = @"
CREATE TABLE IF NOT EXISTS clients (
    uid INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);
"@

    $createSecretsTable = @"
CREATE TABLE IF NOT EXISTS secrets (
    tenantId TEXT NOT NULL,
    clientUid INTEGER NOT NULL,
    clientId TEXT NOT NULL,
    clientSecret TEXT NOT NULL,
    secretId TEXT NOT NULL,
    FOREIGN KEY (clientUid) REFERENCES clients(uid)
);
"@

    Invoke-SqliteQuery -Connection $connection -Query $createClientsTable
    Invoke-SqliteQuery -Connection $connection -Query $createSecretsTable

    $connection.Close()
}

function Get-ClientUid {
    param (
        [string]$dbPath,
        [string]$clientName
    )

    if (-not $dbPath) {
        throw "Database path cannot be null or empty."
    }

    $connection = New-SQLiteConnection -DataSource $dbPath

    $selectClientUid = "SELECT uid FROM clients WHERE name = @name"
    $clientUid = Invoke-SqliteQuery -Connection $connection -Query $selectClientUid -SqlParameters @{ "name" = $clientName } | Select-Object -ExpandProperty uid

    if (-not $clientUid) {
        $insertClient = "INSERT INTO clients (name) VALUES (@name);"
        Invoke-SqliteQuery -Connection $connection -Query $insertClient -SqlParameters @{ "name" = $clientName }
        
        $clientUid = Invoke-SqliteQuery -Connection $connection -Query "SELECT last_insert_rowid() AS uid;" | Select-Object -ExpandProperty uid
    }

    $connection.Close()
    return $clientUid
}


function Insert-Secret {
    param (
        [string]$dbPath,
        [string]$tenantId,
        [string]$clientUid,
        [string]$clientId,
        [string]$clientSecret,
        [string]$secretId
    )

    if (-not $dbPath) {
        throw "Database path cannot be null or empty."
    }

    $connection = New-SQLiteConnection -DataSource $dbPath

    $insertSecret = @"
INSERT INTO secrets (tenantId, clientUid, clientId, clientSecret, secretId)
VALUES (@tenantId, @clientUid, @clientId, @clientSecret, @secretId);
"@

    Invoke-SqliteQuery -Connection $connection -Query $insertSecret -SqlParameters @{
        "tenantId" = $tenantId
        "clientUid" = $clientUid
        "clientId" = $clientId
        "clientSecret" = $clientSecret
        "secretId" = $secretId
    }

    $connection.Close()
}

# Main script
$dbDirectory = [System.Environment]::GetEnvironmentVariable('SQLITEPATH')
if (-not $dbDirectory) {
    throw "Database directory path cannot be null or empty."
}

$dbPath = Join-Path -Path $dbDirectory -ChildPath "db.sqlite3"

$tenantId = Read-Host "Enter TENANTID"
$clientId = Read-Host "Enter CLIENTID"
$clientName = Read-Host "Enter CLIENTNAME"
$clientSecret = Read-Host "Enter CLIENTSECRET"
$secretId = Read-Host "Enter SECRETID"

Initialize-Database -dbPath $dbPath
$clientUid = Get-ClientUid -dbPath $dbPath -clientName $clientName
Insert-Secret -dbPath $dbPath -tenantId $tenantId -clientUid $clientUid -clientId $clientId -clientSecret $clientSecret -secretId $secretId
