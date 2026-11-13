{% macro list_cdc_tables() %}
  {# Prints every table in the raw CDC dataset with its row count #}
  {% set q %}
    select table_id, row_count
    from `{{ target.project }}.CDC.__TABLES__`
    order by table_id
  {% endset %}
  {% set res = run_query(q) %}
  {% for row in res.rows %}
    {{ log("TABLE: [" ~ row[0] ~ "]  rows=" ~ row[1], info=True) }}
  {% endfor %}
{% endmacro %}
