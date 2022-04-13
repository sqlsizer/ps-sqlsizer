SELECT s.name as [schema], o.name as [table], c.name as [column]
FROM sys.computed_columns c
INNER JOIN sys.objects o ON o.object_id = c.object_id
INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
