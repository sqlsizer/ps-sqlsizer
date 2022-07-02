param (
    [string] $apiKey
)

Publish-Module -Path ".\MSSQL-SqlSizer" -NuGetApiKey $apiKey -Verbose -Force