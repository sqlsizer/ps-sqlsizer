﻿## Example that shows how to remove all phone numbers from database starting from phone number type

# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$username = "someuser"
$password = ConvertTo-SecureString -String "pass" -AsPlainText -Force

# Create connection
$connection = New-SqlConnectionInfo -Server $server -Username $username -Password $password

# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection -MeasureSize $true

# Verify if SqlSizer is installed
Install-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info -Force $true

# Disable integrity checks and triggers
Disable-ForeignKeys -Database $database -ConnectionInfo $connection -DatabaseInfo $info
Disable-AllTablesTriggers -Database $database -ConnectionInfo $connection -DatabaseInfo $info

while ($true)
{
    $sessionId = Start-SqlSizerSession -Database $database -ConnectionInfo $connection -DatabaseInfo $info -Installation $false -SecureViews $false -ExportViews $false

    # Define start set
    $query = New-Object -TypeName Query
    $query.Color = [Color]::Blue
    $query.Schema = "Person"
    $query.Table = "PhoneNumberType"
    $query.KeyColumns = @('PhoneNumberTypeID')
    $query.Top = 1

    Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query) -DatabaseInfo $info -SessionId $sessionId

    $null = Find-Subset -Database $database -ConnectionInfo $connection -DatabaseInfo $info -SessionId $sessionId -MaxBatchSize 1000

    $empty = Test-FoundSubsetIsEmpty -Database $database -ConnectionInfo $connection -DatabaseInfo $info -SessionId $sessionId

    if ($empty -eq $true)
    {
        Clear-SqlSizerSession -SessionId $sessionId -Database $database -ConnectionInfo $connection -DatabaseInfo $info -RemoveSessionData $true
        break
    }

    Remove-FoundSubsetFromDatabase -Database $database -ConnectionInfo $connection -DatabaseInfo $info -Step 1000 -SessionId $sessionId
    Clear-SqlSizerSession -SessionId $sessionId -Database $database -ConnectionInfo $connection -DatabaseInfo $info -RemoveSessionData $true
}
# Enable integrity checks and triggers
Enable-ForeignKeys -Database $database -ConnectionInfo $connection -DatabaseInfo $info
Enable-AllTablesTriggers -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Test foreign keys
Test-ForeignKeys -Database $database -ConnectionInfo $connection -DatabaseInfo $info