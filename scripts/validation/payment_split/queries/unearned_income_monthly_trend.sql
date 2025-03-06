/*
Monthly Payment Trend Query
=================

Purpose:
- Analyze monthly trends in all payment types
- Compare regular payments (Type 0) vs unearned income
- Break down unearned income by different types
- Useful for identifying seasonal patterns or growth trends

NOTE FOR PANDAS ANALYSIS:
- This query outputs 3 rows per month (All, Regular, Unearned categories)
- Results will need to be reshaped using pivot_table() for proper time series analysis
- Example: df_pivot = pd.pivot_table(df, index='Month', columns='Payment Category', values=['Total Amount', 'Transaction Count'])
- Investigate negative values in Prepayment/Treatment Plan columns which represent application of previously collected prepayments

Dependencies:
- None

Date Filter: @start_date to @end_date
*/

-- Monthly trend of all payment types
SELECT 
    DATE_FORMAT(ps.DatePay, '%Y-%m') AS 'Month',
    'All Payment Types' AS 'Payment Category',
    COUNT(*) AS 'Transaction Count',
    SUM(ps.SplitAmt) AS 'Total Amount',
    -- Regular payments
    SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS 'Regular Payment Amount',
    COUNT(CASE WHEN ps.UnearnedType = 0 THEN 1 ELSE NULL END) AS 'Regular Payment Count',
    -- Unearned income types
    SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS 'Total Unearned Amount',
    COUNT(CASE WHEN ps.UnearnedType != 0 THEN 1 ELSE NULL END) AS 'Unearned Transaction Count',
    -- Breakdown by unearned income type
    SUM(CASE WHEN ps.UnearnedType = 288 THEN ps.SplitAmt ELSE 0 END) AS 'Prepayment Amount',
    SUM(CASE WHEN ps.UnearnedType = 439 THEN ps.SplitAmt ELSE 0 END) AS 'Treatment Plan Prepayment Amount',
    SUM(CASE WHEN ps.UnearnedType NOT IN (0, 288, 439) AND ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS 'Other Unearned Amount',
    -- Percentage calculations
    FORMAT((SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) / NULLIF(SUM(ps.SplitAmt), 0)) * 100, 1) AS '% Regular Payments',
    FORMAT((SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) / NULLIF(SUM(ps.SplitAmt), 0)) * 100, 1) AS '% Unearned Income'
FROM paysplit ps
WHERE ps.DatePay BETWEEN @start_date AND @end_date
GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m')

UNION ALL

-- Monthly trend of regular payments only (Type 0)
SELECT 
    DATE_FORMAT(ps.DatePay, '%Y-%m') AS 'Month',
    'Regular Payments (Type 0)' AS 'Payment Category',
    COUNT(*) AS 'Transaction Count',
    SUM(ps.SplitAmt) AS 'Total Amount',
    -- Regular payments
    SUM(ps.SplitAmt) AS 'Regular Payment Amount',
    COUNT(*) AS 'Regular Payment Count',
    -- Unearned income types (set to 0 for this category)
    0 AS 'Total Unearned Amount',
    0 AS 'Unearned Transaction Count',
    -- Breakdown by unearned income type (set to 0 for this category)
    0 AS 'Prepayment Amount',
    0 AS 'Treatment Plan Prepayment Amount',
    0 AS 'Other Unearned Amount',
    -- Percentage calculations
    '100.0' AS '% Regular Payments',
    '0.0' AS '% Unearned Income'
FROM paysplit ps
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType = 0
GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m')

UNION ALL

-- Monthly trend of unearned income only (Type != 0)
SELECT 
    DATE_FORMAT(ps.DatePay, '%Y-%m') AS 'Month',
    'Unearned Income (Type != 0)' AS 'Payment Category',
    COUNT(*) AS 'Transaction Count',
    SUM(ps.SplitAmt) AS 'Total Amount',
    -- Regular payments (set to 0 for this category)
    0 AS 'Regular Payment Amount',
    0 AS 'Regular Payment Count',
    -- Unearned income types
    SUM(ps.SplitAmt) AS 'Total Unearned Amount',
    COUNT(*) AS 'Unearned Transaction Count',
    -- Breakdown by unearned income type
    SUM(CASE WHEN ps.UnearnedType = 288 THEN ps.SplitAmt ELSE 0 END) AS 'Prepayment Amount',
    SUM(CASE WHEN ps.UnearnedType = 439 THEN ps.SplitAmt ELSE 0 END) AS 'Treatment Plan Prepayment Amount',
    SUM(CASE WHEN ps.UnearnedType NOT IN (0, 288, 439) AND ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS 'Other Unearned Amount',
    -- Percentage calculations
    '0.0' AS '% Regular Payments',
    '100.0' AS '% Unearned Income'
FROM paysplit ps
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType != 0
GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m')

ORDER BY 
    Month,
    CASE 
        WHEN 'Payment Category' = 'All Payment Types' THEN 1
        WHEN 'Payment Category' = 'Regular Payments (Type 0)' THEN 2
        WHEN 'Payment Category' = 'Unearned Income (Type != 0)' THEN 3
        ELSE 4
    END; 