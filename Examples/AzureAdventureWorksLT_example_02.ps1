## Example that shows how to a subset database in Azure without using Azure Storage Account (with data-copy clone)

# Import of module
Import-Module ..\MSSQL-SqlSizer\MSSQL-SqlSizer

# Connection settings
$server = "sqlsizer.database.windows.net"
$database = "test03"

Connect-AzAccount
$accessToken = (Get-AzAccessToken -ResourceUrl https://database.windows.net).Token

# Create connection
$connection = New-SqlConnectionInfo -Server $server -AccessToken $accessToken -EncryptConnection $true

# Check if database is available
if ((Test-DatabaseOnline -Database $database -ConnectionInfo $connection) -eq $false)
{
    Write-Output "Database is not available" 
    return
}

# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection -MeasureSize $true

# Install SqlSizer
Install-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Define start set

# Query 1: 10 persons with first name = 'John'
$query = New-Object -TypeName Query
$query.Color = [Color]::Yellow
$query.Schema = "SalesLT"
$query.Table = "Customer"
$query.KeyColumns = @('CustomerID')
$query.Top = 10

# Define ignored tables

Clear-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query) -DatabaseInfo $info

# Find subset
Find-Subset -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Get subset info
Get-SubsetTables -Database $database -Connection $connection -DatabaseInfo $info

Write-Output "Logical reads from db during subsetting: $($connection.Statistics.LogicalReads)"


# Ensure that empty database with the database schema exists
$emptyDb = "test03_empty"

if ((Test-DatabaseOnline -Database $emptyDb -ConnectionInfo $connection) -eq $false)
{
   New-EmptyAzDatabase -Database $database -NewDatabase $emptyDb -ConnectionInfo $connection
}

# Create a copy of empty db for new subset db
$newDatabase = "test03_$((New-Guid).ToString().Replace('-', '_'))"
Copy-AzDatabase -Database $emptyDb -NewDatabase $newDatabase -ConnectionInfo $connection

while ((Test-DatabaseOnline -Database $newDatabase -ConnectionInfo $connection) -eq $false)
{
    Write-Output "Waiting for database"
    Start-Sleep -Seconds 5
}

$newInfo = Get-DatabaseInfo -Database $newDatabase -ConnectionInfo $connection -MeasureSize $false
Disable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $newInfo
$files = Copy-SubsetToDatabaseFileSet -SourceDatabase $database -TargetDatabase $newDatabase -DatabaseInfo $info -ConnectionInfo $connection -Secure $false
Import-SubsetFromFileSet -SourceDatabase $newDatabase -TargetDatabase $newDatabase -DatabaseInfo $newInfo -ConnectionInfo $connection -Files $files
Enable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $newInfo

Write-Output "Azure SQL database created"

# end of script