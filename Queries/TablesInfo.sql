SELECT 
	tables.TABLE_SCHEMA as [schema],
	tables.TABLE_NAME as [table],
	OBJECTPROPERTY(OBJECT_ID(tables.TABLE_SCHEMA + '.' + tables.TABLE_NAME), 	'TableHasIdentity') as [identity],
	CASE 
		WHEN t.history_table_name IS NOT NULL 
			THEN 1
			ELSE 0
	END as [is_historic]
FROM INFORMATION_SCHEMA.TABLES tables
LEFT JOIN 
	(	SELECT OBJECT_NAME(history_table_id) as history_table_name, OBJECT_NAME(schema_id) as [schema]
		FROM sys.tables
		WHERE OBJECT_NAME(history_table_id) IS NOT NULL
	) t ON tables.TABLE_NAME = t.history_table_name AND tables.TABLE_SCHEMA = t.[schema]
WHERE tables.TABLE_TYPE = 'BASE TABLE'
ORDER BY [schema], [table]
GO
