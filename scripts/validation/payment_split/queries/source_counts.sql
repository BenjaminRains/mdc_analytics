-- Insurance vs Patient payment counts
-- Uses PaymentSourceSummary CTE for consistent source categorization
-- uses TotalPayments CTE from ctes.sql
-- Date filter: Uses @start_date to @end_date

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
