## Example that shows how to a subset database in Azure

# Import of module
Import-Module ..\MSSQL-SqlSizer

# Connection settings
$server = "sqlsizer.database.windows.net"
$database = "test01"

Connect-AzAccount
$accessToken = (Get-AzAccessToken -ResourceUrl https://database.windows.net).Token

# Create connection
$connection = New-SqlConnectionInfo -Server $server -AccessToken $accessToken

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

Write-Host "Logical reads from db during subsetting: $($connection.Statistics.LogicalReads)" -ForegroundColor Red


# Ensure that empty database with the database schema exists 
#$emptyDb = "test03_empty"

#if ((Test-DatabaseOnline -Database $emptyDb -ConnectionInfo $connection) -eq $false)
#{
#    New-EmptyAzDatabase -Database $database -NewDatabase $emptyDb -ConnectionInfo $connection
#}

# Create a copy of empty db for new subset db
#$newDatabase = "test03_$((New-Guid).ToString().Replace('-', '_'))"
#Copy-AzDatabase -Database $emptyDb -NewDatabase $newDatabase -ConnectionInfo $connection