## Example that shows how to save subsets

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

# Basic limiting color map (because full search is enabled)
$colorMap = New-Object -Type ColorMap
foreach ($table in $info.Tables)
{
    $colorMapItem = New-Object -Type ColorItem
    $colorMapItem.SchemaName = $table.SchemaName
    $colorMapItem.TableName = $table.TableName
    $colorMapItem.Condition = New-Object -Type Condition
    $colorMapItem.Condition.Top = 10 # limit all dependend data for each fk by 10 rows
    $colorMap.Items += $colorMapItem
}

Clear-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query) -DatabaseInfo $info

# Find subset
Find-Subset -Database $database -ConnectionInfo $connection -IgnoredTables @($ignored) -DatabaseInfo $info -ColorMap $colorMap -FullSearch $true

$subsetGuid = Save-Subset -Database $database -ConnectionInfo $connection -SubsetName "Subset_from_example_17" -DatabaseInfo $info
Write-Host $subsetGuid

$sql = "UPDATE [Person].[Person] SET ModifiedDate = GETDATE()"
$null = Invoke-SqlcmdEx -Sql $sql -Database $database -ConnectionInfo $connection     

$subsetGuid2 = Save-Subset -Database $database -ConnectionInfo $connection -SubsetName "Subset_from_example_17_after_little_change" -DatabaseInfo $info
Write-Host $subsetGuid2

$compareResult = Compare-SavedSubsets -SourceDatabase $database -TargetDatabase $database -SourceSubsetGuid $subsetGuid -TargetSubsetGuid $subsetGuid2 -ConnectionInfo $connection

$compareResult
