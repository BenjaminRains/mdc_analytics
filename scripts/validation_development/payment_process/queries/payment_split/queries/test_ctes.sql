{% import "cte_macros.sql" as macros %}

{# The begin_ctes macro adds the WITH keyword #}
{{ macros.begin_ctes() }}

{# For the first CTE, use is_first=True #}
{{ macros.include_cte("test_cte1.sql", True) }}

{# For subsequent CTEs, is_first defaults to False #}
{{ macros.include_cte("test_cte2.sql") }}

{# Main query follows #}
SELECT * FROM TestCTE1
JOIN TestCTE2 ON TestCTE1.id <> TestCTE2.id; 