SELECT tables.TABLE_SCHEMA as [schema], tables.TABLE_NAME as [table]
FROM INFORMATION_SCHEMA.TABLES tables 
WHERE OBJECTPROPERTY(OBJECT_ID(tables.TABLE_SCHEMA + '.' + tables.TABLE_NAME), 	'TableHasIdentity') = 1