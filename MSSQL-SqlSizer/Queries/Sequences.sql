SELECT 
	seq.name,
	seq.current_value,
	seq.increment,
	ISNULL(seq.maximum_value, 2147483647) as maximum_value, -- todo 
	t.[name] as [type]
FROM 
    sys.sequences seq
INNER JOIN 
    sys.types t ON seq.system_type_id = t.system_type_id
