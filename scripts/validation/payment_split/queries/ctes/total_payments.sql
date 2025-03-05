-- TotalPayments: Calculate total payment counts and amounts across all sources.
-- depends on: PaymentSourceSummary
-- Date filter: Uses @start_date to @end_date
TotalPayments AS (
    SELECT 
        SUM(payment_count) as total_count,
        SUM(total_paid) as total_amount
    FROM PaymentSourceSummary
)