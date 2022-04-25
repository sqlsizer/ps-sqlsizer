SELECT  
    [objects].name AS [fk_name],
    [schemas].name AS [fk_schema],
    [tables].name AS [fk_table],
    [columns].name AS [fk_column],
	[columns].is_nullable AS [fk_column_is_nullable],
	[columnsT].name AS [fk_column_data_type],
	[schemas2].name as [schema],
    [tables2].name AS [table],
    [columns2].name AS [column]
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
INNER JOIN sys.types [columnsT] 
	ON [columnsT].user_type_id = [columns].user_type_id
INNER JOIN sys.tables [tables2]
    ON [tables2].object_id = [fk].referenced_object_id
INNER JOIN sys.schemas [schemas2]
    ON [tables2].schema_id = [schemas2].schema_id
INNER JOIN sys.columns [columns2]
    ON [columns2].column_id = [fk].referenced_column_id AND [columns2].object_id = [tables2].object_id
ORDER BY 
 fk_name