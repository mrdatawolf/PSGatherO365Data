# Office 365 Data Gathering and Email Extraction Scripts

This repository contains a set of PowerShell scripts designed to gather data from an Office 365 tenant using APIs and extract email addresses from the collected data.

## Environment Variables

The `.env` file holds the following variables:

- `LOGPATH`: The base folder to write logs to.
- `JSONOUTPUTPATH`: The base folder to write JSON results to.
- `SQLITEPATH`: The base folder for the SQLite database.
- `REPOURL`: URL back to the GitHub repository for self-updating.

## Scripts

### 1. AddClientSecrets

This script collects and stores client secrets in a SQLite database.

#### Parameters

- `TenantID`: The ID of your Office 365 tenant.
- `ClientID`: The client ID for your Office 365 application.
- `ClientName`: The name of the client.
- `ClientSecret`: The client secret for your Office 365 application.
- `ClientSecretID`: The ID of the client secret.

#### Usage

```powershell
# Example usage
.\AddClientSecrets.ps1 -TenantID <YourTenantID> -ClientID <YourClientID> -ClientName <YourClientName> -ClientSecret <YourClientSecret> -ClientSecretID <YourClientSecretID>

2. PSGetAccessToken
This script retrieves a fresh access token for any clients listed in the database and stores the token in the database.

Parameters
ClientName: The name of the client for which to get the token.
Usage
# Example usage
.\PSGetAccessToken.ps1 -ClientName <YourClientName>
3. PSGetGroupList
This script uses the Office 365 API to gather all the data from a tenant and saves the data into a JSON file.

Parameters
TenantID: The ID of your Office 365 tenant.
ClientID: The client ID for your Office 365 application.
ClientSecret: The client secret for your Office 365 application.
Usage
# Example usage
.\PSGetGroupList.ps1 -TenantID <YourTenantID> -ClientID <YourClientID> -ClientSecret <YourClientSecret>
4. PSGetEmails
This script processes the JSON files created by PSGetGroupList to generate a simple list of email addresses.

Parameters
JsonPath: The path to the directory containing the JSON files.
Usage
# Example usage
.\PSGetEmails.ps1 -JsonPath <PathToJsonFiles>
    Best Practices
Parameter Validation: Ensure that all required parameters are provided and valid.
Error Handling: Implement robust error handling to manage API call failures or file read/write errors.
Logging: Include logging to track the scripts execution and troubleshoot issues.
Security: Securely handle sensitive information such as ClientSecret by using secure storage mechanisms.
Examples
Example 1: Running AddClientSecrets
.\AddClientSecrets.ps1

Example 2: Running PSGetAccessToken
.\PSGetAccessToken.ps1 -ClientName "your-client-name"

Example 3: Running PSGetGroupList for all clients
.\PSGetGroupList.ps1

Example 3: Running PSGetGroupList
.\PSGetGroupList.ps1 -ClientName "client"

Example 4: Running PSGetEmails
.\PSGetEmails.ps1 

Contributing
Feel free to submit issues or pull requests if you have suggestions for improvements or new features.

License
This project is licensed under the MIT License.