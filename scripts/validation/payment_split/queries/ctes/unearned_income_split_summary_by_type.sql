-- unearned_income_split_summary_by_type: Summary information for all payment types
-- depends on: none
-- Date filter: Uses @start_date to @end_date variables

unearned_income_split_summary_by_type AS (
    SELECT
        'All Payment Types' AS 'Payment Category',
        COUNT(*) AS 'Total Splits',
        SUM(ps.SplitAmt) AS 'Total Amount',
        AVG(ps.SplitAmt) AS 'Avg Amount',
        COUNT(DISTINCT ps.PatNum) AS 'Unique Patients',
        COUNT(DISTINCT CASE WHEN ps.UnearnedType = 0 THEN ps.SplitNum ELSE NULL END) AS 'Regular Payment Splits',
        COUNT(DISTINCT CASE WHEN ps.UnearnedType != 0 THEN ps.SplitNum ELSE NULL END) AS 'Unearned Income Splits',
        SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS 'Regular Payment Amount',
        SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS 'Unearned Income Amount',
        FORMAT((COUNT(DISTINCT CASE WHEN ps.UnearnedType = 0 THEN ps.SplitNum ELSE NULL END) / COUNT(*)) * 100, 1) AS '% Regular Payments',
        FORMAT((COUNT(DISTINCT CASE WHEN ps.UnearnedType != 0 THEN ps.SplitNum ELSE NULL END) / COUNT(*)) * 100, 1) AS '% Unearned Income',
        0 AS sort_order -- Make summary row appear first
    FROM paysplit ps
    WHERE ps.DatePay BETWEEN @start_date AND @end_date
) 