{% macro begin_ctes() %}
WITH 
{% endmacro %}

{% macro include_cte(cte_file, is_last=False) %}
{% include cte_file %}{% if not is_last %},{% endif %}
{% endmacro %} 