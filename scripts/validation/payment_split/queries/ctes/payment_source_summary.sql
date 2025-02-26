-- PaymentSourceSummary: Summarize payment counts and amounts by payment source.
-- depends on: PaymentSourceCategories
-- Date filter: 2024-01-01 to 2025-01-01
PaymentSourceSummary AS (
    SELECT 
        pc.payment_source,
        COUNT(*) AS payment_count,
        SUM(pc.PayAmt) AS total_paid,
        MIN(pc.PayDate) AS min_date,
        MAX(pc.PayDate) AS max_date,
        AVG(pc.PayAmt) AS avg_payment
    FROM PaymentSourceCategories pc
    GROUP BY pc.payment_source
)