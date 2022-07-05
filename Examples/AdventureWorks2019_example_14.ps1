## Example that shows how to create a subset database without making data-copy of original database

# Import of module
Import-Module ..\MSSQL-SqlSizer\MSSQL-SqlSizer

# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$username = "someuser"
$password = ConvertTo-SecureString -String "pass" -AsPlainText -Force

# Create connection
$connection = New-SqlConnectionInfo -Server $server -Username $username -Password $password

# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection -MeasureSize $true

# Install SqlSizer
Install-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Define start set

# Query 1: 10 persons with first name = 'John'
$query = New-Object -TypeName Query
$query.Color = [Color]::Yellow
$query.Schema = "Person"
$query.Table = "Person"
$query.KeyColumns = @('BusinessEntityID')
$query.Where = "[`$table].FirstName = 'John'"
$query.Top = 10
$query.OrderBy = "[`$table].LastName ASC"

# Define ignored tables

$ignored = New-Object -Type TableInfo2
$ignored.SchemaName = "dbo"
$ignored.TableName = "ErrorLog"


Clear-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query) -DatabaseInfo $info

# Find subset
Find-Subset -Database $database -ConnectionInfo $connection -IgnoredTables @($ignored) -DatabaseInfo $info

# Create a new db with found subset of data
$newDatabase = "AdventureWorks2019_subset_ww"

if ((New-EmptyCompactDatabase -Database $database -NewDatabase $newDatabase -ConnectionInfo $connection -DatabaseInfo $info) -eq $false)
{
    Write-Output "Database already exists"
    return
}

Disable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
$files = Copy-SubsetToDatabaseFileSet -SourceDatabase $database -TargetDatabase $newDatabase -DatabaseInfo $info -ConnectionInfo $connection -Secure $false
Import-SubsetFromFileSet -SourceDatabase $newDatabase -TargetDatabase $newDatabase -DatabaseInfo $info -ConnectionInfo $connection -Files $files
Enable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info