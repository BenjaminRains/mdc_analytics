/*
Payment Aging Analysis Query
==================

Purpose:
- Perform comprehensive aging analysis of both regular and unearned income
- Compare regular payments (Type 0) vs. unearned income (Types 288, 439, etc.)
- Uses both transaction-based aging and patient table's built-in aging columns
- Important for financial risk assessment and accounting compliance

- Dependencies: None
- Date Filter: Uses @end_date as reference point for aging calculation
*/

-- Part 1: Transaction-based aging analysis of all payment types 
SELECT
    'transaction' AS analysis_group,
    'all_age_buckets' AS analysis_detail,
    CASE
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN '0-30_days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN '31-60_days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN '61-90_days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN '91-180_days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN '181-365_days'
        ELSE 'over_365_days'
    END AS age_bucket,
    CASE
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN 0
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN 31
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN 61
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN 91
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN 181
        ELSE 366
    END AS min_days,
    CASE
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN 30
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN 60
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN 90
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN 180
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN 365
        ELSE 999999
    END AS max_days,
    'all_payment_types' AS payment_category,
    0 AS is_unearned,  -- Flag for filtering (0 = mixed, 1 = unearned only)
    COUNT(*) AS transaction_count,
    SUM(ps.SplitAmt) AS total_amount,
    COUNT(DISTINCT ps.PatNum) AS unique_patients,
    AVG(ps.SplitAmt) AS average_amount,
    SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS regular_amount,
    SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS unearned_amount,
    COUNT(CASE WHEN ps.UnearnedType = 0 THEN 1 ELSE NULL END) AS regular_count,
    COUNT(CASE WHEN ps.UnearnedType != 0 THEN 1 ELSE NULL END) AS unearned_count,
    DATEDIFF(@end_date, ps.DatePay) AS actual_days
FROM paysplit ps
WHERE ps.DatePay <= @end_date
GROUP BY 
    age_bucket,
    min_days,
    max_days

UNION ALL

-- Part 2: Transaction-based aging analysis of regular payments (Type 0)
SELECT
    'transaction' AS analysis_group,
    'regular_payments' AS analysis_detail,
    CASE
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN '0-30_days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN '31-60_days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN '61-90_days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN '91-180_days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN '181-365_days'
        ELSE 'over_365_days'
    END AS age_bucket,
    CASE
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN 0
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN 31
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN 61
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN 91
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN 181
        ELSE 366
    END AS min_days,
    CASE
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN 30
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN 60
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN 90
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN 180
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN 365
        ELSE 999999
    END AS max_days,
    'regular_payments' AS payment_category,
    0 AS is_unearned,  -- Flag for filtering
    COUNT(*) AS transaction_count,
    SUM(ps.SplitAmt) AS total_amount,
    COUNT(DISTINCT ps.PatNum) AS unique_patients,
    AVG(ps.SplitAmt) AS average_amount,
    SUM(ps.SplitAmt) AS regular_amount,
    0 AS unearned_amount,
    COUNT(*) AS regular_count,
    0 AS unearned_count,
    DATEDIFF(@end_date, ps.DatePay) AS actual_days
FROM paysplit ps
WHERE ps.DatePay <= @end_date
    AND ps.UnearnedType = 0
GROUP BY 
    age_bucket,
    min_days,
    max_days

UNION ALL

-- Part 3: Transaction-based aging analysis of unearned income (Type != 0)
SELECT
    'transaction' AS analysis_group,
    'unearned_income' AS analysis_detail,
    CASE
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN '0-30_days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN '31-60_days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN '61-90_days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN '91-180_days'
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN '181-365_days'
        ELSE 'over_365_days'
    END AS age_bucket,
    CASE
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN 0
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN 31
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN 61
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN 91
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN 181
        ELSE 366
    END AS min_days,
    CASE
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 30 THEN 30
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 60 THEN 60
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 90 THEN 90
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 180 THEN 180
        WHEN DATEDIFF(@end_date, ps.DatePay) <= 365 THEN 365
        ELSE 999999
    END AS max_days,
    'unearned_income' AS payment_category,
    1 AS is_unearned,  -- Flag for filtering
    COUNT(*) AS transaction_count,
    SUM(ps.SplitAmt) AS total_amount,
    COUNT(DISTINCT ps.PatNum) AS unique_patients,
    AVG(ps.SplitAmt) AS average_amount,
    0 AS regular_amount,
    SUM(ps.SplitAmt) AS unearned_amount,
    0 AS regular_count,
    COUNT(*) AS unearned_count,
    DATEDIFF(@end_date, ps.DatePay) AS actual_days
FROM paysplit ps
WHERE ps.DatePay <= @end_date
    AND ps.UnearnedType != 0
GROUP BY 
    age_bucket,
    min_days,
    max_days

UNION ALL

-- Part 4: Patient table based aging - summary
SELECT
    'patient_aging' AS analysis_group,
    'summary' AS analysis_detail,
    'all_buckets' AS age_bucket,
    0 AS min_days,
    999999 AS max_days,
    'all_patients' AS payment_category,
    0 AS is_unearned,
    COUNT(DISTINCT pt.PatNum) AS transaction_count,
    SUM(pt.BalTotal) AS total_amount,
    COUNT(DISTINCT pt.PatNum) AS unique_patients,
    AVG(pt.BalTotal) AS average_amount,
    NULL AS regular_amount,
    NULL AS unearned_amount,
    NULL AS regular_count,
    NULL AS unearned_count,
    NULL AS actual_days
FROM patient pt
JOIN (SELECT DISTINCT PatNum FROM paysplit WHERE DatePay <= @end_date) ps ON pt.PatNum = ps.PatNum
GROUP BY 1,2,3,4,5,6,7

UNION ALL

-- Part 5: Detail aging by buckets from patient table
SELECT
    'patient_aging' AS analysis_group,
    'detail' AS analysis_detail,
    '0-30_days' AS age_bucket,
    0 AS min_days,
    30 AS max_days,
    'all_patients' AS payment_category,
    0 AS is_unearned,
    COUNT(*) AS transaction_count,
    SUM(pt.Bal_0_30) AS total_amount,
    COUNT(DISTINCT CASE WHEN pt.Bal_0_30 > 0 THEN pt.PatNum ELSE NULL END) AS unique_patients,
    AVG(CASE WHEN pt.Bal_0_30 > 0 THEN pt.Bal_0_30 ELSE NULL END) AS average_amount,
    NULL AS regular_amount,
    NULL AS unearned_amount,
    NULL AS regular_count,
    NULL AS unearned_count,
    NULL AS actual_days
FROM patient pt
JOIN (SELECT DISTINCT PatNum FROM paysplit WHERE DatePay <= @end_date) ps ON pt.PatNum = ps.PatNum
GROUP BY 1,2,3,4,5,6,7

UNION ALL

SELECT
    'patient_aging' AS analysis_group,
    'detail' AS analysis_detail,
    '31-60_days' AS age_bucket,
    31 AS min_days,
    60 AS max_days,
    'all_patients' AS payment_category,
    0 AS is_unearned,
    COUNT(*) AS transaction_count,
    SUM(pt.Bal_31_60) AS total_amount,
    COUNT(DISTINCT CASE WHEN pt.Bal_31_60 > 0 THEN pt.PatNum ELSE NULL END) AS unique_patients,
    AVG(CASE WHEN pt.Bal_31_60 > 0 THEN pt.Bal_31_60 ELSE NULL END) AS average_amount,
    NULL AS regular_amount,
    NULL AS unearned_amount,
    NULL AS regular_count,
    NULL AS unearned_count,
    NULL AS actual_days
FROM patient pt
JOIN (SELECT DISTINCT PatNum FROM paysplit WHERE DatePay <= @end_date) ps ON pt.PatNum = ps.PatNum
GROUP BY 1,2,3,4,5,6,7

UNION ALL

SELECT
    'patient_aging' AS analysis_group,
    'detail' AS analysis_detail,
    '61-90_days' AS age_bucket,
    61 AS min_days,
    90 AS max_days,
    'all_patients' AS payment_category,
    0 AS is_unearned,
    COUNT(*) AS transaction_count,
    SUM(pt.Bal_61_90) AS total_amount,
    COUNT(DISTINCT CASE WHEN pt.Bal_61_90 > 0 THEN pt.PatNum ELSE NULL END) AS unique_patients,
    AVG(CASE WHEN pt.Bal_61_90 > 0 THEN pt.Bal_61_90 ELSE NULL END) AS average_amount,
    NULL AS regular_amount,
    NULL AS unearned_amount,
    NULL AS regular_count,
    NULL AS unearned_count,
    NULL AS actual_days
FROM patient pt
JOIN (SELECT DISTINCT PatNum FROM paysplit WHERE DatePay <= @end_date) ps ON pt.PatNum = ps.PatNum
GROUP BY 1,2,3,4,5,6,7

UNION ALL

SELECT
    'patient_aging' AS analysis_group,
    'detail' AS analysis_detail,
    'over_90_days' AS age_bucket,
    91 AS min_days,
    999999 AS max_days,
    'all_patients' AS payment_category,
    0 AS is_unearned,
    COUNT(*) AS transaction_count,
    SUM(pt.BalOver90) AS total_amount,
    COUNT(DISTINCT CASE WHEN pt.BalOver90 > 0 THEN pt.PatNum ELSE NULL END) AS unique_patients,
    AVG(CASE WHEN pt.BalOver90 > 0 THEN pt.BalOver90 ELSE NULL END) AS average_amount,
    NULL AS regular_amount,
    NULL AS unearned_amount,
    NULL AS regular_count,
    NULL AS unearned_count,
    NULL AS actual_days
FROM patient pt
JOIN (SELECT DISTINCT PatNum FROM paysplit WHERE DatePay <= @end_date) ps ON pt.PatNum = ps.PatNum
GROUP BY 1,2,3,4,5,6,7

ORDER BY 
    analysis_group,
    analysis_detail,
    min_days; 