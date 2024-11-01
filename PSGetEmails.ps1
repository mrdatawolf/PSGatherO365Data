# Define the directory containing the JSON files and the output CSV file path
$jsonDirectory = "\\192.168.203.207\shared folders\PBIData\Biztech\O365_Data\Groups"
$outputCsvPath = Join-Path -Path $jsonDirectory -ChildPath "emails.csv"

# Initialize a list to store unique email addresses
$emailAddresses = @()

# Function to recursively extract email addresses from JSON objects
function Extract-Emails {
    param (
        [object]$jsonObject
    )

    if ($jsonObject -is [System.Collections.IDictionary]) {
        foreach ($key in $jsonObject.Keys) {
            if ($key -eq "Email" -and $jsonObject[$key]) {
                $emailAddresses += $jsonObject[$key]
            } else {
                Extract-Emails -jsonObject $jsonObject[$key]
            }
        }
    } elseif ($jsonObject -is [System.Collections.IEnumerable]) {
        foreach ($item in $jsonObject) {
            Extract-Emails -jsonObject $item
        }
    }
}

# Iterate over all JSON files in the directory
Get-ChildItem -Path $jsonDirectory -Filter *.json | ForEach-Object {
    $jsonFilePath = $_.FullName

    # Read the JSON file
    $data = Get-Content -Path $jsonFilePath | ConvertFrom-Json

    # Extract email addresses from the JSON data
    Extract-Emails -jsonObject $data
}

# Remove duplicates
$emailAddresses = $emailAddresses | Sort-Object -Unique

# Write the email addresses to the CSV file
$emailAddresses | Export-Csv -Path $outputCsvPath -NoTypeInformation -Force

Write-Host "Email addresses have been successfully exported to $outputCsvPath."
