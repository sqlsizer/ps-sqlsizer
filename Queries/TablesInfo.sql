SELECT 
	tables.TABLE_SCHEMA as [schema],
	tables.TABLE_NAME as [table],
	OBJECTPROPERTY(OBJECT_ID(tables.TABLE_SCHEMA + '.' + tables.TABLE_NAME), 	'TableHasIdentity') as [identity]
FROM INFORMATION_SCHEMA.TABLES tables 
WHERE tables.TABLE_TYPE = 'BASE TABLE'
ORDER BY [schema], [table]