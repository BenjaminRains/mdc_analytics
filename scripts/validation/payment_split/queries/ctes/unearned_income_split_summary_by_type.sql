-- UnearnedIncomeSplitSummaryByType: Summary information for all payment types
-- depends on: none
-- Date filter: Uses @start_date to @end_date variables

UnearnedIncomeSplitSummaryByType AS (
    SELECT
        'All Payment Types' AS payment_category,
        COUNT(*) AS total_splits,
        SUM(ps.SplitAmt) AS total_amount,
        AVG(ps.SplitAmt) AS avg_amount,
        COUNT(DISTINCT ps.PatNum) AS unique_patients,
        COUNT(DISTINCT CASE WHEN ps.UnearnedType = 0 THEN ps.SplitNum ELSE NULL END) AS regular_payment_splits,
        COUNT(DISTINCT CASE WHEN ps.UnearnedType != 0 THEN ps.SplitNum ELSE NULL END) AS unearned_income_splits,
        SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS regular_payment_amount,
        SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS unearned_income_amount,
        FORMAT((COUNT(DISTINCT CASE WHEN ps.UnearnedType = 0 THEN ps.SplitNum ELSE NULL END) / COUNT(*)) * 100, 1) AS percent_regular_payments,
        FORMAT((COUNT(DISTINCT CASE WHEN ps.UnearnedType != 0 THEN ps.SplitNum ELSE NULL END) / COUNT(*)) * 100, 1) AS percent_unearned_income,
        0 AS sort_order -- Make summary row appear first
    FROM paysplit ps
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
) 