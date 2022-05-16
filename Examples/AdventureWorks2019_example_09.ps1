## Example that shows ignored tables feature

# Import of module
Import-Module ..\MSSQL-SqlSizer

# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$login = "someuser"
$password = "pass"

# Create connection
$connection = New-SqlConnectionInfo -Server $server -Login $login -Password $password

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

# Define color map
$colorMap = New-Object -Type ColorMap

foreach ($table in $info.Tables)
{
    $colorMapItem = New-Object -Type ColorItem
    $colorMapItem.SchemaName = $table.SchemaName
    $colorMapItem.TableName = $table.TableName

    $colorMapItem.ForcedColor = New-Object -Type ForcedColor
    $colorMapItem.ForcedColor.Color = [Color]::Yellow
    
    $colorMapItem.Condition = New-Object -Type Condition
    $colorMapItem.Condition.Top = 100 # limit all dependend data for each fk by 100 rows (it doesn't mean that there will be no more rows!)
    $colorMap.Items += $colorMapItem
}


Clear-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query) -DatabaseInfo $info

# Find subset
Find-Subset -Database $database -ConnectionInfo $connection -IgnoredTables @($ignored) -DatabaseInfo $info -ColorMap $colorMap

# Get subset info
Get-SubsetTables -Database $database -Connection $connection -DatabaseInfo $info

# Create a new db with found subset of data

$newDatabase = "AdventureWorks2019_subset_01"

Copy-Database -Database $database -NewDatabase $newDatabase -ConnectionInfo $connection
Disable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Clear-Database -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Copy-Data -Source $database -Destination  $newDatabase -ConnectionInfo $connection -DatabaseInfo $info -IgnoredTables @($ignored)
Enable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Format-Indexes -Database $newDatabase -ConnectionInfo $connection
Uninstall-SqlSizer -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Compress-Database -Database $newDatabase -ConnectionInfo $connection

Test-ForeignKeys -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info

$infoNew = Get-DatabaseInfo -Database $newDatabase -ConnectionInfo $connection -MeasureSize $true

Write-Host "Subset size: $($infoNew.DatabaseSize)"
$sum = 0
foreach ($table in $infoNew.Tables)
{
    $sum += $table.Statistics.Rows
}

Write-Host "Total rows: $($sum)"
# end of script
