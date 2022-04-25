SELECT
    c.TABLE_SCHEMA [schema], 
    c.TABLE_NAME [table],
    c.COLUMN_NAME [column], 
    c.DATA_TYPE [dataType],
	c.IS_NULLABLE [isNullable],
	CASE 
		WHEN computed.[isComputed] IS NULL 
			THEN 0 
			ELSE 1
	END as [isComputed]
FROM 
    INFORMATION_SCHEMA.COLUMNS c
	LEFT JOIN 
		(SELECT 1 as [isComputed], s.name as [schema], o.name as [table]
		FROM sys.computed_columns c
		INNER JOIN sys.objects o ON o.object_id = c.object_id
		INNER JOIN sys.schemas s ON s.schema_id = o.schema_id) computed 
		ON c.TABLE_SCHEMA = computed.[schema] and c.TABLE_NAME = computed.[table]
