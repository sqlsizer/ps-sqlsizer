SELECT
    c.TABLE_SCHEMA [schema], 
    c.TABLE_NAME [table],
    c.COLUMN_NAME [column],
	row_number() over(PARTITION BY c.TABLE_SCHEMA, c.TABLE_NAME order by c.ORDINAL_POSITION) as [position],
    c.DATA_TYPE [dataType],
	c.IS_NULLABLE [isNullable],
	CASE 
		WHEN computed.[isComputed] IS NULL 
			THEN 0 
			ELSE 1
	END as [isComputed],
	CASE 
		WHEN computed.[isComputed] IS NULL 
			THEN NULL
			ELSE computed.definition
	END as [computedDefinition],
	CASE 
		WHEN computed2.generated_always_type <> 0
			THEN 1
			ELSE 0
	END as [isGenerated]
FROM 
    INFORMATION_SCHEMA.COLUMNS c
	LEFT JOIN 
		(SELECT 1 as [isComputed], c.[definition], s.name as [schema], o.name as [table], c.[name] as [column]
		FROM sys.computed_columns c
		INNER JOIN sys.objects o ON o.object_id = c.object_id
		INNER JOIN sys.schemas s ON s.schema_id = o.schema_id) computed 
		ON c.TABLE_SCHEMA = computed.[schema] and c.TABLE_NAME = computed.[table] and c.COLUMN_NAME = computed.[column]
	LEFT JOIN 
		(SELECT c.generated_always_type, s.name as [schema], o.name as [table], c.[name] as [column]
		FROM sys.columns c
		INNER JOIN sys.objects o ON o.object_id = c.object_id
		INNER JOIN sys.schemas s ON s.schema_id = o.schema_id) computed2 
		ON c.TABLE_SCHEMA = computed2.[schema] and c.TABLE_NAME = computed2.[table] and c.COLUMN_NAME = computed2.[column]
ORDER BY 
	c.TABLE_SCHEMA, c.TABLE_NAME, [position]