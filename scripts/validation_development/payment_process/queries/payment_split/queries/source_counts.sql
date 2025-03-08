{% include "payment_source_categories.sql" %}
{% include "payment_source_summary.sql" %}
{% include "total_payments.sql" %}
SELECT 
    ps.payment_source,
    ps.payment_count,
    ps.total_paid,
    ps.avg_payment,
    CAST(ps.payment_count AS FLOAT) / tp.total_count as pct_of_total,
    CAST(ps.total_paid AS FLOAT) / NULLIF(tp.total_amount, 0) as pct_of_amount,
    DATEDIFF(ps.max_date, ps.min_date) as date_span_days
FROM PaymentSourceSummary ps
CROSS JOIN TotalPayments tp
ORDER BY ps.payment_count DESC;
