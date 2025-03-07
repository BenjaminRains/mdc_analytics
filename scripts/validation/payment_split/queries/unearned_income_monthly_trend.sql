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
- Example: df_pivot = pd.pivot_table(df, index='month', columns='payment_category', values=['total_amount', 'transaction_count'])
- Investigate negative values in Prepayment/Treatment Plan columns which represent application of previously collected prepayments

- Dependencies: None
- Date Filter: @start_date to @end_date
*/

-- Monthly trend of all payment types
SELECT 
    DATE_FORMAT(ps.DatePay, '%Y-%m') AS month,
    'All Payment Types' AS payment_category,
    COUNT(*) AS transaction_count,
    SUM(ps.SplitAmt) AS total_amount,
    -- Regular payments
    SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS regular_payment_amount,
    COUNT(CASE WHEN ps.UnearnedType = 0 THEN 1 ELSE NULL END) AS regular_payment_count,
    -- Unearned income types
    SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS total_unearned_amount,
    COUNT(CASE WHEN ps.UnearnedType != 0 THEN 1 ELSE NULL END) AS unearned_transaction_count,
    -- Breakdown by unearned income type
    SUM(CASE WHEN ps.UnearnedType = 288 THEN ps.SplitAmt ELSE 0 END) AS prepayment_amount,
    SUM(CASE WHEN ps.UnearnedType = 439 THEN ps.SplitAmt ELSE 0 END) AS treatment_plan_prepayment_amount,
    SUM(CASE WHEN ps.UnearnedType NOT IN (0, 288, 439) AND ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS other_unearned_amount,
    -- Percentage calculations
    FORMAT((SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) / NULLIF(SUM(ps.SplitAmt), 0)) * 100, 1) AS percent_regular_payments,
    FORMAT((SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) / NULLIF(SUM(ps.SplitAmt), 0)) * 100, 1) AS percent_unearned_income
FROM paysplit ps
WHERE ps.DatePay BETWEEN @start_date AND @end_date
GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m')

UNION ALL

-- Monthly trend of regular payments only (Type 0)
SELECT 
    DATE_FORMAT(ps.DatePay, '%Y-%m') AS month,
    'Regular Payments (Type 0)' AS payment_category,
    COUNT(*) AS transaction_count,
    SUM(ps.SplitAmt) AS total_amount,
    -- Regular payments
    SUM(ps.SplitAmt) AS regular_payment_amount,
    COUNT(*) AS regular_payment_count,
    -- Unearned income types (set to 0 for this category)
    0 AS total_unearned_amount,
    0 AS unearned_transaction_count,
    -- Breakdown by unearned income type (set to 0 for this category)
    0 AS prepayment_amount,
    0 AS treatment_plan_prepayment_amount,
    0 AS other_unearned_amount,
    -- Percentage calculations
    '100.0' AS percent_regular_payments,
    '0.0' AS percent_unearned_income
FROM paysplit ps
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType = 0
GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m')

UNION ALL

-- Monthly trend of unearned income only (Type != 0)
SELECT 
    DATE_FORMAT(ps.DatePay, '%Y-%m') AS month,
    'Unearned Income (Type != 0)' AS payment_category,
    COUNT(*) AS transaction_count,
    SUM(ps.SplitAmt) AS total_amount,
    -- Regular payments (set to 0 for this category)
    0 AS regular_payment_amount,
    0 AS regular_payment_count,
    -- Unearned income types
    SUM(ps.SplitAmt) AS total_unearned_amount,
    COUNT(*) AS unearned_transaction_count,
    -- Breakdown by unearned income type
    SUM(CASE WHEN ps.UnearnedType = 288 THEN ps.SplitAmt ELSE 0 END) AS prepayment_amount,
    SUM(CASE WHEN ps.UnearnedType = 439 THEN ps.SplitAmt ELSE 0 END) AS treatment_plan_prepayment_amount,
    SUM(CASE WHEN ps.UnearnedType NOT IN (0, 288, 439) AND ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS other_unearned_amount,
    -- Percentage calculations
    '0.0' AS percent_regular_payments,
    '100.0' AS percent_unearned_income
FROM paysplit ps
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType != 0
GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m')

ORDER BY 
    month,
    CASE 
        WHEN payment_category = 'All Payment Types' THEN 1
        WHEN payment_category = 'Regular Payments (Type 0)' THEN 2
        WHEN payment_category = 'Unearned Income (Type != 0)' THEN 3
        ELSE 4
    END; 