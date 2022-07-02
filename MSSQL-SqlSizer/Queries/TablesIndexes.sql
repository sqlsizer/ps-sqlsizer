SELECT DISTINCT
	i.[name] as [index], [schemas].[name] as [schema], t.[name] as [table], c.[name] as [column]
FROM 
	sys.objects t
INNER JOIN sys.indexes i 
	ON [t].object_id = [i].object_id
INNER JOIN sys.objects [objects]
    ON [objects].object_id = i.object_id
INNER JOIN sys.tables [tables]
    ON [tables].object_id = [objects].object_id
INNER JOIN sys.schemas [schemas]
    ON [tables].schema_id = [schemas].schema_id
INNER JOIN sys.index_columns ic
	ON ic.object_id = i.object_id and ic.index_id = i.index_id
INNER JOIN sys.columns c 
	ON c.object_id = ic.object_id and c.column_id = ic.column_id
WHERE
	i.is_primary_key = 0 and [schemas].[name] not like 'SqlSizer%'
ORDER BY 
	[schemas].[name], t.[name]