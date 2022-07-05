select t.user_type_id, t.name as [user_type_name], b.name as [data_type], t.max_length as [length]
from sys.types t
inner join sys.types b ON t.system_type_id = b.system_type_id and b.system_type_id = b.user_type_id
where t.is_user_defined = 1