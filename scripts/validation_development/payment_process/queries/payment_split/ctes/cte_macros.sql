{# Starts a CTE block with the WITH keyword - use at the beginning of any query containing CTEs #}
{% macro begin_ctes() -%}
WITH 
{%- endmacro %}

{# Includes a CTE file with proper comma handling - use is_first=True only for the first CTE #}
{% macro include_cte(cte_file, is_first=False) -%}
{%- if not is_first -%}
,
{% endif -%}
{% include cte_file %}
{%- endmacro %}

{# Adds a comma between inline CTEs - use is_last=True for the last CTE in a WITH clause #}
{% macro cte_separator(is_last=False) -%}
{%- if not is_last %}
,
{% else %}
{% endif -%}
{%- endmacro %}
