SELECT DISTINCT o2.[type], d.referenced_schema_name, d.referenced_entity_name, s.name as [view_schema_name], OBJECT_NAME(o.object_id) as [view_name]
FROM sys.sql_expression_dependencies  d
INNER JOIN sys.objects AS o ON d.referencing_id = o.object_id  and o.type IN ('V')
INNER JOIN sys.objects AS o2 ON d.referenced_id = o2.object_id
LEFT JOIN sys.schemas s ON s.schema_id = o.schema_id
ORDER BY referenced_schema_name, referenced_entity_name