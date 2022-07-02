param (
    [string] $apiKey
)

Publish-Module -Path ".\Module\" -NuGetApiKey $apiKey -Verbose -Force