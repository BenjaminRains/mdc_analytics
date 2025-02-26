-- TotalPayments: Calculate total payment counts and amounts across all sources.
-- depends on: PaymentSourceSummary
-- Date filter: 2024-01-01 to 2025-01-01
TotalPayments AS (
    SELECT 
        SUM(payment_count) as total_count,
        SUM(total_paid) as total_amount
    FROM PaymentSourceSummary
)