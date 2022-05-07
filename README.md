# mssql-sqlsizer
A set of PowerShell scripts to make a copy of a Microsoft SQL database with a subset of data from that database.

# Details
The algorithm used in SqlSizer is a variation of Breadth-first and Depth-first search search algorithm applied to a relational database.

The initial set of graph nodes needs to be defined before start of the scripts.

Each graph node is represented by the row in *SqlSizer.Processing* tables that has following information:
-  Schema name
-  Table name
-  Primary key values
-  One of the colors: RED, GREEN, YELLOW or BLUE
-  Depth

Finding of neighbours of graph nodes is done in bulks and depends on the color in order to optimize number of queries needed.

Colors have following meaning:
 - Blue: find all rows that are required to remove that row (recursively) 
 - Red: find all rows that are referenced by the row (recursively) 
 - Green: find all dependent rows on the row (recursively) 
 - Yellow: find all related data to the row (recursively) 

# Prerequisites

```powershell
Install-Module dbatools -Scope CurrentUser
```

# How to start?
Please take a look at examples in *Examples* folder.

# Example
```powershell
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
Install-Structures -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Define start set

# Query 1: All persons with first name = 'Mary'
$query = New-Object -TypeName Query
$query.Color = [Color]::Yellow
$query.Schema = "Person"
$query.Table = "Person"
$query.KeyColumns = @('BusinessEntityID')
$query.Where = "[`$table].FirstName = 'Mary'"

# Query 2: All employees with SickLeaveHours > 30
$query2 = New-Object -TypeName Query
$query2.Color = [Color]::Yellow
$query2.Schema = "HumanResources"
$query2.Table = "Employee"
$query2.KeyColumns = @('BusinessEntityID')
$query2.Where = "[`$table].SickLeaveHours > 30"

Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query, $query2)

# Find subset
Get-Subset -Database $database -ConnectionInfo $connection

# Create a new db with found subset of data

$newDatabase = "AdventureWorks2019_subset_01"

Copy-Database -Database $database -NewDatabase $newDatabase -ConnectionInfo $connection
Disable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection
Compress-Database -Database $newDatabase -ConnectionInfo $connection
Copy-Data -Source $database -Destination  $newDatabase -ConnectionInfo $connection
Enable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection

# end of script
```