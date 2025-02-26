-- FilterStats: Compute summary statistics for each payment filter category.
-- depends on: PaymentFilterDiagnostics
-- Date filter: 2024-01-01 to 2025-01-01
FilterStats AS (
    SELECT 
        filter_reason,
        COUNT(*) as payment_count,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as percentage,
        SUM(PayAmt) as total_amount,
        AVG(PayAmt) as avg_amount,
        SUM(has_multiple_splits_per_proc) as complex_split_count,
        SUM(is_large_payment) as large_payment_count,
        SUM(is_simple_payment) as simple_payment_count,
        SUM(has_high_split_ratio) as high_ratio_count,
        SUM(has_oversplit_claims) as oversplit_claim_count
    FROM PaymentFilterDiagnostics
    GROUP BY filter_reason
)