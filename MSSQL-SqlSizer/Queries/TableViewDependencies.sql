WITH Dependencies ([referenced_type], [referenced_id], [referenced_schema_name],[referenced_entity_name], [referencing_type], [referencing_id], [view_schema_name], [view_name])
AS
(
	SELECT DISTINCT o2.[type], d.referenced_id, d.referenced_schema_name, d.referenced_entity_name, o.[type], d.referencing_id, s.name as [view_schema_name], OBJECT_NAME(o.object_id) as [view_name]
	FROM sys.sql_expression_dependencies  d
	INNER JOIN sys.objects AS o ON d.referencing_id = o.object_id  and o.type IN ('V')
	INNER JOIN sys.objects AS o2 ON d.referenced_id = o2.object_id
	LEFT JOIN sys.schemas s ON s.schema_id = o.schema_id
	WHERE o2.[type] IN ('U', 'V')
	
    UNION ALL

	SELECT o2.[type], ed.referenced_id, ed.referenced_schema_name, ed.referenced_entity_name, d.referencing_type, d.referencing_id, d.view_schema_name, d.view_name
	FROM Dependencies d 
	INNER JOIN sys.sql_expression_dependencies ed ON d.referenced_id = ed.referencing_id
	INNER JOIN sys.objects AS o ON ed.referencing_id = o.object_id  and o.type IN ('V')
	INNER JOIN sys.objects AS o2 ON ed.referenced_id = o2.object_id
	INNER JOIN sys.schemas s ON s.schema_id = o.schema_id

)
SELECT DISTINCT d.*
FROM Dependencies d
ORDER BY d.referenced_schema_name, d.referenced_entity_name