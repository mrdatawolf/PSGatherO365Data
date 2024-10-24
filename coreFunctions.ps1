function Set-EnvironmentVariables {
    param (
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
TENANTID = <tenantId>
CLIENTID = <clientId>
CLIENTNAME = <Client Name>
CLIENTSECRET = <clientSecret>
LOGPATH = <log path>
TOKENPATH = <token path>
JSONOUTPUTPATH = <json output path>
"@
        Set-Content -Path $envFilePath -Value $envContent
        Write-Host ".env file created with default values. You need to update it with the correct values." -ForegroundColor Yellow
        exit
    }
}

function Test-EnvironmentVariables {
    param (
        [string]$tenantId,
        [string]$clientId,
        [string]$clientSecret
    )

    $missingVariables = @()
    if (-not $tenantId) { $missingVariables += 'TENANTID' }
    if (-not $clientId) { $missingVariables += 'CLIENTID' }
    if (-not $clientSecret) { $missingVariables += 'CLIENTSECRET' }

    if ($missingVariables.Count -gt 0) {
        throw "The following environment variables are missing: $($missingVariables -join ', '). Please check your .env file."
    }

    $invalidVariables = @()
    if ($tenantId -match '^<.*>$') { $invalidVariables += 'TENANTID' }
    if ($clientId -match '^<.*>$') { $invalidVariables += 'CLIENTID' }
    if ($clientSecret -match '^<.*>$') { $invalidVariables += 'CLIENTSECRET' }

    if ($invalidVariables.Count -gt 0) {
        throw "The following environment variables contain placeholder values: $($invalidVariables -join ', '). Please put valid data into your .env file."
    }
}

function Write-Log {
    param (
        [string]$message,
        [string]$logPath
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    $logFilePath = Join-Path -Path $logPath -ChildPath "log.txt"
    $logMessage | Out-File -FilePath $logFilePath -Append
}

function New-Directories {
    param (
        [string]$jsonOutputPath,
        [string]$errorLogPath
    )
    if (-not (Test-Path -Path $jsonOutputPath)) {
        New-Item -Path $jsonOutputPath -ItemType Directory
    }
    if (-not (Test-Path -Path $errorLogPath)) {
        New-Item -Path $errorLogPath -ItemType Directory
    }
}
