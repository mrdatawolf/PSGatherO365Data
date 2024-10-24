# Import common functions
. ./coreFunctions.ps1

function Get-AccessToken {
    param (
        [string]$authUrl,
        [hashtable]$body,
        [string]$tokenPath,
        [string]$logPath,
        [int]$maxRetries = 3
    )
    $retryCount = 0
    $success = $false

    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            $response = Invoke-RestMethod -Method Post -Uri $authUrl -ContentType "application/x-www-form-urlencoded" -Body $body
            $accessToken = $response.access_token
            $tokenFilePath = Join-Path -Path $tokenPath -ChildPath "token.txt"
            Set-Content -Path $tokenFilePath -Value $accessToken
            Write-Host "Access token has been successfully written to $tokenFilePath."
            $success = $true
        }
        catch {
            $retryCount++
            Write-Log -message "Attempt ${retryCount}: An error occurred while requesting the access token. $_" -logPath $logPath
            Write-Host "Attempt ${retryCount}: An error occurred. Retrying..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
    }

    if (-not $success) {
        Write-Host "Failed to obtain the access token after ${maxRetries} attempts. Check the errors.log file for details." -ForegroundColor Red
    }
}

# Main script execution
$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$envFilePath = Join-Path -Path $scriptRoot -ChildPath ".env"
Set-EnvironmentVariables -envFilePath $envFilePath
$tenantId = [System.Environment]::GetEnvironmentVariable('TENANTID')
$clientId = [System.Environment]::GetEnvironmentVariable('CLIENTID')
$clientSecret = [System.Environment]::GetEnvironmentVariable('CLIENTSECRET')
$logPath = [System.Environment]::GetEnvironmentVariable('LOGPATH')
$tokenPath = [System.Environment]::GetEnvironmentVariable('TOKENPATH')
$jsonOutputPath = [System.Environment]::GetEnvironmentVariable('JSONOUTPUTPATH')
Test-EnvironmentVariables -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret

$resource = "https://graph.microsoft.com"
$authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/token"
$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    resource      = $resource
}

New-Directories -jsonOutputPath $jsonOutputPath -errorLogPath $logPath
Get-AccessToken -authUrl $authUrl -body $body -tokenPath $tokenPath -logPath $logPath
