SELECT  
    [objects].name AS [fk_name],
    [schemas].name AS [schema_name],
    [tables].name AS [table],
    [columns].name AS [column],
	[schemas2].name as [schema2_name],
    [tables2].name AS [referenced_table],
    [columns2].name AS [referenced_column]
FROM 
    sys.foreign_key_columns [fk]
INNER JOIN sys.objects [objects]
    ON [objects].object_id = [fk].constraint_object_id
INNER JOIN sys.tables [tables]
    ON [tables].object_id = [fk].parent_object_id
INNER JOIN sys.schemas [schemas]
    ON [tables].schema_id = [schemas].schema_id
INNER JOIN sys.columns [columns]
    ON [columns].column_id = [fk].parent_column_id AND [columns].object_id = [tables].object_id
INNER JOIN sys.tables [tables2]
    ON [tables2].object_id = [fk].referenced_object_id
INNER JOIN sys.schemas [schemas2]
    ON [tables2].schema_id = [schemas2].schema_id
INNER JOIN sys.columns [columns2]
    ON [columns2].column_id = [fk].referenced_column_id AND [columns2].object_id = [tables2].object_id