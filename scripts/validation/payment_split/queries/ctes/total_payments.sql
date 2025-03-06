-- TotalPayments: Calculate total payment counts and amounts across all sources.
-- Date filter: Uses @start_date to @end_date
-- Include dependent CTE
<<include:payment_source_summary.sql>>

TotalPayments AS (
    SELECT 
        SUM(payment_count) as total_count,
        SUM(total_paid) as total_amount
    FROM PaymentSourceSummary
)