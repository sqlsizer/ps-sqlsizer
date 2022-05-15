class ColorMap
{
    [ColorItem[]]$Items
}

class ColorItem
{
    [string]$SchemaName
    [string]$TableName
    [ForcedColor]$ForcedColor
    [Condition]$Condition
}

class ForcedColor
{
    [Color]$Color
}

class Condition
{
    [int]$Top
}