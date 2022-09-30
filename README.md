![logo](https://avatars.githubusercontent.com/u/96390582?s=100&v=4)
# sqlsizer-mssql

A PowerShell module for managing data in Microsoft SQL Server and Azure SQL databases.

Currently there is only limited support for Azure Synapse Analytics SQL Pool (work in progress).

The long-term goal of the project is to create a generic tool for managing data in Microsoft cloud and on-premises data platform and services.

The core feature is ability to find desired subset from the database and that feature has following properties:

 - No limitation on database or subset size
 - No limitation on primary key size. It can handle tables with any size of primary key (e.g. even with 8 columns and any types)
 - No limitation on foreign key size. It can handle tables with any size of foreign key (e.g. even with 8 columns and any types)
 - Heavy processing done on the server side (Azure SQL or Microsoft SQL Server)
 - Memory complexity:
    - on PowerShell side related to number of tables (rather very small, benchmark to be provided)
    - on SQL Server or Azure SQL side dependent on server configuration

# Use cases
**SqlSizer** can help with:
 - making copies of Microsoft SQL Server or Azure SQL databases with a subset of data from the original database
 - doing comparison of subsets (comparing only data that you are interested in)
 - copying schemas/tables/data to the same or different database or to Azure BLOB storage
 - getting the database object model that you can use to implement your own data management logic
 - extracting selected data from your database in CSV, JSON format to file
 - importing previously extracted subset data from Azure BLOB storage
 - removing unwanted data, tables or schemas from database  
 - removing large amount of data from database in safe way (with log file that will not grow that much)
 - disabling/enabling/editing/testing table foreign keys 
 - disabling/enabling triggers

# Internals
There are two algorithms used in SqlSizer:
  - a variation of *Breadth-first search (BFS)* algorithm with *multiple sources* 
  - a variation of *Depth-first search (DFS)* algorithm with *multiple sources*

Both can be applied to the relational database data to find the desired subset.

In order to optimize speed of BFS the following ideas have been applied:
- The BFS algorithm is visiting the graph nodes in specific, well-known order.
In SqlSizer the node is the BFS operation which is one row that defines a set of data rows visited or to visit.
Thanks to this, it's more efficient to find next nodes (data rows) in the graph during BFS search.
- The SqlSizer is not marking data rows as vistited in order to limit the number of SQL updates.
Instead the status of BFS operation is updated which is only one row SQL update.


# How to find subset you need

- Step 1: Provide configuration
    - Queries that define initial data (the table rows with colors)
    - (Optional) Color map that allow to configure colors for the data and limits

- Step 2: Execute `Find-Subset` cmdlet to find the subset you want
- Step 3: Copy data to new db or just do your own processing of the subset

## Color map

The colors defines rules which related data to the rows will be included in the subset.

The initial data has colors and also you can adjust colors of the data during search using **color map**.

At the moment there are following colors:

- Red: find referenced rows (recursively)
- Green: find dependent and referenced rows (recursively, there is also an option to adjust this behavior)
- Yellow: split into Red and Green
- Blue: find rows that are required to remove that row (recursively)
- Purple: find referenced (recursively) and dependent data on the row (no-recursively)

![Diagram1](https://user-images.githubusercontent.com/115426/190853966-c51be4e3-0e24-41bf-bda8-1eabec89a6c5.png)

# Prerequisites

```powershell
Install-Module sqlserver -Scope CurrentUser
Install-Module dbatools -Scope CurrentUser
Install-Module Az -Scope CurrentUser

```

# Installation
Run the following to install SqlSizer-MSSQL from the  [PowerShell Gallery](https://www.powershellgallery.com/packages/SqlSizer-MSSQL).

Please bare in mind that at the moment the SqlSizer-MSSQL is in alpha stage.

To install for all users, remove the -Scope parameter and run in an elevated session:

```powershell
Install-Module SqlSizer-MSSQL -AllowPrerelease -Scope CurrentUser
```

Before running scripts:

```powershell
Import-Module SqlSizer-MSSQL
```

# Examples
Please take a look at examples in *Examples* folder.

## Sample 1 (on-premises SQL server)
```powershell
## Example that shows how to create a new database with the subset of data based on queries which define initial data

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

# Get subset info
Get-SubsetTables -Database $database -Connection $connection -DatabaseInfo $info

Write-Output "Logical reads from db during subsetting: $($connection.Statistics.LogicalReads)" 

# Create a new db with found subset of data

$newDatabase = "AdventureWorks2019_subset_01"

Copy-Database -Database $database -NewDatabase $newDatabase -ConnectionInfo $connection
Disable-ForeignKeys -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Clear-Database -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Copy-DataFromSubset -Source $database -Destination  $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Enable-ForeignKeys -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Format-Indexes -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Uninstall-SqlSizer -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Compress-Database -Database $newDatabase -ConnectionInfo $connection

Test-ForeignKeys -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info

$infoNew = Get-DatabaseInfo -Database $newDatabase -ConnectionInfo $connection -MeasureSize $true

Write-Output "Subset size: $($infoNew.DatabaseSize)"
$sum = 0
foreach ($table in $infoNew.Tables)
{
    $sum += $table.Statistics.Rows
}

Write-Output "Total rows: $($sum)"
# end of script
```
## Sample 2 (Azure SQL database)

```powershell

## Example that shows how to a subset database in Azure

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

# Query 1: 10 top customers
$query = New-Object -TypeName Query
$query.Color = [Color]::Yellow
$query.Schema = "SalesLT"
$query.Table = "Customer"
$query.KeyColumns = @('CustomerID')
$query.Top = 10

Clear-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query) -DatabaseInfo $info

# Find subset
Find-Subset -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Get subset info
Get-SubsetTables -Database $database -Connection $connection -DatabaseInfo $info

Write-Output "Logical reads from db during subsetting: $($connection.Statistics.LogicalReads)" 

```

## Schema visualizations

Demo01:
https://sqlsizer.github.io/sqlsizer-mssql/Visualizations/Demo01/

Demo02:
https://sqlsizer.github.io/sqlsizer-mssql/Visualizations/Demo02/

## License
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fsqlsizer%2Fsqlsizer-mssql.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Fsqlsizer%2Fsqlsizer-mssql?ref=badge_large)

