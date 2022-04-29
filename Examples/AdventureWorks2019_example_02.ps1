# Import of module
Import-Module ..\MSSQL-SqlSizer -Verbose


# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$login = "someuser"
$password = "pass"

# Create connection
$connection = Get-SqlConnectionInfo -Server $server -Login $login -Password $password


# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection

# Init SqlSizer structures
Init-Structures -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Define start set

# Query 1: All persons with first name = 'Michael'
$query = New-Object -TypeName Query
$query.Color = [Color]::Blue
$query.Schema = "Person"
$query.Table = "Person"
$query.KeyColumns = @('BusinessEntityID')
$query.Where = "[`$table].FirstName = 'Michael'"

Init-StartSet -Database $database -ConnectionInfo $connection -Queries @($query)

# Find smallest subset that allows to remove start set from the database
Get-Subset -Database $database -ConnectionInfo $connection -Return $false


$newDatabase = "AdventureWorks2019_subset_02"

Copy-Database -Database $database -NewDatabase $newDatabase -ConnectionInfo $connection
Disable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection
Delete-Data -Source $database -Target $newDatabase -ConnectionInfo $connection -Verbose
Enable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection

# end of script