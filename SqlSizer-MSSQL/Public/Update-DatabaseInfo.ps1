function Update-DatabaseInfo
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory = $true)]
        [string]$Database,

        [Parameter(Mandatory = $false)]
        [bool]$MeasureSize = $false,

        [Parameter(Mandatory = $true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfo -Database $Database -ConnectionInfo $ConnectionInfo -MeasureSize $MeasureSize
    
    $DatabaseInfo.Views = @()
    if ($null -ne $info.Views)
    {
        foreach ($view in $info.Views)
        {
            $DatabaseInfo.Views += $view
        }
    }

    $DatabaseInfo.Tables = @()
    if ($null -ne $info.Tables)
    {
        foreach ($table in $info.Tables)
        {
            $DatabaseInfo.Tables += $table
        }
    }

    $DatabaseInfo.StoredProcedures = @()
    if ($null -ne $info.StoredProcedures)
    {
        foreach ($sp in $info.StoredProcedures)
        {
            $DatabaseInfo.StoredProcedures += $sp
        }
    }
    
    $DatabaseInfo.Schemas = @()
    if ($null -ne $info.Schemas)
    {
        foreach ($schema in $info.Schemas)
        {
            $DatabaseInfo.Schemas += $schema
        }
    }

    return
}