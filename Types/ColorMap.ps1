class ColorMap
{
    [ColorItem[]]$Items
}

class ColorItem
{
    [string]$SchemaName
    [string]$TableName
    [Color]$ForcedColor
}