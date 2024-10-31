function Set-EnvironmentVariables {
    param (
        [Parameter(Mandatory=$true)]
        [string]$envFilePath
    )
    if (Test-Path $envFilePath) {
        Get-Content $envFilePath | ForEach-Object {
            if ($_ -match "^\s*([^#][^=]+?)\s*=\s*(.*?)\s*$") {
                $name = $matches[1].ToUpper()
                $value = $matches[2]
                [System.Environment]::SetEnvironmentVariable($name, $value)
            }
        }
    } else {
        Write-Host "You need a .env file. I will create one with default values. Please update it with the correct values." -ForegroundColor Red
        $envContent = @"
LOGPATH = <log path>
JSONOUTPUTPATH = <json output path>
SQLITEPATH = <sqlite file location>
REPOURL = <repo url>
"@
        Set-Content -Path $envFilePath -Value $envContent
        Write-Host ".env file created with default values. You need to update it with the correct values." -ForegroundColor Yellow
        exit
    }
}

function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$message,
        [Parameter(Mandatory=$true)]
        [string]$logPath
    )
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "$timestamp - $message"
        $logMessage | Out-File -FilePath $logPath -Append
    } catch {
        Write-Host "Failed to write log: $_" -ForegroundColor Red
    }
}

function New-Directories {
    param (
        [Parameter(Mandatory=$true)]
        [string]$jsonOutputPath,
        [Parameter(Mandatory=$true)]
        [string]$errorLogPath
    )
    foreach ($path in @($jsonOutputPath, $errorLogPath)) {
        try {
            if (-not (Test-Path -Path $path)) {
                Write-Host "Creating directory: $path"
                New-Item -Path $path -ItemType Directory -Force
            } else {
                Write-Host "Directory already exists: $path"
            }
        } catch {
            Write-Host "Failed to create directory: $path. Error: $_" -ForegroundColor Red
        }
    }
}

function Check-GitInstalled {
    try {
        git --version 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch {
        Write-Host "Git is not installed or not found in the PATH." -ForegroundColor Red
        return $false
    }
}
function Do-Update {
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-File `"$PSCommandPath`""
        exit
    } catch {
        Write-Host "Failed to restart the script: $_" -ForegroundColor Red
    }
}

function Update-Script {
    $localPath = $PSScriptRoot
    $repoUrl = [System.Environment]::GetEnvironmentVariable('REPOURL')
    if (-not $repoUrl) {
        throw "REPOURL environment variable is missing. Please check your .env file."
    }
    Set-Location -Path $localPath
    if (-not (Test-Path ".git")) {
        Write-Output "Cloning repository..."
        git clone $repoUrl .
    }

    $currentCommit = git rev-parse HEAD
    git pull
    $newCommit = git rev-parse HEAD

    if ($currentCommit -ne $newCommit) {
        Write-Output "Updates found. Restarting script..."
        Do-Update
    }
}

function Test-ModuleInstallation {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ModuleName
    )

    try {
        if (!(Get-Module -ListAvailable -Name $ModuleName)) {
            Write-Host "The $ModuleName module is not installed. Installing..." -ForegroundColor Yellow
            Install-Module -Name $ModuleName -Force
            return $false
        } else {
            Write-Host "Importing $ModuleName..." -ForegroundColor Green
            Import-Module $ModuleName
        }
    } catch {
        Write-Host "Failed to install or import module ${$ModuleName}: $_" -ForegroundColor Red
        return $false
    }

    return $true
}
function Get-ClientsAndSecrets {
    param (
        [Parameter(Mandatory=$true)]
        [string]$dbPath
    )

    try {
        $connection = New-SQLiteConnection -DataSource $dbPath

        $query = @"
SELECT clients.name AS clientName, secrets.tenantId, secrets.clientId, secrets.clientSecret, secrets.secretId
FROM clients
JOIN secrets ON clients.uid = secrets.clientUid;
"@

        $clientsAndSecrets = Invoke-SqliteQuery -Connection $connection -Query $query

        $connection.Close()
        return $clientsAndSecrets
    } catch {
        Write-Host "Failed to retrieve clients and secrets: $_" -ForegroundColor Red
        throw
    }
}
function Get-AccessToken {
    param (
        [string]$authUrl,
        [hashtable]$body,
        [string]$dbPath,
        [string]$logPath,
        [string]$clientName,
        [int]$maxRetries = 3
    )
    $retryCount = 0
    $success = $false

    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            $response = Invoke-RestMethod -Method Post -Uri $authUrl -ContentType "application/x-www-form-urlencoded" -Body $body
            $accessToken = $response.access_token

            $connection = New-SQLiteConnection -DataSource $dbPath
            $insertToken = @"
INSERT INTO tokens (clientName, accessToken)
VALUES (@clientName, @accessToken)
ON CONFLICT(clientName) DO UPDATE SET accessToken = excluded.accessToken;
"@
            Invoke-SqliteQuery -Connection $connection -Query $insertToken -SqlParameters @{
                "clientName" = $clientName
                "accessToken" = $accessToken
            }
            $connection.Close()

            Write-Host "Access token has been successfully stored in the database for $clientName."
            $success = $true
        }
        catch {
            $retryCount++
            $errorLogPath = Join-Path -Path $logPath -ChildPath "${clientName}_errors.log"
            Write-Log -message "Attempt ${retryCount}: An error occurred while requesting the access token. $_" -logPath $errorLogPath
            Write-Host "Attempt ${retryCount}: An error occurred. Retrying..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
    }

    if (-not $success) {
        Write-Host "Failed to obtain the access token after ${maxRetries} attempts. Check the errors.log file for details." -ForegroundColor Red
        throw "Failed to obtain the access token after ${maxRetries} attempts."
    }
}
function Initialize-TokensTable {
    param (
        [string]$dbPath
    )

    $connection = New-SQLiteConnection -DataSource $dbPath

    $createTokensTable = @"
CREATE TABLE IF NOT EXISTS tokens (
    clientName TEXT NOT NULL UNIQUE,
    accessToken TEXT NOT NULL
);
"@

    Invoke-SqliteQuery -Connection $connection -Query $createTokensTable

    $connection.Close()
}

