<<include:payment_source_summary.sql>>
TotalPayments AS (
    SELECT 
        SUM(payment_count) as total_count,
        SUM(total_paid) as total_amount
    FROM PaymentSourceSummary
)